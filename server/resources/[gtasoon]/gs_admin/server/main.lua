-- gs_admin (serveur). Chaque action : niveau vérifié → cible validée → exécution → journal (BDD + webhook).
-- Règle anti-abus : on ne sanctionne jamais un staff de niveau égal ou supérieur.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local JobsApi  = exports.gs_jobs

Admin = {
    onDuty = {},     -- [src] = os.time() de prise de service staff
    tickets = {},    -- [id] = { id, src, name, message, time, status, claimedBy }
    nextTicket = 0,
    jailed = {},     -- [src] = { untilTs, license }
    frozen = {},     -- [src] = true
    joinedAt = {},   -- [src] = os.time()
    logs = {},       -- journal récent (le plus récent en premier)
}

local function started(res) return GetResourceState(res) == 'started' end

--- Niveau staff : 0 (joueur), 1 helper, 2 modo, 3 admin, 4 fondateur.
function Admin.level(src)
    if type(src) ~= 'number' or src <= 0 then return 0 end
    for lvl = #Config.Aces, 1, -1 do
        if IsPlayerAceAllowed(src, Config.Aces[lvl]) then return lvl end
    end
    return 0
end

local function license(src) return GetPlayerIdentifierByType(src, 'license') end
local function online(src) return type(src) == 'number' and GetPlayerName(src) ~= nil end
local function label(src)
    return ('%s [%s]'):format(Bridge:GetName(src) or GetPlayerName(src) or '?', src)
end

local function notify(src, msg, t) Bridge:Notify(src, msg, t or 'inform') end

function Admin.log(staffSrc, action, target, details)
    local staff = staffSrc == 0 and 'console' or label(staffSrc)
    local entry = { staff = staff, action = action, target = target, details = details, time = os.time() }
    table.insert(Admin.logs, 1, entry)
    Admin.logs[Config.LogHistory + 1] = nil
    Store.log(staff, action, target, details)
    Security:LogStaff(('[Staff] %s → %s %s %s'):format(staff, action, target or '', details or ''))
end

--- Publication transparente d'une sanction (staff anonyme).
function Admin.publishSanction(kind, targetName, reason, extra)
    if not Config.PublicSanctions then return end
    local who = Config.PublicShowName and targetName or 'Un joueur'
    Security:LogStaff(('**%s** · %s · Motif : %s%s'):format(kind, who, reason, extra and (' · ' .. extra) or ''), 'sanctions', true)
end

-- Jail -----------------------------------------------------------------------------------------------

local function teleport(src, c)
    local ped = GetPlayerPed(src)
    if ped ~= 0 then SetEntityCoords(ped, c.x, c.y, c.z, false, false, false, false) end
end

function Admin.jail(src, minutes, reason, staffName)
    local untilTs = os.time() + minutes * 60
    local lic = license(src)
    Admin.jailed[src] = { untilTs = untilTs, license = lic }
    if lic then Store.jailSet(lic, untilTs, reason, staffName) end
    teleport(src, Config.Jail.coords)
    TriggerClientEvent('gs_admin:client:jail', src, untilTs - os.time(), reason)
end

function Admin.release(src, silent)
    local j = Admin.jailed[src]
    if not j then return false end
    Admin.jailed[src] = nil
    if j.license then Store.jailClear(j.license) end
    teleport(src, Config.Jail.release)
    TriggerClientEvent('gs_admin:client:jail', src, 0)
    if not silent then notify(src, 'Tu es libéré de la salle d\'isolement.', 'success') end
    return true
end

--- Toutes les 5 s : libération à l'échéance, retour en cellule si le joueur s'échappe.
function Admin.jailTick()
    local now = os.time()
    for src, j in pairs(Admin.jailed) do
        if now >= j.untilTs then
            Admin.release(src)
        else
            local ped = GetPlayerPed(src)
            if ped ~= 0 and #(GetEntityCoords(ped) - Config.Jail.coords) > Config.Jail.radius then
                teleport(src, Config.Jail.coords)
            end
        end
    end
end

-- Tickets ----------------------------------------------------------------------------------------------

local function openTickets()
    local list = {}
    for _, t in pairs(Admin.tickets) do
        if t.status ~= 'closed' then
            list[#list + 1] = { id = t.id, src = t.src, name = t.name, message = t.message, time = t.time,
                status = t.status, claimedBy = t.claimedBy, online = online(t.src) }
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

local function pushToStaff(event, ...)
    for src in pairs(Admin.onDuty) do TriggerClientEvent(event, src, ...) end
end

RegisterNetEvent('gs_admin:server:report', function(message)
    local src = source
    if not Security:RateLimit(src, 'gs_admin:report', 1, Config.Report.cooldown) then
        return notify(src, 'Tu as déjà fait un signalement il y a peu, patiente.', 'error')
    end
    message = Security:Sanitize(message, Config.Report.maxLength)
    if not message then return notify(src, 'Décris ton problème : /report <message>', 'error') end
    for _, t in pairs(Admin.tickets) do
        if t.src == src and t.status ~= 'closed' then return notify(src, 'Tu as déjà un ticket ouvert (#' .. t.id .. ').', 'error') end
    end
    Admin.nextTicket = Admin.nextTicket + 1
    local t = { id = Admin.nextTicket, src = src, name = label(src), message = message, time = os.time(), status = 'open' }
    Admin.tickets[t.id] = t
    pushToStaff('gs_admin:client:ticket', { id = t.id, name = t.name, message = t.message })
    Security:LogStaff(('[Ticket #%d] %s : %s'):format(t.id, t.name, message))
    notify(src, next(Admin.onDuty) and ('Ticket #%d envoyé au staff.'):format(t.id)
        or ('Ticket #%d enregistré : aucun staff en service, il sera traité dès que possible.'):format(t.id), 'success')
end)

-- Fiche joueur -------------------------------------------------------------------------------------------

function Admin.playerList()
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local s = tonumber(id)
        local job = Bridge:GetJob(s)
        list[#list + 1] = {
            id = s, name = Bridge:GetName(s) or GetPlayerName(s), account = GetPlayerName(s), ping = GetPlayerPing(s),
            job = job and job.name or nil, duty = job and job.onduty or false,
            heat = started('gs_wanted') and exports.gs_wanted:GetHeat(s) or 0,
            staff = Admin.level(s) > 0, jailed = Admin.jailed[s] ~= nil,
        }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

function Admin.dossier(src, target)
    local lvl = Admin.level(src)
    local job = Bridge:GetJob(target)
    local d = {
        id = target, name = Bridge:GetName(target), account = GetPlayerName(target), ping = GetPlayerPing(target),
        citizenid = Bridge:GetIdentifier(target), level = Admin.level(target),
        session = os.time() - (Admin.joinedAt[target] or os.time()),
        job = job, contracts = JobsApi:GetMemberships(target),
        heat = started('gs_wanted') and exports.gs_wanted:GetHeat(target) or 0,
        handle = started('gs_social') and exports.gs_social:GetHandle(target) or nil,
        frozen = Admin.frozen[target] == true,
        jailedFor = Admin.jailed[target] and (Admin.jailed[target].untilTs - os.time()) or 0,
    }
    if started('gs_duo') then
        local partner = exports.gs_duo:GetPartner(target)
        d.duo = partner and label(partner) or nil
        d.duoLevel = exports.gs_duo:GetDuoLevel(target)
    end
    if started('gs_gangs') then
        local gang, grade = exports.gs_gangs:GetGang(target)
        d.gang = gang and ('%s (grade %d)'):format(gang, grade) or nil
    end
    if lvl >= 2 then
        d.license = license(target)
        d.notes = d.license and Store.notes(d.license) or {}
    end
    if lvl >= 3 then
        d.money = { cash = Bridge:GetMoney(target, 'cash'), bank = Bridge:GetMoney(target, 'bank') }
    end
    return d
end

-- Actions ----------------------------------------------------------------------------------------------------
-- level : niveau minimum ; target : cible joueur requise ; sanction : cible de niveau inférieur obligatoire

local function need(v, msg) if not v then error({ msg = msg }, 0) end return v end
local function reasonOf(data) return need(Security:Sanitize(data.reason, 200), 'Motif obligatoire.') end

local Actions = {}

Actions['goto'] = { level = 1, target = true, run = function(src, target)
    local c = GetEntityCoords(GetPlayerPed(target))
    teleport(src, vec3(c.x + 1.0, c.y, c.z))
    return 'Téléporté vers ' .. label(target)
end }

Actions.bring = { level = 2, target = true, run = function(src, target)
    local c = GetEntityCoords(GetPlayerPed(src))
    teleport(target, vec3(c.x + 1.0, c.y, c.z))
    return label(target) .. ' amené à toi'
end }

Actions.freeze = { level = 2, target = true, sanction = true, run = function(_, target)
    local on = not Admin.frozen[target]
    Admin.frozen[target] = on or nil
    FreezeEntityPosition(GetPlayerPed(target), on)
    notify(target, on and 'Tu es figé par le staff.' or 'Tu peux de nouveau bouger.', on and 'warning' or 'success')
    return on and 'Figé' or 'Libéré'
end }

Actions.heal = { level = 2, target = true, run = function(_, target)
    TriggerClientEvent('gs_admin:client:heal', target)
    return 'Soigné'
end }

Actions.revive = { level = 2, target = true, run = function(_, target)
    Bridge:Revive(target)
    TriggerClientEvent('gs_admin:client:heal', target)
    return 'Réanimé'
end }

Actions.fixveh = { level = 2, target = true, run = function(_, target)
    TriggerClientEvent('gs_admin:client:fixveh', target)
    return 'Véhicule réparé'
end }

Actions.clearheat = { level = 2, target = true, run = function(_, target)
    need(started('gs_wanted'), 'gs_wanted non démarré.')
    exports.gs_wanted:ClearHeat(target)
    return 'Recherche effacée'
end }

Actions.note = { level = 2, target = true, run = function(src, target, data)
    local text = need(Security:Sanitize(data.text, 250), 'Note vide.')
    Store.addNote(need(license(target), 'Licence introuvable.'), 'note', text, label(src))
    return 'Note ajoutée'
end }

Actions.warn = { level = 2, target = true, sanction = true, run = function(src, target, data)
    local reason = reasonOf(data)
    Store.addNote(need(license(target), 'Licence introuvable.'), 'warn', reason, label(src))
    TriggerClientEvent('gs_admin:client:warn', target, reason)
    Admin.publishSanction('Avertissement', Bridge:GetName(target) or GetPlayerName(target), reason)
    return 'Averti'
end }

Actions.kick = { level = 2, target = true, sanction = true, run = function(_, target, data)
    local reason = reasonOf(data)
    local name = Bridge:GetName(target) or GetPlayerName(target)
    DropPlayer(target, 'Expulsé par le staff : ' .. reason)
    Admin.publishSanction('Expulsion', name, reason)
    return 'Expulsé'
end }

Actions.jail = { level = 2, target = true, sanction = true, run = function(src, target, data)
    local reason = reasonOf(data)
    local minutes = tonumber(data.minutes)
    need(minutes and minutes == math.floor(minutes) and minutes >= 1 and minutes <= Config.Jail.maxMinutes,
        ('Durée : 1 à %d min.'):format(Config.Jail.maxMinutes))
    Admin.jail(target, minutes, reason, label(src))
    Admin.publishSanction('Isolement', Bridge:GetName(target) or GetPlayerName(target), reason, minutes .. ' min')
    return ('Isolé %d min'):format(minutes)
end }

Actions.unjail = { level = 2, target = true, run = function(_, target)
    need(Admin.release(target), 'Pas en isolement.')
    return 'Libéré'
end }

local function amountOf(data, max)
    local n = tonumber(data.amount)
    return need(n and n == math.floor(n) and n >= 1 and n <= max and n, ('Montant : 1 à %d.'):format(max))
end

Actions.givemoney = { level = 3, target = true, run = function(_, target, data)
    local account = need((data.account == 'cash' or data.account == 'bank') and data.account, 'Compte invalide.')
    local amount = amountOf(data, Config.Give.maxMoney)
    reasonOf(data)
    need(Bridge:AddMoney(target, account, amount, 'staff'), 'Échec.')
    return ('+%d $ (%s)'):format(amount, account)
end }

Actions.removemoney = { level = 3, target = true, run = function(_, target, data)
    local account = need((data.account == 'cash' or data.account == 'bank') and data.account, 'Compte invalide.')
    local amount = amountOf(data, Config.Give.maxMoney)
    reasonOf(data)
    need(Bridge:RemoveMoney(target, account, amount, 'staff'), 'Solde insuffisant.')
    return ('-%d $ (%s)'):format(amount, account)
end }

local function itemOf(data)
    local item = need(type(data.item) == 'string' and data.item:match('^[%w_]+$') and data.item, 'Item invalide.')
    return need(Bridge:ItemExists(item) and item, 'Item inconnu d\'ox_inventory.')
end

-- Motif obligatoire, sauf pour le fondateur (menu rapide).
local function reasonUnlessFounder(src, data) if Admin.level(src) < 4 then reasonOf(data) end end

Actions.giveitem = { level = 3, target = true, run = function(src, target, data)
    local item = itemOf(data)
    local count = amountOf(data, Config.Give.maxItems)
    reasonUnlessFounder(src, data)
    need(Bridge:AddItem(target, item, count), 'Inventaire plein.')
    return ('+%d %s'):format(count, item)
end }

Actions.removeitem = { level = 4, target = true, run = function(_, target, data)
    local item = itemOf(data)
    local have = Bridge:GetItemCount(target, item)
    need(have > 0, 'Il n\'en a pas.')
    local count = math.min(amountOf(data, Config.Give.maxItems), have)
    need(Bridge:RemoveItem(target, item, count), 'Échec.')
    return ('-%d %s'):format(count, item)
end }

Actions.dropitem = { level = 4, duty = true, run = function(src, _, data)
    local item = itemOf(data)
    local count = amountOf(data, Config.Give.maxItems)
    need(Bridge:CreateDrop({ { item, count } }, GetEntityCoords(GetPlayerPed(src))), 'Échec du dépôt.')
    return ('%d %s posés au sol'):format(count, item)
end }

Actions.addjob = { level = 3, target = true, run = function(_, target, data)
    local ok, err = JobsApi:AdminAddContract(need(Bridge:GetIdentifier(target), 'Perso introuvable.'),
        tostring(data.job), tonumber(data.grade) or 0, Bridge:GetName(target))
    need(ok, 'Refusé : ' .. tostring(err))
    return ('Contrat %s grade %s'):format(data.job, data.grade or 0)
end }

Actions.removejob = { level = 3, target = true, run = function(_, target, data)
    local ok, err = JobsApi:AdminRemoveContract(need(Bridge:GetIdentifier(target), 'Perso introuvable.'), tostring(data.job))
    need(ok, 'Refusé : ' .. tostring(err))
    return 'Contrat ' .. data.job .. ' retiré'
end }

-- Menu rapide : pouvoirs (appliqués par le client après accord), métier / gang de test, véhicules --------

Actions.power = { level = 1, duty = true, run = function(src, _, data)
    local min = need(Config.Powers[data.power], 'Pouvoir inconnu.')
    need(Admin.level(src) >= min, 'Niveau insuffisant.')
    if data.power == 'animal' and data.model then
        local ok = false
        for _, a in ipairs(Config.Animals) do if a.model == data.model then ok = true end end
        need(ok, 'Animal inconnu.')
    end
    return ('%s %s'):format(data.power, data.model or (data.on == false and 'OFF' or 'ON'))
end }

Actions.spectate = { level = 2, duty = true, target = true, run = function(src, target)
    need(target ~= src, 'Tu ne peux pas te regarder toi-même.')
    TriggerClientEvent('gs_admin:client:spectate', src, target, GetEntityCoords(GetPlayerPed(target)))
    return 'Spectate'
end }

Actions.setjob = { level = 3, target = true, run = function(_, target, data)
    local ok, err = JobsApi:AdminSetActive(target, tostring(data.job), tonumber(data.grade) or 0)
    need(ok, 'Refusé : ' .. tostring(err))
    return ('Job actif %s grade %s'):format(data.job, data.grade or 0)
end }

Actions.setgang = { level = 3, target = true, run = function(_, target, data)
    need(started('gs_gangs'), 'gs_gangs non démarré.')
    local gang = data.gang ~= 'none' and tostring(data.gang) or nil
    local ok, err = exports.gs_gangs:AdminSetGang(target, gang, tonumber(data.grade) or 0)
    need(ok, 'Refusé : ' .. tostring(err))
    return gang and ('Gang %s grade %s'):format(gang, data.grade or 0) or 'Retiré de son gang'
end }

local VEH_TYPES = { automobile = true, bike = true, boat = true, heli = true, plane = true }

Actions.spawnveh = { level = 3, duty = true, run = function(src, _, data)
    local model = need(type(data.model) == 'string' and #data.model <= 30 and data.model:match('^[%w_]+$') and data.model:lower(), 'Modèle invalide.')
    local vtype = need(VEH_TYPES[data.vtype] and data.vtype, 'Type de véhicule invalide.')
    local ped = GetPlayerPed(src)
    local c = GetEntityCoords(ped)
    local veh = Bridge:SpawnVehicle(src, model, vtype, c, GetEntityHeading(ped), 'STAFF', true)
    need(veh and veh ~= 0, 'Création impossible.')
    return 'Véhicule ' .. model
end }

Actions.delveh = { level = 2, duty = true, run = function(src, _, data)
    local veh = NetworkGetEntityFromNetworkId(tonumber(data.netId) or 0)
    need(veh and veh ~= 0 and DoesEntityExist(veh) and GetEntityType(veh) == 2, 'Aucun véhicule.')
    need(#(GetEntityCoords(veh) - GetEntityCoords(GetPlayerPed(src))) <= Config.Vehicle.maxDeleteDistance + 3.0, 'Trop loin.')
    DeleteEntity(veh)
    return 'Véhicule supprimé'
end }

Actions.announce = { level = 3, run = function(_, _, data)
    local text = need(Security:Sanitize(data.text, 200), 'Annonce vide.')
    TriggerClientEvent('gs_admin:client:announce', -1, text)
    return 'Annonce envoyée'
end }

Actions.weather = { level = 3, run = function(_, _, data)
    need(started('gs_weather'), 'gs_weather non démarré.')
    if data.event == 'stop' then exports.gs_weather:StopEvent() return 'Événement arrêté' end
    if data.event then need(exports.gs_weather:StartEvent(data.event), 'Événement inconnu.') return 'Événement ' .. data.event end
    need(exports.gs_weather:SetWeather(tostring(data.type), tonumber(data.minutes) or 30), 'Météo inconnue.')
    return 'Météo ' .. data.type
end }

Actions.ticket_claim = { level = 1, run = function(src, _, data)
    local t = need(Admin.tickets[tonumber(data.id)], 'Ticket introuvable.')
    need(t.status == 'open', 'Déjà pris en charge.')
    t.status, t.claimedBy = 'claimed', label(src)
    if online(t.src) then notify(t.src, ('Un membre du staff prend en charge ton ticket #%d.'):format(t.id), 'success') end
    pushToStaff('gs_admin:client:ticketsChanged')
    return 'Ticket #' .. t.id .. ' pris'
end }

Actions.ticket_close = { level = 1, run = function(src, _, data)
    local t = need(Admin.tickets[tonumber(data.id)], 'Ticket introuvable.')
    need(t.status ~= 'closed', 'Déjà fermé.')
    t.status = 'closed'
    if online(t.src) then notify(t.src, ('Ton ticket #%d est clôturé. Merci !'):format(t.id), 'inform') end
    pushToStaff('gs_admin:client:ticketsChanged')
    Admin.tickets[t.id] = nil
    return 'Ticket #' .. t.id .. ' fermé'
end }

Actions.ticket_goto = { level = 1, run = function(src, _, data)
    local t = need(Admin.tickets[tonumber(data.id)], 'Ticket introuvable.')
    need(online(t.src), 'Joueur déconnecté.')
    local c = GetEntityCoords(GetPlayerPed(t.src))
    teleport(src, vec3(c.x + 1.0, c.y, c.z))
    return 'Téléporté au ticket #' .. t.id
end }

--- Exécute une action staff. Retourne ok, message.
function Admin.run(src, name, target, data)
    local action = Actions[name]
    if not action then return false, 'Action inconnue.' end
    local lvl = Admin.level(src)
    if lvl < action.level then
        Security:LogStaff(('[Staff] %s a tenté %s sans le niveau requis'):format(label(src), name))
        return false, 'Niveau insuffisant.'
    end
    if action.duty and not Admin.onDuty[src] then return false, 'Active d\'abord le mode staff.' end
    data = type(data) == 'table' and data or {}
    target = tonumber(target)
    if action.target then
        if not online(target) then return false, 'Joueur introuvable.' end
        if action.sanction and target ~= src and Admin.level(target) >= lvl then
            return false, 'Impossible sur un staff de niveau égal ou supérieur.'
        end
    end
    local targetLabel = action.target and label(target) or nil
    local ok, res = pcall(action.run, src, target, data)
    if not ok then
        if type(res) == 'table' and res.msg then return false, res.msg end
        print(('[gs_admin] erreur action %s : %s'):format(name, tostring(res)))
        return false, 'Erreur interne.'
    end
    Admin.log(src, name, targetLabel, res)
    return true, res
end

-- Callbacks NUI -------------------------------------------------------------------------------------------------

local function staffGuard(src, key, max, window)
    return Security:RateLimit(src, 'gs_admin:' .. key, max, window) and Admin.level(src) > 0
end

lib.callback.register('gs_admin:open', function(src)
    if not staffGuard(src, 'open', 10, 10000) then return nil end
    local lvl = Admin.level(src)
    local weathers, events = {}, {}
    if started('gs_weather') then weathers, events = exports.gs_weather:ListWeathers() end
    local duty = {}
    for _, job in ipairs({ 'police', 'ambulance', 'mechanic' }) do duty[job] = #JobsApi:GetOnDutyPlayers(job) end
    return {
        level = lvl, levelName = Config.LevelNames[lvl], me = src, onDuty = Admin.onDuty[src] ~= nil,
        players = Admin.playerList(), tickets = openTickets(), logs = lvl >= 2 and Admin.logs or {},
        server = {
            players = #GetPlayers(), maxPlayers = GetConvarInt('sv_maxclients', 48), staffOnDuty = (function()
                local n = 0 for _ in pairs(Admin.onDuty) do n = n + 1 end return n end)(),
            duty = duty,
            weather = started('gs_weather') and exports.gs_weather:GetWeather() or nil,
            weatherEvent = started('gs_weather') and exports.gs_weather:GetEvent() or nil,
        },
        weathers = weathers, events = events, maxJail = Config.Jail.maxMinutes,
    }
end)

--- Menu rapide : ce que ce staff peut faire (le client n'affiche que ça ; le serveur revérifie tout).
lib.callback.register('gs_admin:quick', function(src)
    if not staffGuard(src, 'quick', 10, 10000) then return nil end
    local lvl = Admin.level(src)
    local players = {}
    for _, p in ipairs(Admin.playerList()) do players[#players + 1] = { id = p.id, name = p.name } end
    return {
        level = lvl, levelName = Config.LevelNames[lvl], me = src, onDuty = Admin.onDuty[src] ~= nil, players = players,
        jobs = lvl >= 3 and JobsApi:ListJobs() or {},
        gangs = lvl >= 3 and started('gs_gangs') and exports.gs_gangs:ListGangs() or {},
    }
end)

--- Liste des items (fondateur) : pour le menu « Items ».
lib.callback.register('gs_admin:items', function(src)
    if not staffGuard(src, 'items', 5, 10000) or Admin.level(src) < 4 then return nil end
    return Bridge:ListItems()
end)

lib.callback.register('gs_admin:dossier', function(src, target)
    if not staffGuard(src, 'dossier', 20, 10000) then return nil end
    target = tonumber(target)
    if not online(target) then return nil end
    return Admin.dossier(src, target)
end)

lib.callback.register('gs_admin:action', function(src, name, target, data)
    if not staffGuard(src, 'action', 20, 10000) then return false, 'Doucement.' end
    return Admin.run(src, name, target, data)
end)

lib.callback.register('gs_admin:toggleDuty', function(src)
    if not staffGuard(src, 'duty', 3, 10000) then return nil end
    if Admin.onDuty[src] then
        local minutes = math.floor((os.time() - Admin.onDuty[src]) / 60)
        Admin.onDuty[src] = nil
        Admin.log(src, 'staff_off', nil, minutes .. ' min de service')
        TriggerClientEvent('gs_admin:client:powersOff', src)
        return false
    end
    Admin.onDuty[src] = os.time()
    Admin.log(src, 'staff_on', nil, nil)
    return true
end)

-- Cycle de vie --------------------------------------------------------------------------------------------------

AddEventHandler('gs_bridge:server:playerLoaded', function(src)
    Admin.joinedAt[src] = os.time()
    local lic = license(src)
    local j = lic and Store.jailGet(lic)
    if j and j.until_ts > os.time() then
        Admin.jailed[src] = { untilTs = j.until_ts, license = lic }
        teleport(src, Config.Jail.coords)
        TriggerClientEvent('gs_admin:client:jail', src, j.until_ts - os.time(), j.reason)
    elseif j then
        Store.jailClear(lic)
    end
end)

AddEventHandler('gs_bridge:server:playerUnloaded', function(src)
    Admin.onDuty[src], Admin.jailed[src], Admin.frozen[src], Admin.joinedAt[src] = nil, nil, nil, nil
end)

-- txAdmin : bans / warns / kicks faits depuis txAdmin publiés aussi (transparence). [API] noms d'events txAdmin
AddEventHandler('txAdmin:events:playerBanned', function(e)
    Admin.publishSanction('Bannissement', e.targetName or 'Un joueur', e.reason or '—',
        e.expiration and e.expiration ~= false and 'temporaire' or 'définitif')
end)
AddEventHandler('txAdmin:events:playerWarned', function(e)
    Admin.publishSanction('Avertissement', e.targetName or 'Un joueur', e.reason or '—')
end)
AddEventHandler('txAdmin:events:playerKicked', function(e)
    Admin.publishSanction('Expulsion', e.targetName or 'Un joueur', e.reason or '—')
end)

CreateThread(function()
    Store.init()
    for _, row in ipairs(Store.recentLogs(Config.LogHistory)) do Admin.logs[#Admin.logs + 1] = row end
    while true do
        Wait(5000)
        Admin.jailTick()
    end
end)

exports('GetStaffLevel', Admin.level)
exports('IsJailed', function(src) return Admin.jailed[src] ~= nil end)
