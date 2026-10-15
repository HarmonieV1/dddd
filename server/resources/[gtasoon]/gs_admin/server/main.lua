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

--- Niveau staff : 0 (joueur), 1 helper, 2 modo, 3 admin, 4 super-admin, 5 fondateur.
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
    if ped ~= 0 then
        pcall(function() Security:AllowTeleport(src, 10) end) -- V9 : pas d'alerte anti-triche pour un TP du staff
        SetEntityCoords(ped, c.x, c.y, c.z, false, false, false, false)
    end
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
    -- V12.62 · « /report 12 il me fonce dessus » : le joueur n° 12 est signalé (replay staff 30 s, gs_lives)
    local named = tonumber(message:match('^#?(%d+)%s'))
    if named and named ~= src and online(named) then t.target = named end
    Admin.tickets[t.id] = t
    Admin.ticketTimes = Admin.ticketTimes or {} -- V12.61 : rapport staff de fin de soirée
    Admin.ticketTimes[#Admin.ticketTimes + 1] = t.time
    while Admin.ticketTimes[1] and Admin.ticketTimes[1] < t.time - 172800 do table.remove(Admin.ticketTimes, 1) end -- V12.62 : 48 h gardées
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
        local pos = GetEntityCoords(GetPlayerPed(s))
        list[#list + 1] = {
            id = s, name = Bridge:GetName(s) or GetPlayerName(s), account = GetPlayerName(s), ping = GetPlayerPing(s),
            job = job and job.name or nil, duty = job and job.onduty or false,
            heat = started('gs_wanted') and exports.gs_wanted:GetHeat(s) or 0,
            staff = Admin.level(s) > 0, jailed = Admin.jailed[s] ~= nil,
            frozen = Admin.frozen[s] == true, -- V12.63 : carte en direct (F10 et appli staff)
            x = math.floor(pos.x), y = math.floor(pos.y),
        }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

function Admin.dossier(src, target, lvlOverride) -- V12.63 : lvlOverride = appli staff externe (pas de joueur derrière)
    local lvl = lvlOverride or Admin.level(src)
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
    if started('gs_quests') then d.progress = exports.gs_quests:GetSummary(target) end
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

-- V12.4 · Bannissements RoadLine, posés ET retirés depuis le jeu (txAdmin ne sait pas débannir en jeu).
-- `days` : 0 = définitif. Réservé au super-admin ; l'anti-abus (pas de sanction sur un staff de rang ≥) s'applique.
Actions.ban = { level = 4, target = true, sanction = true, run = function(src, target, data)
    local reason = reasonOf(data)
    local days = tonumber(data.days)
    need(days and days == math.floor(days) and days >= 0 and days <= 3650, 'Durée : 0 (définitif) à 3650 jours.')
    local lic = need(license(target), 'Licence introuvable.')
    local name = Bridge:GetName(target) or GetPlayerName(target) or '?'
    local untilTs = days == 0 and 0 or (os.time() + days * 86400)
    Store.banSet(lic, name, untilTs, reason, label(src))
    Store.addNote(lic, 'warn', ('Bannissement (%s) : %s'):format(days == 0 and 'définitif' or (days .. ' j'), reason), label(src))
    Admin.publishSanction('Bannissement', name, reason, days == 0 and 'définitif' or (days .. ' jour(s)'))
    DropPlayer(target, ('Banni de RoadLine RP (%s)\nMotif : %s'):format(days == 0 and 'définitif' or (days .. ' jour(s)'), reason))
    return days == 0 and 'Banni définitivement' or ('Banni %d jour(s)'):format(days)
end }

--- Lève un bannissement par licence (le joueur n'est plus en ville : on ne passe pas par une cible).
Actions.unban = { level = 4, run = function(src, _, data)
    local lic = need(Security:Sanitize(data.license, 64), 'Licence manquante.')
    local b = Store.ban(lic)
    need(Store.banClear(lic), 'Ce joueur n\'est pas banni.')
    Store.log(label(src), 'unban', b and b.name or lic, lic)
    Admin.publishSanction('Lévée de bannissement', b and b.name or lic, 'Décision du staff')
    return ('Débanni : %s'):format(b and b.name or lic)
end }

local function amountOf(data, max)
    local n = tonumber(data.amount)
    return need(n and n == math.floor(n) and n >= 1 and n <= max and n, ('Montant : 1 à %d.'):format(max))
end

Actions.givemoney = { level = 4, target = true, run = function(_, target, data)
    local account = need((data.account == 'cash' or data.account == 'bank') and data.account, 'Compte invalide.')
    local amount = amountOf(data, Config.Give.maxMoney)
    reasonOf(data)
    need(Bridge:AddMoney(target, account, amount, 'staff'), 'Échec.')
    return ('+%d $ (%s)'):format(amount, account)
end }

Actions.removemoney = { level = 4, target = true, run = function(_, target, data)
    local account = need((data.account == 'cash' or data.account == 'bank') and data.account, 'Compte invalide.')
    local amount = amountOf(data, Config.Give.maxMoney)
    reasonOf(data)
    need(Bridge:RemoveMoney(target, account, amount, 'staff'), 'Solde insuffisant.')
    return ('-%d $ (%s)'):format(amount, account)
end }

local function itemOf(data)
    -- V11.5 : le tiret est accepté (munitions ox_inventory : ammo-9, ammo-rifle…), refusées avant par erreur
    local item = need(type(data.item) == 'string' and data.item:match('^[%w_%-]+$') and data.item, 'Item invalide.')
    return need(Bridge:ItemExists(item) and item, 'Item inconnu d\'ox_inventory.')
end

-- Motif obligatoire, sauf pour le fondateur (menu rapide).
local function reasonUnlessFounder(src, data) if Admin.level(src) < 5 then reasonOf(data) end end

Actions.giveitem = { level = 4, target = true, run = function(src, target, data)
    local item = itemOf(data)
    local count = amountOf(data, Config.Give.maxItems)
    reasonUnlessFounder(src, data)
    need(Bridge:AddItem(target, item, count), 'Inventaire plein.')
    return ('+%d %s'):format(count, item)
end }

Actions.removeitem = { level = 5, target = true, run = function(_, target, data)
    local item = itemOf(data)
    local have = Bridge:GetItemCount(target, item)
    need(have > 0, 'Il n\'en a pas.')
    local count = math.min(amountOf(data, Config.Give.maxItems), have)
    need(Bridge:RemoveItem(target, item, count), 'Échec.')
    return ('-%d %s'):format(count, item)
end }

Actions.dropitem = { level = 5, duty = true, run = function(src, _, data)
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

-- Rangs staff : le fondateur seul promeut / rétrograde (0 = joueur … 4 = super-admin). Enregistré en base par licence
-- et appliqué tout de suite (add_principal) : pas besoin de redémarrer ni de toucher aux fichiers cfg.
function Admin.applyRank(lic, rank)
    local who = 'identifier.' .. lic
    for _, group in ipairs(Config.RankGroups) do ExecuteCommand(('remove_principal %s %s'):format(who, group)) end
    if rank > 0 then ExecuteCommand(('add_principal %s %s'):format(who, Config.RankGroups[rank])) end
end

Actions.setrank = { level = 5, target = true, run = function(src, target, data)
    local rank = tonumber(data.rank)
    need(rank and rank == math.floor(rank) and rank >= 0 and rank <= #Config.RankGroups, 'Rang invalide.')
    need(target ~= src, 'Tu ne peux pas changer ton propre rang.')
    need(Admin.level(target) < 5, 'Un fondateur se déclare dans secrets.cfg, pas en jeu.')
    local lic = need(license(target), 'Licence introuvable.')
    Store.rankSet(lic, rank, label(src))
    Admin.applyRank(lic, rank)
    notify(target, rank > 0 and ('Tu es maintenant %s du staff.'):format(Config.LevelNames[rank]) or 'Tu ne fais plus partie du staff.', 'inform')
    if rank == 0 then Admin.onDuty[target] = nil TriggerClientEvent('gs_admin:client:powersOff', target) end
    return rank > 0 and ('Rang : %s'):format(Config.LevelNames[rank]) or 'Retiré du staff'
end }

-- V11.5 · VIP : 2 personnages (comme le fondateur et les super-admins), rien d'autre. Donné par le fondateur, par licence.
function Admin.applyVip(lic, on)
    ExecuteCommand(('%s identifier.%s group.vip'):format(on and 'add_principal' or 'remove_principal', lic))
end

Actions.setvip = { level = 5, target = true, run = function(src, target, data)
    local lic = need(license(target), 'Licence introuvable.')
    local on = data.on == true
    Store.vipSet(lic, on, label(src))
    Admin.applyVip(lic, on)
    notify(target, on and 'Tu es VIP : un deuxième personnage t\'est ouvert.' or 'Statut VIP retiré.', 'inform')
    return on and 'VIP accordé (2 personnages)' or 'VIP retiré'
end }

--- Nombre de personnages autorisés (appelé par qbx_core, correctif posé par METTRE-A-JOUR) : 2 pour le fondateur,
--- les super-admins et les VIP, sinon nil = valeur par défaut de qbx_core (1).
function Admin.characterSlots(license2, lic)
    local function extra(id)
        if type(id) ~= 'string' or id == '' then return false end
        local who = 'identifier.' .. id
        return IsPrincipalAceAllowed(who, 'gs.admin.superadmin') or IsPrincipalAceAllowed(who, 'gs.vip')
    end
    if extra(lic) or extra(license2) then return Config.Characters.extra end
    return nil
end
exports('CharacterSlots', function(license2, lic) return Admin.characterSlots(license2, lic) end)

-- Menu rapide : pouvoirs (appliqués par le client après accord), métier / gang de test, véhicules --------

Actions.power = { level = 1, duty = true, run = function(src, _, data)
    local min = need(Config.Powers[data.power], 'Pouvoir inconnu.')
    need(Admin.level(src) >= min, 'Niveau insuffisant.')
    if data.power == 'animal' and data.model then
        local ok = false
        for _, a in ipairs(Config.Animals) do if a.model == data.model then ok = true end end
        for _, a in ipairs(Config.Peds) do if a.model == data.model then ok = true end end
        -- V12.59 : tout ped humain du jeu par son nom (préfixes de Config.PedPattern, lettres / chiffres / _ seulement)
        if not ok and type(data.model) == 'string' and #data.model <= 40 and data.model:match('^[%w_]+$') then
            for _, pat in ipairs(Config.PedPattern or {}) do if data.model:lower():match(pat) then ok = true end end
        end
        need(ok, 'Modèle inconnu (ped humain du jeu attendu, ex. a_m_y_hipster_02).')
    end
    return ('%s %s'):format(data.power, data.model or (data.on == false and 'OFF' or 'ON'))
end }

-- Points déplaçables de toutes nos ressources (gs_bridge/shared/points.lua) : posé à la position du staff.
-- V12.5 · Confirmation quelques secondes plus tard : la ressource a-t-elle VRAIMENT redémarré avec la nouvelle position ?
local function confirmPoint(src, key, res, c)
    local since = GetGameTimer()
    SetTimeout(6000, function()
        local okC, state = pcall(function() return exports.gs_bridge:CheckPoint(key, c, since) end)
        if not okC then return end
        if state == 'ok' then
            notify(src, ('✅ Vérifié : %s a redémarré avec la nouvelle position.'):format(res), 'success')
        elseif state == 'pas_relance' then
            notify(src, ('⚠️ %s n\'a pas redémarré. Console serveur : « restart %s », puis vérifie à nouveau.'):format(res, res), 'error')
        else
            notify(src, ('⚠️ %s a redémarré mais sans la nouvelle position : préviens le développeur (clé %s).'):format(res, key), 'error')
        end
    end)
end

-- V12.37 · Placement libre : `data.pose` = { x, y, z, heading } choisie à l'aperçu (gs_markers Place), vérifiée ici (nombres,
-- ≤ 60 m du staff) ; sans pose, le point est posé à la position du staff, orienté comme lui (comportement d'avant).
Actions.movepoint = { level = 4, duty = true, run = function(src, _, data)
    local ped = GetPlayerPed(src)
    local here = GetEntityCoords(ped)
    local c, w = here, GetEntityHeading(ped)
    if data.pose ~= nil then
        local pose, err = exports.gs_bridge:CleanPose(data.pose, here, 60.0)
        need(pose, err)
        c, w = vector3(pose.x, pose.y, pose.z), pose.w
    end
    local ok, res = exports.gs_bridge:SetPoint(data.key, vector4(c.x, c.y, c.z, w))
    need(ok, res)
    confirmPoint(src, data.key, res, c)
    return ('Point déplacé, %s redémarre (confirmation dans quelques secondes)'):format(res)
end }

Actions.resetpoint = { level = 4, duty = true, run = function(_, _, data)
    local ok, res = exports.gs_bridge:ResetPoint(data.key)
    need(ok, res)
    return ('Point remis à l\'origine (%s relancé)'):format(res)
end }

-- V11.6 · Retirer un point du jeu (super-admin), réversible
Actions.disablepoint = { level = 4, duty = true, run = function(_, _, data)
    local ok, res = exports.gs_bridge:DisablePoint(data.key)
    need(ok, res)
    return ('Point retiré du jeu (%s relancé)'):format(res)
end }

Actions.enablepoint = { level = 4, duty = true, run = function(_, _, data)
    local ok, res = exports.gs_bridge:EnablePoint(data.key)
    need(ok, res)
    return ('Point réactivé (%s relancé)'):format(res)
end }

-- V12.37 · PNJ et objets posés par le staff (F11 → Monde et lieux → PNJ et objets), reliés à un métier, un gang ou libres.
-- Stockés par gs_bridge (table gs_staff_peds, GlobalState.gsStaffPeds) ; super-admin et fondateur, en mode staff.
local STAFF_PED_ROLES = { duty = 'Accueil', boss = 'Direction', garage = 'Garage' }

--- Pure : cible normalisée ou nil, message. 'libre' ; 'job:<métier>:<duty|boss|garage>[n]' (le point n doit exister dans `jobs`,
--- forme de JobsApi:ListJobs) ; 'gang:<gang>' (dans `gangs`, forme de gs_gangs:ListGangs).
function Admin.staffTarget(t, jobs, gangs)
    if t == nil or t == '' or t == 'libre' then return 'libre' end
    if type(t) ~= 'string' or #t > 48 then return nil, 'Cible invalide.' end
    local job, kind, idx = t:match('^job:([%w_]+):(%a+)(%d*)$')
    if job then
        if not STAFF_PED_ROLES[kind] then return nil, 'Rôle inconnu (accueil, direction ou garage).' end
        idx = tonumber(idx) or 1
        for _, j in ipairs(jobs or {}) do
            if j.name == job then
                for _, pt in ipairs(j.points or {}) do
                    if pt.kind == kind and pt.idx == idx then return ('job:%s:%s%s'):format(job, kind, idx > 1 and idx or '') end
                end
                return nil, 'Ce métier n\'a pas ce point.'
            end
        end
        return nil, 'Métier inconnu.'
    end
    local gang = t:match('^gang:([%w_]+)$')
    if gang then
        for _, g in ipairs(gangs or {}) do if g.name == gang then return t end end
        return nil, 'Gang inconnu.'
    end
    return nil, 'Cible invalide.'
end

Actions.addstaffped = { level = 4, duty = true, run = function(src, _, data)
    local kind = need((data.kind == 'ped' or data.kind == 'prop') and data.kind, 'Type invalide (PNJ ou objet).')
    local model = need(Security:Sanitize(data.model, 64), 'Modèle obligatoire.')
    need(model:match('^[%w_]+$'), 'Nom de modèle invalide.')
    local gangs = started('gs_gangs') and exports.gs_gangs:ListGangs() or {}
    local target, terr = Admin.staffTarget(data.target, JobsApi:ListJobs(), gangs)
    need(target, terr)
    local scenario = Security:Sanitize(data.scenario, 48)
    if scenario then need(kind == 'ped' and scenario:match('^[%u_]+$') and (scenario:find('^WORLD_HUMAN_') or scenario:find('^PROP_HUMAN_') or scenario:find('^CODE_HUMAN_')), 'Scénario invalide.') end
    local pose, perr = exports.gs_bridge:CleanPose(data.pose, GetEntityCoords(GetPlayerPed(src)), 60.0)
    need(pose, perr)
    local ok, res = exports.gs_bridge:AddStaffPed({ kind = kind, target = target, model = model, scenario = scenario,
        x = pose.x, y = pose.y, z = pose.z, heading = pose.w, by = label(src) })
    need(ok, res)
    return ('%s #%d « %s » posé (%s)'):format(kind == 'ped' and 'PNJ' or 'Objet', res, model, target)
end }

Actions.delstaffped = { level = 4, duty = true, run = function(_, _, data)
    local ok, res = exports.gs_bridge:RemoveStaffPed(tonumber(data.id))
    need(ok, res)
    return ('%s #%d « %s » retiré (%s)'):format(res.kind == 'ped' and 'PNJ' or 'Objet', res.id, res.model, res.target)
end }

--- Pure : catalogue d'objets de gs_builder (shared/config.lua, `Config.Catalog`) lu dans le texte du fichier : gs_admin ne
--- charge pas la config de gs_builder et le serveur n'exécute jamais de code dynamique. { { label, icon, items = { { model, label } } } }.
function Admin.parseCatalog(text)
    local cats = {}
    if type(text) ~= 'string' then return cats end
    local body = text:match('Config%.Catalog%s*=%s*{(.*)') or ''
    for label, icon, items in body:gmatch("{%s*label%s*=%s*'([^']+)',%s*icon%s*=%s*'([^']+)',%s*items%s*=%s*{(.-)}%s*},") do
        local cat = { label = label, icon = icon, items = {} }
        for model, name in items:gmatch("{%s*model%s*=%s*'([%w_]+)',%s*label%s*=%s*'(.-)'%s*}") do
            cat.items[#cat.items + 1] = { model = model, label = (name:gsub("\\'", "'")) }
        end
        if #cat.items > 0 then cats[#cats + 1] = cat end
    end
    return cats
end

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

Actions.jobpoint = { level = 4, duty = true, run = function(src, _, data)
    local ped = GetPlayerPed(src)
    local veh = GetVehiclePedIsIn(ped, false)
    local ent = (data.kind == 'garage_spawn' and veh ~= 0) and veh or ped
    local c = GetEntityCoords(ent)
    local ok, err = JobsApi:AdminSetPoint(tostring(data.job), tostring(data.kind), tonumber(data.idx),
        vec4(c.x, c.y, c.z, GetEntityHeading(ent)))
    need(ok, tostring(err))
    return ('Point %s %s #%s placé ici'):format(data.job, data.kind, data.idx)
end }

Actions.creategang = { level = 4, duty = true, run = function(_, _, data)
    need(started('gs_gangs'), 'gs_gangs non démarré.')
    local ok, err = exports.gs_gangs:AdminCreateGang(tostring(data.name or ''):lower(), Security:Sanitize(data.label, 50), tonumber(data.color))
    need(ok, tostring(err))
    return ('Gang %s créé : place sa planque et son garage'):format(data.name)
end }

Actions.gangplace = { level = 4, duty = true, run = function(src, _, data)
    need(started('gs_gangs'), 'gs_gangs non démarré.')
    local ped = GetPlayerPed(src)
    local veh = GetVehiclePedIsIn(ped, false)
    local ent = (data.kind == 'garage' and veh ~= 0) and veh or ped
    local c = GetEntityCoords(ent)
    if data.kind == 'stash' then
        need(exports.gs_gangs:SetStash(tostring(data.gang), c), 'Gang inconnu.')
        return 'Planque / QG placé ici'
    end
    local ok, err = exports.gs_gangs:AdminSetGarage(tostring(data.gang), vec4(c.x, c.y, c.z, GetEntityHeading(ent)), tonumber(data.paint) or 0)
    need(ok, tostring(err))
    return 'Garage du gang placé ici'
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

--- Événement en un clic : annonce + GPS à tous, effet aux joueurs dans le rayon.
Actions.event = { level = 3, duty = true, run = function(src, _, data)
    local ev = need(Config.Events[data.kind], 'Événement inconnu.')
    local c = ev.at or GetEntityCoords(GetPlayerPed(src))
    local text = ev.text
    if ev.roadtrip then -- départ au premier point du carnet du mois (gs_roadbook)
        need(started('gs_roadbook'), 'gs_roadbook non démarré.')
        local at, label = exports.gs_roadbook:MonthlyStart()
        c, text = at, ('%s (%s)'):format(ev.text, label)
    end
    local seconds = ev.minutes * 60
    if ev.party then
        need(started('gs_world'), 'gs_world non démarré.')
        exports.gs_world:StartParty(seconds)
    end
    local n = 0
    for _, id in ipairs(GetPlayers()) do
        local p = tonumber(id)
        TriggerClientEvent('gs_admin:client:eventStart', p, { kind = data.kind, label = ev.label, text = text, x = c.x, y = c.y, z = c.z,
            fx = ev.fx, radius = ev.radius, seconds = seconds })
        n = n + 1
    end
    if ev.freeRaces and started('gs_races') then exports.gs_races:SetFreeEntry(seconds) end
    if started('gs_social') then exports.gs_social:Newsroom('event', ('ÉVÉNEMENT · %s : %s'):format(ev.label, text)) end
    return ('%s lancé (%d joueurs prévenus, %d min)'):format(ev.label, n, ev.minutes)
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

-- V9 : dernières alertes anti-triche (gs_security) pour le menu F11
lib.callback.register('gs_admin:acAlerts', function(src)
    if not staffGuard(src, 'acAlerts', 4, 5000) then return nil end
    local ok, list = pcall(function() return Security:GetAlerts() end)
    return ok and list or {}
end)

--- V12.4 : bannis actifs pour le menu F11 (lecture seule, pas journalisée). Super-admin uniquement.
lib.callback.register('gs_admin:bans', function(src, search)
    if not staffGuard(src, 'bans', 6, 10000) then return nil end
    if Admin.level(src) < 4 then return nil end
    local ok, list = pcall(function() return Store.bans(Security:Sanitize(search, 64), 25) end)
    if not ok or type(list) ~= 'table' then return {} end
    -- V12.35 : la date est formatée ICI (os.date n'existe pas côté client : le menu plantait au premier ban à durée)
    for _, b in ipairs(list) do
        b.when = (tonumber(b.until_ts) or 0) == 0 and 'définitif' or ('jusqu\'au ' .. os.date('%d/%m/%Y %H:%M', b.until_ts))
    end
    return list
end)

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
    for _, p in ipairs(Admin.playerList()) do players[#players + 1] = { id = p.id, name = p.name, license = lvl >= 5 and license(p.id) or nil } end
    return {
        level = lvl, levelName = Config.LevelNames[lvl], me = src, onDuty = Admin.onDuty[src] ~= nil, players = players,
        jobs = lvl >= 3 and JobsApi:ListJobs() or {}, ranks = lvl >= 5 and Config.LevelNames or nil,
        vips = lvl >= 5 and (function() local t = {} for _, r in ipairs(Store.vips()) do t[r.license] = true end return t end)() or nil,
        gangs = lvl >= 3 and started('gs_gangs') and exports.gs_gangs:ListGangs() or {},
    }
end)

--- Liste des items (fondateur) : pour le menu « Items ».
lib.callback.register('gs_admin:items', function(src)
    if not staffGuard(src, 'items', 5, 10000) or Admin.level(src) < 4 then return nil end -- super-admin et fondateur
    return Bridge:ListItems()
end)

--- V12.10 · Mappings installés : emplacement lu dans les fichiers de chaque map par server/maps.js, + conflits entre maps.
lib.callback.register('gs_admin:mappings', function(src)
    if not staffGuard(src, 'mappings', 4, 10000) or Admin.level(src) < 4 then return nil end -- Monde et lieux : super-admin et fondateur
    local ok, res = pcall(function() return exports[GetCurrentResourceName()]:MapScan() end)
    if not ok or type(res) ~= 'table' then return { maps = {}, conflicts = {}, error = tostring(res) } end
    return res
end)

--- V12.37 · Catalogue d'objets (celui de gs_builder) pour « Ajouter un objet » : super-admin et fondateur, lu une fois.
local catalogCache
lib.callback.register('gs_admin:staffCatalog', function(src)
    if not staffGuard(src, 'staffCatalog', 4, 10000) or Admin.level(src) < 4 then return nil end
    if not catalogCache then catalogCache = Admin.parseCatalog(LoadResourceFile('gs_builder', 'shared/config.lua')) end
    return catalogCache
end)

--- V12.30 · Résultat du contrôle « chez moi » (F11 → Mappings installés → Contrôler) recopié dans la console du serveur :
--- une map démarrée côté serveur mais invisible chez le joueur n'y laissait aucune trace.
local CHECK_COLOR = { ok = '^2', na = '^3', missing = '^1', partial = '^1', unreadable = '^1' }
lib.callback.register('gs_admin:mapCheckReport', function(src, list)
    if not staffGuard(src, 'mapcheck', 3, 30000) or Admin.level(src) < 4 or type(list) ~= 'table' then return false end
    local bad = 0
    for i, c in ipairs(list) do
        if i > 80 or type(c) ~= 'table' then break end
        local name = tostring(c.name or ''):match('^gsa_[%w_]+$')
        local v = CHECK_COLOR[c.v] and c.v or nil
        if name and v then
            if v ~= 'ok' and v ~= 'na' then bad = bad + 1 end
            print(('%s[gs_admin] Contrôle map (%s) %s : %s^7'):format(CHECK_COLOR[v], GetPlayerName(src) or src, name, Security:Sanitize(tostring(c.msg or ''), 220)))
        end
    end
    print(('[gs_admin] Contrôle des maps chez %s : %s'):format(GetPlayerName(src) or src, bad > 0 and ('^1%d map(s) invisible(s) chez le joueur^7'):format(bad) or '^2toutes chargées^7'))
    return true
end)

--- V12.15 · Retirer une map (F11 → Mappings installés) : super-admin et fondateur, journalisé. Arrêt immédiat + ligne
--- commentée dans cfg/addons.cfg (server/maps.js) : réversible en retirant le #.
lib.callback.register('gs_admin:disableMap', function(src, name)
    if not staffGuard(src, 'disablemap', 3, 10000) or Admin.level(src) < 4 then return false, 'Réservé au super-admin et au fondateur.' end
    if type(name) ~= 'string' or not name:match('^gsa_[%w_]+$') then return false, 'Map inconnue.' end
    local ok, res = pcall(function() return exports[GetCurrentResourceName()]:DisableMap(name, GetPlayerName(src)) end)
    if not ok or type(res) ~= 'table' then return false, 'Retrait impossible : ' .. tostring(res) end
    if res.ok then Store.log(label(src), 'disablemap', name, name) end
    return res.ok, res.msg
end)

--- V12.16 · Supprimer définitivement toutes les maps (disque, addons.cfg, archives) : super-admin et fondateur, journalisé
lib.callback.register('gs_admin:deleteAllMaps', function(src, confirm)
    if not staffGuard(src, 'deleteallmaps', 2, 30000) or Admin.level(src) < 4 then return false, 'Réservé au super-admin et au fondateur.' end
    if confirm ~= 'SUPPRIMER' then return false, 'Confirmation manquante.' end
    local ok, res = pcall(function() return exports[GetCurrentResourceName()]:DeleteAllMaps() end)
    if not ok or type(res) ~= 'table' then return false, 'Suppression impossible : ' .. tostring(res) end
    if res.ok then Store.log(label(src), 'deleteallmaps', 'toutes', res.msg) end
    return res.ok, res.msg
end)

--- V12.16 · Retirer toutes les maps d'un coup (super-admin et fondateur, journalisé)
lib.callback.register('gs_admin:disableAllMaps', function(src)
    if not staffGuard(src, 'disableallmaps', 2, 30000) or Admin.level(src) < 4 then return false, 'Réservé au super-admin et au fondateur.' end
    local ok, res = pcall(function() return exports[GetCurrentResourceName()]:DisableAllMaps(GetPlayerName(src)) end)
    if not ok or type(res) ~= 'table' then return false, 'Retrait impossible : ' .. tostring(res) end
    if res.ok then Store.log(label(src), 'disableallmaps', 'toutes', res.msg) end
    return res.ok, res.msg
end)

--- Véhicules ajoutés par IMPORTER-MODS (bloc « GTA SOON ADDONS » du catalogue Qbox) + véhicules de service ajoutés
--- aux garages des métiers : pour les retrouver sans connaître leur nom de spawn.
lib.callback.register('gs_admin:addonVehicles', function(src)
    if not staffGuard(src, 'addonveh', 5, 10000) or Admin.level(src) < 3 then return nil end
    local list, seen = {}, {}
    local text = LoadResourceFile('qbx_core', 'shared/vehicles.lua') or ''
    local block = text:match('%-%- GTA SOON ADDONS DEBUT(.-)%-%- GTA SOON ADDONS FIN') or ''
    for model, name, price in block:gmatch("%['([%w_]+)'%]%s*=%s*{%s*name%s*=%s*'([^']*)'.-price%s*=%s*(%d+)") do
        seen[model] = true
        list[#list + 1] = { model = model, name = name, price = tonumber(price) }
    end
    for _, v in ipairs(exports.gs_jobs:GetAddonVehicles() or {}) do
        if not seen[v.model] then seen[v.model] = true; list[#list + 1] = v end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
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
    for _, row in ipairs(Store.ranks()) do Admin.applyRank(row.license, row.rank) end
    for _, row in ipairs(Store.vips()) do Admin.applyVip(row.license, true) end
    for _, row in ipairs(Store.recentLogs(Config.LogHistory)) do Admin.logs[#Admin.logs + 1] = row end
    while true do
        Wait(5000)
        Admin.jailTick()
    end
end)

exports('GetStaffLevel', Admin.level)
--- V9 : alerte aux membres du staff en service (anti-triche…)
exports('NotifyStaff', function(msg) for s in pairs(Admin.onDuty) do notify(s, msg, 'warning') end return true end)
exports('IsJailed', function(src) return Admin.jailed[src] ~= nil end)
exports('IsOnDuty', function(src) return Admin.onDuty[src] ~= nil end) -- V12.60 : mode staff actif (gs_lives)
--- V12.62 · Joueurs liés à un ticket ouvert (l'auteur, et le joueur signalé s'il est nommé) : { [src] = n° de ticket }.
--- gs_lives garde leurs 30 dernières secondes d'écran tant que le ticket est ouvert (replay staff).
exports('ReportedPlayers', function()
    local out = {}
    for _, t in pairs(Admin.tickets) do
        if t.status ~= 'closed' then
            if online(t.src) then out[t.src] = t.id end
            if t.target and online(t.target) then out[t.target] = t.id end
        end
    end
    return out
end)
--- V12.61 · Chiffres depuis `since` (os.time) pour le rapport staff de fin de soirée (gs_discord) : tickets ouverts,
--- sanctions (avertissement, gel, expulsion, prison, bannissement) par type, alertes anti-triche, membres du staff actifs.
local SANCTIONS = { warn = 'avertissement(s)', freeze = 'gel(s)', kick = 'expulsion(s)', jail = 'prison(s) admin', ban = 'bannissement(s)' }
exports('NightStats', function(since)
    since = tonumber(since) or 0
    local out = { tickets = 0, openTickets = 0, sanctions = {}, staff = {}, alerts = 0 }
    for _, t in ipairs(Admin.ticketTimes or {}) do if t >= since then out.tickets = out.tickets + 1 end end
    for _, t in pairs(Admin.tickets) do if t.status ~= 'closed' then out.openTickets = out.openTickets + 1 end end
    local seen = {}
    for _, e in ipairs(Admin.logs) do
        if (e.time or 0) >= since then
            if SANCTIONS[e.action] then out.sanctions[SANCTIONS[e.action]] = (out.sanctions[SANCTIONS[e.action]] or 0) + 1 end
            if e.staff and e.staff ~= 'console' and not seen[e.staff] then seen[e.staff] = true out.staff[#out.staff + 1] = (e.staff:gsub(' %[%d+%]$', '')) end
        end
    end
    local ok, alerts = pcall(function() return Security:GetAlerts() end)
    for _, a in ipairs(ok and type(alerts) == 'table' and alerts or {}) do
        if type(a) ~= 'table' or not tonumber(a.time or a.at) or tonumber(a.time or a.at) >= since then out.alerts = out.alerts + 1 end
    end
    return out
end)
--- V12.4 · Bannissement actif d'une licence : { name, until_ts, reason, staff } ou nil. Lu par gs_onboarding à la connexion.
exports('GetBan', function(lic) return lic and Store.ban(lic) or nil end)

--- V12.4 · Bannissement automatique (pots de miel de gs_security). `days` = 0 : définitif. Jamais appliqué au staff :
--- un membre du staff qui déclencherait un piège est seulement signalé (erreur de manipulation ou test).
exports('AutoBan', function(src, reason, days)
    src = tonumber(src)
    if not src or not online(src) then return false, 'Joueur absent.' end
    local name = Bridge:GetName(src) or GetPlayerName(src) or '?'
    if Admin.level(src) > 0 then
        Security:LogStaff(('[Anti-triche] PIÈGE déclenché par un STAFF : %s · %s (aucun ban)'):format(label(src), reason), 'anticheat')
        return false, 'Staff : signalé, pas banni.'
    end
    local lic = license(src)
    days = tonumber(days) or 0
    local untilTs = days <= 0 and 0 or (os.time() + days * 86400)
    if lic then
        Store.banSet(lic, name, untilTs, reason, 'Anti-triche (automatique)')
        Store.addNote(lic, 'warn', 'Bannissement automatique : ' .. reason, 'Anti-triche')
    end
    Store.log('Anti-triche (automatique)', 'ban', ('%s [%s]'):format(name, src), reason)
    Admin.publishSanction('Bannissement', name, reason, days <= 0 and 'définitif' or (days .. ' jour(s)'))
    DropPlayer(src, ('Banni de RoadLine RP (triche détectée)\nMotif : %s\n\nContestation : notre Discord.'):format(reason))
    return true
end)

--- V10.1 · Modération à distance (commandes staff du bot Discord, rôle staff vérifié par gs_discord). Sous-ensemble
--- sûr : liste, geler, dégeler, avertir, expulser, message privé, annonce. Journalisé comme une action staff.
--- Retourne ok, texte. `staff` = pseudo Discord de l'auteur.
-- Vue d'ensemble pour le panneau web (V11) : joueurs (cartes cliquables), tickets ouverts, état du serveur
local startedAt = os.time()
function Admin.overview()
    local players = {}
    for _, id in ipairs(GetPlayers()) do
        local s = tonumber(id)
        players[#players + 1] = { id = s, name = GetPlayerName(s) or '?', char = Bridge:GetName(s) or '', ping = GetPlayerPing(s),
            frozen = Admin.frozen[s] and true or false }
    end
    table.sort(players, function(a, b) return a.id < b.id end)
    local tickets = {}
    for _, tk in ipairs(openTickets()) do
        tickets[#tickets + 1] = { id = tk.id, src = tk.src, name = tk.name, message = tk.message, age = os.time() - (tk.time or os.time()),
            claimedBy = tk.claimedBy, online = tk.online and true or false }
    end
    return { players = players, tickets = tickets, max = GetConvarInt('sv_maxclients', 0), uptime = os.time() - startedAt,
        version = GetConvar('gs_version', '?'), staffOnDuty = (function() local n = 0 for _ in pairs(Admin.onDuty) do n = n + 1 end return n end)() }
end

function Admin.remote(action, target, text, staff, extra)
    staff = tostring(staff or '?'):sub(1, 40)
    if not staff:find('·', 1, true) then staff = 'Discord · ' .. staff end -- le bot passe le pseudo seul, le web « Web · pseudo »
    if action == 'players' then
        local out = {}
        for _, id in ipairs(GetPlayers()) do
            local s = tonumber(id)
            out[#out + 1] = ('`%d` %s (%s) · %d ms%s'):format(s, GetPlayerName(s) or '?', Bridge:GetName(s) or '—', GetPlayerPing(s),
                Admin.frozen[s] and ' · gelé' or '')
        end
        return true, #out > 0 and table.concat(out, '\n') or 'Personne en ville.'
    end
    -- V12.63 · Appli staff externe : débannir, tickets (pas de joueur ciblé)
    if action == 'unban' then
        local lic = Security:Sanitize(text, 64)
        if not lic then return false, 'Licence manquante.' end
        local b = Store.ban(lic)
        if not Store.banClear(lic) then return false, 'Ce joueur n\'est pas banni.' end
        Admin.logRemote(staff, 'unban', b and b.name or lic, lic)
        Admin.publishSanction('Levée de bannissement', b and b.name or lic, 'Décision du staff')
        return true, ('Débanni : %s'):format(b and b.name or lic)
    end
    if action == 'ticket_claim' or action == 'ticket_close' then
        local t = Admin.tickets[tonumber(extra) or 0]
        if not t then return false, 'Ticket introuvable.' end
        if action == 'ticket_claim' then
            if t.status ~= 'open' then return false, 'Déjà pris en charge.' end
            t.status, t.claimedBy = 'claimed', staff
            if online(t.src) then notify(t.src, ('Un membre du staff prend en charge ton ticket #%d.'):format(t.id), 'success') end
        else
            t.status = 'closed'
            if online(t.src) then notify(t.src, ('Ton ticket #%d est clôturé. Merci !'):format(t.id), 'inform') end
            Admin.tickets[t.id] = nil
        end
        pushToStaff('gs_admin:client:ticketsChanged')
        Admin.logRemote(staff, action, '#' .. t.id)
        return true, ('Ticket #%d %s.'):format(t.id, action == 'ticket_claim' and 'pris en charge' or 'clôturé')
    end
    if action == 'announce' then
        local msg = Security:Sanitize(text, 200)
        if not msg or msg == '' then return false, 'Annonce vide.' end
        TriggerClientEvent('gs_admin:client:announce', -1, msg)
        Admin.logRemote(staff, 'announce', nil, msg)
        return true, 'Annonce envoyée en jeu.'
    end
    target = tonumber(target)
    if not online(target) then return false, 'Aucun joueur avec cet identifiant en ville.' end
    local who = label(target)
    local reason = Security:Sanitize(text, 200)
    if reason == '' then reason = nil end
    -- V12.63 : pas de sanction à distance sur un staff haut placé (mot de passe collectif de l'appli)
    local SANCTION = { freeze = true, warn = true, jail = true, kick = true, ban = true, tp = true }
    if SANCTION[action] and Admin.level(target) >= ((Config.Web or {}).protectLevel or 4) then
        return false, 'Impossible à distance sur un membre du staff de ce rang.'
    end
    -- V12.63 · Assistance depuis l'appli staff : soigner, réparer, effacer la recherche, note, téléporter, amener
    if action == 'heal' then
        TriggerClientEvent('gs_admin:client:heal', target)
        Admin.logRemote(staff, 'heal', who)
        return true, who .. ' soigné.'
    end
    if action == 'fixveh' then
        TriggerClientEvent('gs_admin:client:fixveh', target)
        Admin.logRemote(staff, 'fixveh', who)
        return true, 'Véhicule de ' .. who .. ' réparé.'
    end
    if action == 'clearheat' then
        if not started('gs_wanted') then return false, 'gs_wanted non démarré.' end
        exports.gs_wanted:ClearHeat(target)
        Admin.logRemote(staff, 'clearheat', who)
        return true, 'Recherche de ' .. who .. ' effacée.'
    end
    if action == 'note' then
        local lic = license(target)
        if not reason or not lic then return false, 'Note vide.' end
        Store.addNote(lic, 'note', reason, staff)
        Admin.logRemote(staff, 'note', who, reason)
        return true, 'Note ajoutée au dossier de ' .. who .. '.'
    end
    if action == 'tp' then -- extra = { place = n } ou { to = id du joueur }
        local e = type(extra) == 'table' and extra or {}
        local dest, where
        if tonumber(e.to) and online(tonumber(e.to)) then
            local c = GetEntityCoords(GetPlayerPed(tonumber(e.to)))
            dest, where = vec3(c.x + 1.0, c.y, c.z), label(tonumber(e.to))
        else
            local pl = ((Config.Web or {}).places or {})[tonumber(e.place) or 0]
            if pl then dest, where = pl.coords, pl.label end
        end
        if not dest then return false, 'Destination inconnue.' end
        teleport(target, dest)
        notify(target, 'Le staff t\'a téléporté : ' .. where .. '.', 'inform')
        Admin.logRemote(staff, 'tp', who, where)
        return true, ('%s téléporté : %s.'):format(who, where)
    end
    if action == 'freeze' or action == 'unfreeze' then
        local on = action == 'freeze'
        Admin.frozen[target] = on or nil
        FreezeEntityPosition(GetPlayerPed(target), on)
        notify(target, on and 'Tu es figé par le staff.' or 'Tu peux de nouveau bouger.', on and 'warning' or 'success')
        Admin.logRemote(staff, action, who, reason)
        return true, (on and '%s est gelé.' or '%s est dégelé.'):format(who)
    end
    -- V12.3 : réanimer et libérer de l'isolement (sans motif), isoler (motif + minutes) depuis le bot et l'appli staff
    if action == 'revive' then
        Bridge:Revive(target)
        TriggerClientEvent('gs_admin:client:heal', target)
        Admin.logRemote(staff, 'revive', who)
        return true, who .. ' réanimé et soigné.'
    end
    if action == 'unjail' then
        if not Admin.release(target) then return false, who .. ' n\'est pas en isolement.' end
        Admin.logRemote(staff, 'unjail', who)
        return true, who .. ' libéré de l\'isolement.'
    end
    if action == 'message' then
        if not reason then return false, 'Message vide.' end
        notify(target, 'Message du staff : ' .. reason, 'warning')
        Admin.logRemote(staff, 'message', who, reason)
        return true, 'Message envoyé à ' .. who .. '.'
    end
    if not reason then return false, 'Motif obligatoire.' end
    if action == 'warn' then
        local lic = license(target)
        if lic then Store.addNote(lic, 'warn', reason, staff) end
        TriggerClientEvent('gs_admin:client:warn', target, reason)
        Admin.publishSanction('Avertissement', Bridge:GetName(target) or GetPlayerName(target), reason)
        Admin.logRemote(staff, 'warn', who, reason)
        return true, who .. ' a été averti.'
    end
    if action == 'jail' then
        local minutes = math.tointeger(tonumber(extra)) -- V12.63 (relecture) : un entier, sinon refusé (plus de 15 min par défaut en silence)
        if not minutes or minutes < 1 or minutes > Config.Jail.maxMinutes then return false, ('Durée : 1 à %d min.'):format(Config.Jail.maxMinutes) end
        Admin.jail(target, minutes, reason, staff)
        Admin.publishSanction('Isolement', Bridge:GetName(target) or GetPlayerName(target), reason, minutes .. ' min')
        Admin.logRemote(staff, 'jail', who, ('%d min · %s'):format(minutes, reason))
        return true, ('%s isolé %d min.'):format(who, minutes)
    end
    if action == 'kick' then
        local name = Bridge:GetName(target) or GetPlayerName(target)
        Admin.logRemote(staff, 'kick', who, reason)
        DropPlayer(target, 'Expulsé par le staff : ' .. reason)
        Admin.publishSanction('Expulsion', name, reason)
        return true, who .. ' a été expulsé.'
    end
    if action == 'ban' then -- V12.63 : extra = jours (0 = définitif)
        local days = math.tointeger(tonumber(extra)) -- V12.63 (relecture) : 0,5 jour ne devient plus un bannissement définitif
        if not days or days < 0 or days > ((Config.Web or {}).maxBanDays or 3650) then return false, 'Durée : 0 (définitif) à 3650 jours (nombre entier).' end
        local lic = license(target)
        if not lic then return false, 'Licence introuvable.' end
        local name = Bridge:GetName(target) or GetPlayerName(target) or '?'
        local untilTs = days == 0 and 0 or (os.time() + days * 86400)
        local span = days == 0 and 'définitif' or (days .. ' jour(s)')
        Store.banSet(lic, name, untilTs, reason, staff)
        Store.addNote(lic, 'warn', ('Bannissement (%s) : %s'):format(span, reason), staff)
        Admin.publishSanction('Bannissement', name, reason, span)
        Admin.logRemote(staff, 'ban', who, ('%s · %s'):format(span, reason))
        DropPlayer(target, ('Banni de RoadLine RP (%s)\nMotif : %s'):format(span, reason))
        return true, ('%s banni (%s).'):format(who, span)
    end
    return false, 'Action inconnue.'
end

function Admin.logRemote(staff, action, target, details)
    table.insert(Admin.logs, 1, { staff = staff, action = action, target = target, details = details, time = os.time() })
    Admin.logs[Config.LogHistory + 1] = nil
    Store.log(staff, action, target, details)
    Security:LogStaff(('[Staff] %s → %s %s %s'):format(staff, action, target or '', details or ''))
end

-- Un seul retour (table) : lisible tel quel depuis le JavaScript du bot
exports('RemoteAction', function(action, target, text, staff, extra)
    local ok, a, b = pcall(Admin.remote, action, target, text, staff, extra)
    if not ok then return { ok = false, text = 'Erreur : ' .. tostring(a) } end
    return { ok = a == true, text = b or '' }
end)

-- V12.63 · Courbe « joueurs en ville » de l'appli staff : un point toutes les 5 min, 24 h gardées (mémoire)
Admin.history = {}
CreateThread(function()
    while true do
        Admin.history[#Admin.history + 1] = { t = os.time(), n = #GetPlayers() }
        while #Admin.history > 288 do table.remove(Admin.history, 1) end
        Wait(300000)
    end
end)
function Admin.openTickets() return openTickets() end

-- Version RoadLine affichée au démarrage (console) : savoir d'un coup d'œil quelle version tourne
CreateThread(function() print(('^5[RoadLine RP]^7 version %s'):format(GetConvar('gs_version', 'inconnue'))) end)
