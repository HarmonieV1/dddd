-- gs_heists (serveur) : gros coups en duo. Rôles, phases et paiement décidés ici ; chaque action en 2 temps (begin / finish).
local Security  = exports.gs_security
local Bridge    = exports.gs_bridge
local JobsApi   = exports.gs_jobs
local WantedApi = exports.gs_wanted

Big = { sessions = {}, cooldowns = {}, byPlayer = {}, pending = {}, scouted = {} } -- scouted[cid][site][i] = os.time()
local function started(res) return GetResourceState(res) == 'started' end
local ROLES = { hacker = 'Pirate', driver = 'Conducteur' }

local function nearPoint(src, c, r) return Security:InRange(src, c, r + Config.Tolerance) end

local function phaseInfo(sess, role)
    local site = Config.Big[sess.id]
    if sess.phase == 'hack' then
        return { phase = 'hack', site = sess.id, role = role, mine = role == 'hacker', label = 'Pirater le terminal', coords = { site.terminal } }
    elseif sess.phase == 'loot' then
        local pts = {}
        for i, c in ipairs(site.vault) do if not sess.done[i] then pts[#pts + 1] = c end end
        return { phase = 'loot', site = sess.id, role = role, mine = role == 'driver', label = 'Vider les coffres', coords = pts }
    end
    return { phase = 'escape', role = role, label = 'Fuite : le conducteur au volant, le pirate avec lui', coords = {}, from = site.center,
             distance = site.escapeDistance, timeLeft = math.max(0, site.escapeTime - (os.time() - sess.escapeAt)) }
end

local function sync(sess)
    for role, src in pairs({ hacker = sess.hacker, driver = sess.driver }) do
        TriggerClientEvent('gs_heists:client:bigPhase', src, phaseInfo(sess, role))
    end
end

local function close(sess, reason, success)
    Big.sessions[sess.id] = nil
    Big.cooldowns[sess.id] = os.time() + Config.Big[sess.id].cooldown
    for _, src in ipairs({ sess.hacker, sess.driver }) do
        Big.byPlayer[src], Big.pending[src] = nil, nil
        TriggerClientEvent('gs_heists:client:bigPhase', src, nil, reason, success)
    end
end

--- Lancer un gros coup : le joueur choisit son rôle, le partenaire de duo prend l'autre.
lib.callback.register('gs_heists:bigStart', function(src, id, role)
    if not Security:RateLimit(src, 'gs_heists:bigStart', 3, 10000) then return false, 'Doucement.' end
    local site = Config.Big[id]
    if not site or not ROLES[role] then return false, 'Invalide.' end
    if Big.byPlayer[src] then return false, 'Tu es déjà dans un gros coup.' end
    if GetResourceState('gs_duo') ~= 'started' then return false, 'Il faut un partenaire de duo.' end
    local partner = exports.gs_duo:GetPartner(src)
    if not partner or not Bridge:IsLoaded(partner) then return false, 'Il te faut ton partenaire de duo (F7), en ville.' end
    if Big.byPlayer[partner] then return false, 'Ton partenaire est déjà occupé.' end
    if JobsApi:IsOnDutyAs(src, Config.PoliceJob) or JobsApi:IsOnDutyAs(partner, Config.PoliceJob) then return false, 'Pas en service de police.' end
    local startAt = site.start or site.center
    if not nearPoint(src, startAt, Config.BigStartRadius) or not nearPoint(partner, startAt, Config.BigStartRadius) then
        return false, 'Vous devez être tous les deux sur place.'
    end
    if GetSelectedPedWeapon(GetPlayerPed(src)) == GetHashKey('WEAPON_UNARMED') then return false, 'Il te faut une arme en main.' end
    if Big.sessions[id] then return false, 'Un coup est déjà en cours ici.' end
    if (Big.cooldowns[id] or 0) > os.time() then return false, 'L\'endroit est sous haute surveillance, reviens plus tard.' end
    if Heists.policeCount() < site.minPolice then return false, ('Pas assez de policiers en ville (%d requis).'):format(site.minPolice) end
    if site.scout and not (Big.hasScouted(src, id) or Big.hasScouted(partner, id)) then
        return false, ('Repérage d\'abord : visitez les %d points de repérage, il y a moins de 48 h.'):format(#site.scout)
    end
    local other = role == 'hacker' and 'driver' or 'hacker'
    local sess = { id = id, phase = 'hack', done = {}, startedAt = os.time(), [role] = src, [other] = partner, primary = Big.pickPrimary(site) }
    Big.sessions[id] = sess
    Big.byPlayer[src], Big.byPlayer[partner] = id, id
    Security:LogStaff(('[Gros coup] %s (%s) et partenaire lancent %s'):format(GetPlayerName(src), ROLES[role], site.label), 'jobs')
    Bridge:Notify(partner, ('Gros coup lancé : tu es %s.'):format(ROLES[other]), 'inform')
    sync(sess)
    return true, ('Tu es %s.'):format(ROLES[role])
end)

local function mySession(src)
    local id = Big.byPlayer[src]
    local sess = id and Big.sessions[id]
    local role = sess and (sess.hacker == src and 'hacker' or 'driver')
    return sess, role
end

--- Début de l'action du rôle pour la phase courante (piratage, pillage d'un coffre).
lib.callback.register('gs_heists:bigBegin', function(src, point)
    if not Security:RateLimit(src, 'gs_heists:bigBegin', 5, 10000) then return false, 'Doucement.' end
    local sess, role = mySession(src)
    if not sess then return false, 'Aucun gros coup en cours.' end
    if Big.pending[src] then return false, 'Déjà occupé.' end
    local site = Config.Big[sess.id]
    if sess.phase == 'hack' then
        if role ~= 'hacker' then return false, 'C\'est le boulot du pirate.' end
        if not nearPoint(src, site.terminal, 1.8) then return false, 'Trop loin du terminal.' end
        Big.pending[src] = { kind = 'hack', doneAt = GetGameTimer() + site.hackAction - 750 }
        return true, site.hackAction, 'Piratage du système…'
    elseif sess.phase == 'loot' then
        if role ~= 'driver' then return false, 'C\'est le boulot du conducteur.' end
        point = tonumber(point)
        local c = point and site.vault[point]
        if not c or sess.done[point] then return false, 'Coffre invalide ou déjà vidé.' end
        if not nearPoint(src, c, 1.8) then return false, 'Trop loin du coffre.' end
        Big.pending[src] = { kind = 'loot', point = point, doneAt = GetGameTimer() + site.lootAction - 750 }
        return true, site.lootAction, 'Vidage du coffre…'
    end
    return false, 'Il ne reste plus qu\'à fuir.'
end)

lib.callback.register('gs_heists:bigFinish', function(src)
    if not Security:RateLimit(src, 'gs_heists:bigFinish', 5, 10000) then return false, 'Doucement.' end
    local p = Big.pending[src]
    Big.pending[src] = nil
    local sess, role = mySession(src)
    if not p or not sess or GetGameTimer() < p.doneAt then return false, 'Interrompu.' end
    local site = Config.Big[sess.id]
    if p.kind == 'hack' and sess.phase == 'hack' then
        if not nearPoint(src, site.terminal, 1.8) then return false, 'Tu t\'es éloigné.' end
        local alarm = math.random() < site.hackFail
        WantedApi:ReportCrime(src, 'bank', site.center, { alarm = alarm })
        if alarm and site.guards then TriggerClientEvent('gs_heists:client:guards', src, sess.id) end -- gardes créés par le pirate
        sess.phase = 'loot'
        if not alarm and started('gs_wanted') then exports.gs_wanted:BlindCameras(site.center, 80.0) end -- caméras aveuglées quelques minutes
        sync(sess)
        return true, alarm and 'Piratage réussi… mais une alarme s\'est déclenchée ! Vite, les coffres.' or 'Alarme coupée. Le conducteur peut vider les coffres.'
    elseif p.kind == 'loot' and sess.phase == 'loot' and not sess.done[p.point] then
        if not nearPoint(src, site.vault[p.point], 1.8) then return false, 'Tu t\'es éloigné.' end
        sess.done[p.point] = true
        local left = 0
        for i in ipairs(site.vault) do if not sess.done[i] then left = left + 1 end end
        if left == 0 then sess.phase, sess.escapeAt = 'escape', os.time() end
        sync(sess)
        return true, left > 0 and ('Coffre vidé. Encore %d.'):format(left) or 'Tout est vidé : FUITE ! Conducteur au volant, pirate à bord.'
    end
    return false, 'Trop tard.'
end)

local function payout(sess)
    local site = Config.Big[sess.id]
    local total = math.floor(math.random(site.reward[1], site.reward[2]) * Heists.multiplier(sess.driver, site) * (sess.primary and sess.primary.mult or 1))
    local each = total // 2
    local lines = {}
    for _, src in ipairs({ sess.hacker, sess.driver }) do
        lines[#lines + 1] = Heists.giveLoot(src, each)
        if started('gs_quests') then exports.gs_quests:Reward(src, 'heist') end
    end
    Security:LogStaff(('[Gros coup] %s réussi : %d $ (%d chacun)'):format(site.label, total, each), 'jobs')
    return ('%sButin partagé : %s chacun'):format(sess.primary and (sess.primary.label .. ' récupéré(e). ') or '', lines[1])
end

--- Vérifie l'avancée des fuites et les échecs (toutes les 2 s, seulement s'il y a une session).
function Big.tick()
    for _, sess in pairs(Big.sessions) do
        local site = Config.Big[sess.id]
        local dead
        for _, src in ipairs({ sess.hacker, sess.driver }) do
            if not Bridge:IsLoaded(src) or Bridge:IsDowned(src) then dead = src end
        end
        if dead then close(sess, 'Le coup a échoué : un des deux est à terre ou parti.', false)
        elseif sess.phase ~= 'escape' and os.time() - sess.startedAt > 900 then close(sess, 'Le coup a échoué : trop long.', false)
        elseif sess.phase == 'escape' then
            local dped, hped = GetPlayerPed(sess.driver), GetPlayerPed(sess.hacker)
            local veh = dped ~= 0 and GetVehiclePedIsIn(dped, false) or 0
            if os.time() - sess.escapeAt > site.escapeTime then close(sess, 'Fuite ratée : la police vous a rattrapés.', false)
            elseif veh ~= 0 and GetPedInVehicleSeat(veh, -1) == dped and #(GetEntityCoords(dped) - site.center) >= site.escapeDistance
                and #(GetEntityCoords(dped) - GetEntityCoords(hped)) <= Config.BigPartnerRadius then
                close(sess, payout(sess), true)
            end
        end
    end
end

AddEventHandler('gs_bridge:server:playerUnloaded', function(src)
    local sess = mySession(src)
    if sess then close(sess, 'Le coup a échoué : ton partenaire est parti.', false) end
end)

CreateThread(function()
    while true do
        Wait(2000)
        if next(Big.sessions) then Big.tick() end
    end
end)

--- Cible principale (sites avec `primary`) : tirage pondéré, la plus rare a sa propre chance.
function Big.pickPrimary(site)
    if not site.primary then return nil end
    local common = {}
    for _, p in ipairs(site.primary) do
        if p.chance then if math.random() < p.chance then return p end else common[#common + 1] = p end
    end
    return common[math.random(#common)]
end

function Big.hasScouted(src, id)
    local site = Config.Big[id]
    local cid = Bridge:GetIdentifier(src)
    local s = cid and Big.scouted[cid] and Big.scouted[cid][id]
    if not s then return false end
    for i in ipairs(site.scout) do
        if not s[i] or os.time() - s[i] > site.scoutValid then return false end
    end
    return true
end

--- Repérage : photo d'un point (sur place). Retourne ok, message.
lib.callback.register('gs_heists:scout', function(src, id, i)
    if not Security:RateLimit(src, 'gs_heists:scout', 5, 10000) then return false, 'Doucement.' end
    local site = Config.Big[id]
    i = tonumber(i)
    local c = site and site.scout and i and site.scout[i]
    if not c then return false, 'Invalide.' end
    if not nearPoint(src, c, 8.0) then return false, 'Trop loin du point de repérage.' end
    local cid = Bridge:GetIdentifier(src)
    Big.scouted[cid] = Big.scouted[cid] or {}
    Big.scouted[cid][id] = Big.scouted[cid][id] or {}
    Big.scouted[cid][id][i] = os.time()
    local n = 0
    for j in ipairs(site.scout) do if Big.scouted[cid][id][j] then n = n + 1 end end
    return true, n >= #site.scout and 'Repérage terminé : le coup peut être lancé (48 h).' or ('Repérage %d / %d.'):format(n, #site.scout)
end)

lib.callback.register('gs_heists:bigSites', function(src)
    if not Security:RateLimit(src, 'gs_heists:bigSites', 5, 10000) then return nil end
    return { inSession = Big.byPlayer[src] ~= nil }
end)
