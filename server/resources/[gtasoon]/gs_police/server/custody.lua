-- gs_police (serveur) · V8 « Garde à vue et interrogatoire » + chien K9 (flair vérifié dans les inventaires côté serveur).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local JobsApi  = exports.gs_jobs
local C = Config.Custody
local Actions, need, label = Police.Actions, Police.need, Police.label

Custody = { list = {} } -- [src] = { cid, untilTs, room, lawyer, confessed, silence, by }

local function teleport(src, c)
    local ped = GetPlayerPed(src)
    if ped ~= 0 then SetEntityCoords(ped, c.x, c.y, c.z, false, false, false, false) if c.w then SetEntityHeading(ped, c.w) end end
end
local function dist(src, c) local ped = GetPlayerPed(src) return ped ~= 0 and #(GetEntityCoords(ped) - vec3(c.x, c.y, c.z)) or math.huge end

local function lawyerNear(target)
    for _, l in ipairs(JobsApi:GetOnDutyPlayers(C.lawyerJob)) do
        if l ~= target and Security:PlayersInRange(l, target, C.lawyerRange) then return Bridge:GetName(l) or GetPlayerName(l) end
    end
end

function Custody.release(target, msg)
    if not Custody.list[target] then return false end
    Custody.list[target] = nil
    teleport(target, C.release)
    TriggerClientEvent('gs_police:client:custody', target, 0)
    if msg then Bridge:Notify(target, msg, 'success') end
    return true
end

Actions.custody = { job = 'police', target = true, run = function(src, target, data)
    need(Player(target).state.gsCuffed == true, 'La personne doit être menottée.')
    need(not Custody.list[target] and not Police.jailed[target], 'Déjà en garde à vue ou en prison.')
    need(dist(src, C.station) <= C.stationRange, 'La garde à vue se fait au commissariat.')
    local minutes = math.floor(tonumber(data.minutes) or 20)
    need(minutes >= 1 and minutes <= C.maxMinutes, ('Durée : 1 à %d min.'):format(C.maxMinutes))
    Custody.list[target] = { cid = Bridge:GetIdentifier(target), untilTs = os.time() + minutes * 60, by = label(src) }
    Player(target).state:set('gsCuffed', nil, true)
    teleport(target, C.cell)
    TriggerClientEvent('gs_police:client:custody', target, minutes * 60)
    Bridge:Notify(target, 'Garde à vue. Tes droits : /droits (avocat, silence, aveux).', 'warning')
    return ('Garde à vue : %d min'):format(minutes)
end }

Actions.interrogate = { job = 'police', target = true, range = 12.0, run = function(src, target)
    local g = need(Custody.list[target], 'Pas en garde à vue.')
    g.room = not g.room
    teleport(target, g.room and C.room or C.cell)
    if not g.room then return 'Retour en cellule' end
    local lawyer = lawyerNear(target)
    local body = ('Interrogatoire mené par %s.\nAvocat : %s.\nAttitude : %s.'):format(label(src), lawyer and ('Me ' .. lawyer) or 'absent',
        g.confessed and 'aveux' or (g.silence and 'garde le silence' or 'déclarations libres'))
    if g.lawyer and not lawyer then body = body .. '\n⚠ Avocat demandé mais absent : vice de procédure possible.' end
    if Store.addReport then Store.addReport('Interrogatoire de ' .. (Bridge:GetName(target) or '?'), body, label(src), Bridge:GetIdentifier(src)) end
    return g.lawyer and not lawyer and 'Interrogatoire sans l\'avocat demandé : vice de procédure noté' or 'En salle d\'interrogatoire'
end }

Actions.custodyend = { job = 'police', target = true, range = 12.0, run = function(_, target)
    need(Custody.list[target], 'Pas en garde à vue.')
    Custody.release(target, 'Fin de garde à vue : tu es libre.')
    return 'Libéré'
end }

--- Droits du suspect : avocat, silence, aveux
function Custody.right(src, what, extra)
    local g = Custody.list[src]
    if not g then return false, 'Tu n\'es pas en garde à vue.' end
    if what == 'lawyer' then
        if g.lawyer then return false, 'Avocat déjà demandé.' end
        g.lawyer = true
        local c = GetEntityCoords(GetPlayerPed(src))
        for _, l in ipairs(JobsApi:GetOnDutyPlayers(C.lawyerJob)) do
            TriggerClientEvent('gs_police:client:backup', l, { x = c.x, y = c.y, z = c.z }, 'Client en garde à vue : ' .. (Bridge:GetName(src) or '?'))
        end
        return true, 'Avocat demandé. Ne dis rien sans lui.'
    elseif what == 'silence' then
        g.silence = true
        return true, 'Tu gardes le silence.'
    elseif what == 'confess' then
        g.confessed = true
        Player(src).state:set('gsConfessed', true, true)
        for _, cop in ipairs(JobsApi:GetOnDutyPlayers(Config.PoliceJob)) do Bridge:Notify(cop, (Bridge:GetName(src) or '?') .. ' passe aux aveux.', 'inform') end
        return true, ('Aveux enregistrés : peine réduite de %d %% si tu es incarcéré.'):format(math.floor(C.confessDiscount * 100))
    elseif what == 'denounce' then
        -- V12 · Témoin protégé : balancer un gang (jamais le sien pour rien : c'est le but, mais la peine est divisée par deux)
        if GetResourceState('gs_gangs') ~= 'started' then return false, 'Indisponible.' end
        if g.snitch then return false, 'Tu as déjà parlé.' end
        local known = false
        for _, gg in ipairs(exports.gs_gangs:ListGangs()) do if gg.name == extra then known = gg.label end end
        if not known then return false, 'Gang inconnu.' end
        g.snitch = extra
        Player(src).state:set('gsSnitch', extra, true)
        for _, cop in ipairs(JobsApi:GetOnDutyPlayers(Config.PoliceJob)) do Bridge:Notify(cop, ('%s balance %s. Témoin à protéger %d jours.'):format(Bridge:GetName(src) or '?', known, C.witnessDays), 'inform') end
        return true, ('Tu as parlé de %s. Peine divisée par deux si tu es incarcéré, et la police te protège %d jours (lieu sûr : GPS après ta sortie). Le gang saura que quelqu\'un a parlé, pas qui.'):format(known, C.witnessDays)
    end
    return false
end

-- V12 · Témoins protégés -------------------------------------------------------------------------------------------
Witness = { list = {} } -- [cid] = { gang, untilTs }

function Witness.protect(target, gang)
    local cid = Bridge:GetIdentifier(target)
    if not cid then return false end
    local untilTs = os.time() + C.witnessDays * 86400
    Witness.list[cid] = { gang = gang, untilTs = untilTs }
    Store.witnessSet(cid, gang, untilTs)
    local label = gang
    for _, gg in ipairs(exports.gs_gangs:ListGangs()) do if gg.name == gang then label = gg.label end end
    pcall(function() exports.gs_gangs:NotifyGang(gang, 'Un bruit court : quelqu\'un a parlé de vous aux flics. Personne ne sait qui.', 'warning') end)
    if GetResourceState('gs_rumors') == 'started' then
        pcall(function() exports.gs_rumors:Add(('quelqu\'un a balancé %s aux flics'):format(label), 'Un témoin sous protection. Le gang cherche qui.') end)
    end
    Store.addRecord(cid, ('Témoin protégé (%s) jusqu\'au %s'):format(label, os.date('%d/%m', untilTs)), 0, 0, 'Procureur')
    TriggerClientEvent('gs_police:client:witness', target, { x = C.safeHouse.x, y = C.safeHouse.y, z = C.safeHouse.z }, C.witnessDays)
    return true
end

function Witness.active(cid)
    local w = Witness.list[cid]
    if w and w.untilTs > os.time() then return w end
    if w then Witness.list[cid] = nil Store.witnessClear(cid) end
    return nil
end

--- Le témoin meurt pendant sa protection : la ville réagit
function Witness.killed(src)
    local cid = Bridge:GetIdentifier(src)
    local w = cid and Witness.active(cid)
    if not w then return false end
    local name = Bridge:GetName(src) or '?'
    local c = GetEntityCoords(GetPlayerPed(src))
    for _, cop in ipairs(JobsApi:GetOnDutyPlayers(Config.PoliceJob)) do
        TriggerClientEvent('gs_police:client:backup', cop, { x = c.x, y = c.y, z = c.z }, 'TÉMOIN PROTÉGÉ ABATTU : ' .. name)
    end
    if GetResourceState('gs_wanted') == 'started' then
        local okM, members = pcall(function() return exports.gs_gangs:MembersOnline(w.gang) end)
        for _, s in ipairs(okM and members or {}) do pcall(function() exports.gs_wanted:AddHeat(s, C.witnessHeat) end) end
    end
    if GetResourceState('gs_rumors') == 'started' then
        pcall(function() exports.gs_rumors:Add('un témoin protégé est tombé', 'La police parle de représailles. Le gang visé est dans le viseur.') end)
    end
    Witness.list[cid] = nil
    Store.witnessClear(cid)
    return true
end

AddStateBagChangeHandler('isDead', nil, function(bag, _, value)
    if value ~= true then return end
    local src = tonumber(bag:match('^player:(%d+)$') or '')
    if src and next(Witness.list) then Witness.killed(src) end
end)

exports('IsWitness', function(src) local cid = Bridge:GetIdentifier(src) return cid ~= nil and Witness.active(cid) ~= nil end)

CreateThread(function()
    Wait(2500)
    for _, w in ipairs(Store.witnessAll()) do Witness.list[w.citizenid] = { gang = w.gang, untilTs = w.until_ts } end
end)

lib.callback.register('gs_police:custodyRight', function(src, what, extra)
    if not Security:RateLimit(src, 'gs_police:custodyRight', 3, 5000) then return false, 'Doucement.' end
    return Custody.right(src, what, type(extra) == 'string' and extra:sub(1, 30) or nil)
end)
lib.callback.register('gs_police:gangsList', function(src)
    if not Security:RateLimit(src, 'gs_police:gangsList', 3, 5000) or not Custody.list[src] then return {} end
    return GetResourceState('gs_gangs') == 'started' and exports.gs_gangs:ListGangs() or {}
end)

function Custody.tick()
    local now = os.time()
    for src, g in pairs(Custody.list) do
        if not GetPlayerName(src) then Custody.list[src] = nil
        elseif now >= g.untilTs then Custody.release(src, 'Fin de garde à vue : libéré, aucune charge retenue.')
        elseif dist(src, g.room and C.room or C.cell) > C.radius then teleport(src, g.room and C.room or C.cell) end
    end
end
CreateThread(function() while true do Wait(5000) Custody.tick() end end)
AddEventHandler('playerDropped', function() Custody.list[source] = nil end)

-- K9 : le chien flaire (le serveur regarde vraiment les inventaires, le client ne voit que « marque / rien »)
local function hasAny(inv)
    for _, item in ipairs(Config.K9.items) do
        local ok, n = pcall(function() return exports.ox_inventory:Search(inv, 'count', item) end) -- [API] ox_inventory
        if ok and tonumber(n) and tonumber(n) > 0 then return true end
    end
    return false
end

Actions.k9 = { job = 'police', run = function(src, _, data)
    local job = Bridge:GetJob(src)
    need(job and job.grade >= Config.K9.minGrade, 'Grade insuffisant pour le chien.')
    if data.target then
        local t = tonumber(data.target)
        need(t and t ~= src and GetPlayerName(t) and Security:PlayersInRange(src, t, Config.K9.range), 'Personne à portée.')
        return hasAny(t) and 'Le chien marque : il a senti quelque chose sur cette personne.' or 'Le chien ne marque pas.'
    end
    local veh = NetworkGetEntityFromNetworkId(tonumber(data.netId) or 0)
    need(veh and veh ~= 0 and DoesEntityExist(veh) and GetEntityType(veh) == 2, 'Aucun véhicule.')
    need(#(GetEntityCoords(veh) - GetEntityCoords(GetPlayerPed(src))) <= Config.K9.range + 2.0, 'Trop loin du véhicule.')
    local plate = (GetVehicleNumberPlateText(veh) or ''):gsub('%s+$', '')
    local found = hasAny('trunk' .. plate) or hasAny('glove' .. plate)
    for seat = -1, 2 do
        local p = GetPedInVehicleSeat(veh, seat)
        if p and p ~= 0 and IsPedAPlayer(p) then
            local s = NetworkGetEntityOwner(p)
            if s and s > 0 and hasAny(s) then found = true end
        end
    end
    return found and 'Le chien marque le véhicule : fouille justifiée.' or 'Le chien ne marque pas le véhicule.'
end }

-- Incarcération après aveux : peine réduite ; garde à vue terminée
local jailRun = Actions.jail.run
Actions.jail.run = function(src, target, data)
    if Custody.list[target] then
        Custody.list[target] = nil
        TriggerClientEvent('gs_police:client:custody', target, 0)
        Player(target).state:set('gsCuffed', true, true) -- l'incarcération demande une personne menottée
    end
    if Player(target).state.gsConfessed and tonumber(data.minutes) then
        data.minutes = math.max(1, math.ceil(tonumber(data.minutes) * (1 - C.confessDiscount)))
        Player(target).state:set('gsConfessed', nil, true)
    end
    -- V12 : témoin qui a balancé un gang → peine divisée par deux, protection après coup
    local snitch = Player(target).state.gsSnitch
    if snitch and tonumber(data.minutes) then
        data.minutes = math.max(1, math.ceil(tonumber(data.minutes) * (1 - C.snitchDiscount)))
        Player(target).state:set('gsSnitch', nil, true)
    end
    local r = jailRun(src, target, data)
    if snitch and GetResourceState('gs_gangs') == 'started' then Witness.protect(target, snitch) end
    return r
end
