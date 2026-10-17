-- gs_admin (serveur) · V12.63 · Mises en scène du staff (admin et plus) et chasse au trésor.
--   · Enlèvement : une camionnette embarque le joueur, écran noir, puis expulsion (motif publié comme une expulsion).
--   · Arrestation PNJ : un policier plaque et menotte le joueur, fondu, puis isolement dans une cellule de Mission Row.
--   La scène se joue chez le joueur visé (entités réseau, visibles des autres). Le serveur applique la sanction à la fin de la
--   scène OU au bout de Config.Scenes.*.maxSeconds quoi qu'il arrive, et supprime lui-même les entités de la scène.
--   · Chasse au trésor (événement) : mallette cachée à la position du staff, zone approximative pour tout le monde, prime au
--   premier qui la ramasse (vérifiée ici : distance, une seule fois, jamais un membre du staff).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local S = Config.Scenes or {}
local H = Config.Hunt or {}

Admin.scenes = {} -- [cible] = { kind, reason, minutes, staff, ents = { netId } }
Admin.hunt = nil  -- { at, prize, by, untilAt }

local function online(src) return type(src) == 'number' and GetPlayerName(src) ~= nil end
local function label(src) return ('%s [%s]'):format(GetPlayerName(src) or '?', tostring(src)) end
local function need(v, msg) if not v then error({ msg = msg }, 0) end return v end
local function nameOf(src) local ok, n = pcall(function() return Bridge:GetName(src) end) return (ok and n) or GetPlayerName(src) or '?' end

local function deleteEnts(list)
    for _, net in ipairs(list or {}) do
        local e = NetworkGetEntityFromNetworkId(net)
        if e and e ~= 0 and DoesEntityExist(e) then DeleteEntity(e) end
    end
end

--- Fin de scène : entités supprimées, sanction appliquée (une seule fois)
function Admin.finishScene(target)
    local s = Admin.scenes[target]
    if not s then return false end
    Admin.scenes[target] = nil
    deleteEnts(s.ents)
    if not online(target) then return true end
    if s.kind == 'desert' then -- V12.65 : version douce, sans expulsion
        local cash = (S.desert.takeCash and Bridge:GetMoney(target, 'cash')) or 0
        if cash > 0 then Bridge:RemoveMoney(target, 'cash', cash, 'relâché dans le désert') end
        TriggerClientEvent('ox_lib:notify', target, { title = 'Relâché dans le désert', type = 'error', duration = 9000,
            description = cash > 0 and ('Ils sont partis avec tes %d $ en liquide… et tes vêtements.'):format(cash) or 'Ils sont partis avec tes vêtements.' })
        Admin.logRemote('Mise en scène', 'desert', label(target), ('relâché dans le désert (%d $ pris) · %s · par %s'):format(cash, s.reason, s.staff))
        return true
    end
    if s.kind == 'transfer' then -- V12.65 : arrivé à Bolingbroke (ou délai écoulé) = isolement
        Admin.jail(target, s.minutes, s.reason, s.staff)
        return true
    end
    if s.kind == 'kidnap' then
        -- V12.64 : entités supprimées d'abord, expulsion 1,5 s plus tard (le jeu du joueur se ferme proprement)
        local msg = ('Embarqué dans une camionnette par des inconnus… (expulsé par le staff : %s)'):format(s.reason)
        SetTimeout(1500, function() if online(target) then DropPlayer(target, msg) end end)
    else
        Admin.jail(target, s.minutes, s.reason, s.staff, S.arrest.cell)
    end
    return true
end

local function startScene(src, target, kind, data, minutes)
    local reason = need(Security:Sanitize(data.reason, 200), 'Motif obligatoire.')
    need(not Admin.scenes[target], 'Une mise en scène est déjà en cours sur ce joueur.')
    need(not (Admin.jailed and Admin.jailed[target]), 'Ce joueur est déjà isolé.')
    local cfg, maxS = S[kind], S[kind].maxSeconds or 30
    if kind == 'arrest' and data.interrogation and S.arrest.interrogation then -- V12.65 : interrogatoire avant la cellule
        cfg = {}
        for k, v in pairs(S.arrest) do cfg[k] = v end
        cfg.interrogate = true
        maxS = S.arrest.interrogation.maxSeconds
    end
    Admin.scenes[target] = { kind = kind, reason = reason, minutes = minutes, staff = label(src), staffSrc = src, ents = {}, interrogation = cfg.interrogate }
    pcall(function() Security:AllowTeleport(target, maxS + 10) end)
    TriggerClientEvent('gs_admin:client:scene', target, kind, cfg)
    SetTimeout(maxS * 1000, function() Admin.finishScene(target) end)
    return reason
end

local Actions = Admin.actions

-- V12.65 · Relâché dans le désert (sans argent liquide ni vêtements, pas d'expulsion)
Actions.desert = { level = (S.levels and S.levels.desert) or S.level or 3, target = true, sanction = true, run = function(src, target, data)
    startScene(src, target, 'desert', data)
    return 'Camionnette en route : relâché dans le désert, sans liquide ni vêtements'
end }

-- V12.65 · Transfert en fourgon vers Bolingbroke, attaquable (annonce Weazel optionnelle)
Actions.transfer = { level = (S.levels and S.levels.transfer) or S.level or 3, target = true, sanction = true, run = function(src, target, data)
    local minutes = tonumber(data.minutes) or S.transfer.minutes
    need(minutes == math.floor(minutes) and minutes >= 1 and minutes <= Config.Jail.maxMinutes, ('Durée : 1 à %d min.'):format(Config.Jail.maxMinutes))
    local reason = startScene(src, target, 'transfer', data, minutes)
    Admin.publishSanction('Isolement', nameOf(target), reason, minutes .. ' min (transfert)')
    if data.announce and GetResourceState('gs_social') == 'started' then
        pcall(function() exports.gs_social:Newsroom('police', 'FLASH · Un fourgon de transfert de détenu quitte Mission Row en direction de Bolingbroke.') end)
    end
    return ('Fourgon parti (%d min d\'isolement à l\'arrivée%s) · %s'):format(minutes, data.announce and ', annoncé sur Weazel' or '', reason)
end }

--- Le détenu dit qu'on l'a libéré : vérifié ici (fourgon détruit ou absent, ou conducteur à terre)
lib.callback.register('gs_admin:transferFreed', function(src)
    if not Security:RateLimit(src, 'gs_admin:transferFreed', 3, 10000) then return false end
    local s = Admin.scenes[src]
    if not s or s.kind ~= 'transfer' or not s.vanOk or #s.ents < 2 then return false end -- V12.65 (relecture) : fourgon vérifié d'abord
    local van, driver = NetworkGetEntityFromNetworkId(s.ents[1]), NetworkGetEntityFromNetworkId(s.ents[2])
    if not van or van == 0 or not DoesEntityExist(van) then return false end -- fourgon disparu : pas une évasion
    local broken = GetVehicleEngineHealth(van) <= S.transfer.engineFail
    local downed = driver and driver ~= 0 and DoesEntityExist(driver) and GetEntityHealth(driver) <= 0
    if not (broken or downed) then return false end
    Admin.scenes[src] = nil
    SetTimeout(20000, function() deleteEnts(s.ents) end) -- le temps de s'enfuir
    Admin.logRemote('Mise en scène', 'transfer', label(src), ('ÉVADÉ pendant le transfert (%s) · lancé par %s'):format(broken and 'fourgon arrêté' or 'conducteur à terre', s.staff))
    for staffSrc in pairs(Admin.onDuty or {}) do
        TriggerClientEvent('ox_lib:notify', staffSrc, { title = 'Transfert', description = ('%s s\'est évadé du fourgon !'):format(label(src)), type = 'error', duration = 10000 })
    end
    return true
end)

-- V12.65 · Interrogatoire avant la cellule : les réponses arrivent au staff qui a lancé la scène et au journal
RegisterNetEvent('gs_admin:server:interrogation', function(answers)
    local src = source
    if not Security:RateLimit(src, 'gs_admin:interrogation', 2, 30000) then return end
    local s = Admin.scenes[src]
    if not s or s.kind ~= 'arrest' or not s.interrogation or type(answers) ~= 'table' then return end
    local qs, lines = S.arrest.interrogation.questions, {}
    for i = 1, #qs do lines[#lines + 1] = ('%s → %s'):format(qs[i], Security:Sanitize(answers[i], 200) or '(silence)') end
    local text = table.concat(lines, ' | ')
    s.interrogation = nil -- une seule fois
    Admin.logRemote('Interrogatoire', 'npcarrest', label(src), text)
    if s.staffSrc and GetPlayerName(s.staffSrc) then
        TriggerClientEvent('ox_lib:notify', s.staffSrc, { title = 'Interrogatoire · ' .. label(src), description = text, type = 'inform', duration = 20000 })
    end
end)

-- V12.65 · Mises en scène d'ambiance (sans sanction) --------------------------------------------------------------------
Admin.stages = {} -- [cible] = { kind, ents, untilAt }
local function endStage(target)
    local st = Admin.stages[target]
    if not st then return end
    Admin.stages[target] = nil
    deleteEnts(st.ents)
end
Admin.endStage = endStage

Actions.stage = { level = S.level or 3, target = true, run = function(src, target, data)
    local kind = type(data) == 'table' and data.kind or nil
    local cfg = need(S.stages and S.stages[kind], 'Mise en scène inconnue.')
    need(Admin.level(src) >= (cfg.level or 4), 'Réservé aux super-admins et au fondateur.') -- V12.65 : niveau par scène
    need(not Admin.scenes[target], 'Une mise en scène est déjà en cours sur ce joueur.')
    local text
    if kind == 'call' then text = need(Security:Sanitize(data.text, 300), 'Écris ce que dit la voix au téléphone.') end
    endStage(target)
    Admin.stages[target] = { kind = kind, ents = {}, untilAt = os.time() + cfg.seconds }
    TriggerClientEvent('gs_admin:client:stage', target, kind, cfg, text)
    SetTimeout((cfg.seconds + 20) * 1000, function()
        local st = Admin.stages[target]
        if st and st.untilAt <= os.time() then endStage(target) end
    end)
    return ('%s lancé (%d s)%s'):format(cfg.label, cfg.seconds, text and (' : « ' .. text .. ' »') or '')
end }

lib.callback.register('gs_admin:stageDone', function(src)
    if not Security:RateLimit(src, 'gs_admin:stageDone', 3, 10000) then return false end
    endStage(src)
    return true
end)

Actions.kidnap = { level = (S.levels and S.levels.kidnap) or S.level or 3, target = true, sanction = true, run = function(src, target, data)
    local reason = startScene(src, target, 'kidnap', data)
    Admin.publishSanction('Expulsion', nameOf(target), reason)
    return 'Camionnette en route : expulsion à la fin de la scène'
end }

Actions.npcarrest = { level = (S.levels and S.levels.npcarrest) or S.level or 3, target = true, sanction = true, run = function(src, target, data)
    local minutes = tonumber(data.minutes) or S.arrest.minutes
    need(minutes == math.floor(minutes) and minutes >= 1 and minutes <= Config.Jail.maxMinutes, ('Durée : 1 à %d min.'):format(Config.Jail.maxMinutes))
    local reason = startScene(src, target, 'arrest', data, minutes)
    Admin.publishSanction('Isolement', nameOf(target), reason, minutes .. ' min')
    if data.interrogation then return ('Policier en route : interrogatoire, puis %d min de cellule (réponses envoyées ici)'):format(minutes) end
    return ('Policier en route : %d min de cellule à Mission Row'):format(minutes)
end }

--- Le joueur visé signale les entités de sa scène (le serveur les supprimera) : 6 au plus, entiers seulement
lib.callback.register('gs_admin:sceneEnts', function(src, nets)
    if not Security:RateLimit(src, 'gs_admin:sceneEnts', 6, 10000) then return false end
    local s = Admin.scenes[src] or (Admin.stages and Admin.stages[src]) -- V12.65 : aussi les scènes d'ambiance
    if not s or type(nets) ~= 'table' then return false end
    for i = 1, math.min(#nets, 6) do
        local n = math.tointeger(tonumber(nets[i]))
        local e = n and NetworkGetEntityFromNetworkId(n)
        -- V12.65 (relecture) : seulement une entité qui existe, créée par ce joueur, et jamais un joueur
        if e and e ~= 0 and DoesEntityExist(e) and NetworkGetEntityOwner(e) == src and not (GetEntityType(e) == 1 and IsPedAPlayer(e)) and #s.ents < 6 then
            s.ents[#s.ents + 1] = n
            if s.kind == 'transfer' and #s.ents == 1 and GetEntityType(e) == 2 and GetEntityModel(e) == GetHashKey(S.transfer.van) then s.vanOk = true end
        end
    end
    return true
end)

--- Fin de la scène côté joueur (écran noir) : sanction tout de suite
lib.callback.register('gs_admin:sceneDone', function(src)
    if not Security:RateLimit(src, 'gs_admin:sceneDone', 3, 10000) then return false end
    return Admin.finishScene(src)
end)

AddEventHandler('playerDropped', function()
    local s = Admin.scenes[source]
    if s then Admin.scenes[source] = nil deleteEnts(s.ents) end
    if Admin.stages and Admin.stages[source] then Admin.endStage(source) end -- V12.65
end)

-- Chasse au trésor ------------------------------------------------------------------------------------------------------
function Admin.startHunt(src, ev, data)
    need(not (Admin.hunt and os.time() < Admin.hunt.untilAt), 'Une chasse au trésor est déjà en cours.')
    local prize = math.tointeger(tonumber(data.prize)) or H.prize or 1500
    need(prize >= 100 and prize <= (H.maxPrize or 5000), ('Prime : 100 à %d $.'):format(H.maxPrize or 5000))
    if prize > (H.prize or 1500) then need(src ~= 0 and Admin.level(src) >= (H.bigPrizeLevel or 4), ('Prime au-delà de %d $ : super-admin.'):format(H.prize or 1500)) end
    local c = data.at or GetEntityCoords(GetPlayerPed(src)) -- V12.65 : lieu imposé (événement programmé)
    local at = vec3(c.x, c.y, c.z)
    -- zone affichée : centrée à côté de la mallette (jamais dessus), rayon `ev.radius`
    local a, r = math.random() * 2 * math.pi, ev.radius * (0.25 + math.random() * 0.4)
    local zone = vec3(at.x + math.cos(a) * r, at.y + math.sin(a) * r, at.z)
    Admin.hunt = { at = at, prize = prize, by = src ~= 0 and label(src) or 'programmé', untilAt = os.time() + ev.minutes * 60 }
    local n = 0
    for _, id in ipairs(GetPlayers()) do
        TriggerClientEvent('gs_admin:client:huntStart', tonumber(id), { zone = zone, radius = ev.radius, at = at, prize = prize,
            seconds = ev.minutes * 60, text = ev.text, label = ev.label })
        n = n + 1
    end
    if GetResourceState('gs_social') == 'started' then
        pcall(function() exports.gs_social:Newsroom('event', ('ÉVÉNEMENT · %s : %d $ pour le premier qui trouve la mallette !'):format(ev.label, prize)) end)
    end
    return ('%s lancée : %d $ (%d joueurs prévenus, %d min)'):format(ev.label, prize, n, ev.minutes)
end

lib.callback.register('gs_admin:huntClaim', function(src)
    if not Security:RateLimit(src, 'gs_admin:huntClaim', 3, 5000) then return false, 'Doucement.' end
    local h = Admin.hunt
    if not h or os.time() >= h.untilAt then return false, 'Plus de trésor à trouver.' end
    if Admin.level(src) > 0 then return false, 'Le staff ne ramasse pas le trésor.' end
    if not Security:InRange(src, h.at, (H.pickup or 3.0) + 1.0) then return false, 'Approche-toi de la mallette.' end
    Admin.hunt = nil
    Bridge:AddMoney(src, 'bank', h.prize, 'chasse au trésor')
    local who = nameOf(src)
    TriggerClientEvent('gs_admin:client:huntEnd', -1, who)
    Admin.logRemote('Chasse au trésor', 'hunt', label(src), ('%d $ (cachée par %s)'):format(h.prize, h.by))
    return true, ('Trésor trouvé : +%d $ en banque !'):format(h.prize)
end)
