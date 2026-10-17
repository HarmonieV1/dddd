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
    Admin.scenes[target] = { kind = kind, reason = reason, minutes = minutes, staff = label(src), ents = {} }
    pcall(function() Security:AllowTeleport(target, (S[kind].maxSeconds or 30) + 10) end)
    TriggerClientEvent('gs_admin:client:scene', target, kind, S[kind])
    SetTimeout((S[kind].maxSeconds or 30) * 1000, function() Admin.finishScene(target) end)
    return reason
end

local Actions = Admin.actions

Actions.kidnap = { level = S.level or 3, target = true, sanction = true, run = function(src, target, data)
    local reason = startScene(src, target, 'kidnap', data)
    Admin.publishSanction('Expulsion', nameOf(target), reason)
    return 'Camionnette en route : expulsion à la fin de la scène'
end }

Actions.npcarrest = { level = S.level or 3, target = true, sanction = true, run = function(src, target, data)
    local minutes = tonumber(data.minutes) or S.arrest.minutes
    need(minutes == math.floor(minutes) and minutes >= 1 and minutes <= Config.Jail.maxMinutes, ('Durée : 1 à %d min.'):format(Config.Jail.maxMinutes))
    local reason = startScene(src, target, 'arrest', data, minutes)
    Admin.publishSanction('Isolement', nameOf(target), reason, minutes .. ' min')
    return ('Policier en route : %d min de cellule à Mission Row'):format(minutes)
end }

--- Le joueur visé signale les entités de sa scène (le serveur les supprimera) : 6 au plus, entiers seulement
lib.callback.register('gs_admin:sceneEnts', function(src, nets)
    local s = Admin.scenes[src]
    if not s or type(nets) ~= 'table' then return false end
    for i = 1, math.min(#nets, 6) do
        local n = math.tointeger(tonumber(nets[i]))
        if n and #s.ents < 6 then s.ents[#s.ents + 1] = n end
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
end)

-- Chasse au trésor ------------------------------------------------------------------------------------------------------
function Admin.startHunt(src, ev, data)
    need(not (Admin.hunt and os.time() < Admin.hunt.untilAt), 'Une chasse au trésor est déjà en cours.')
    local prize = math.tointeger(tonumber(data.prize)) or H.prize or 1500
    need(prize >= 100 and prize <= (H.maxPrize or 5000), ('Prime : 100 à %d $.'):format(H.maxPrize or 5000))
    if prize > (H.prize or 1500) then need(Admin.level(src) >= (H.bigPrizeLevel or 4), ('Prime au-delà de %d $ : super-admin.'):format(H.prize or 1500)) end
    local c = GetEntityCoords(GetPlayerPed(src))
    local at = vec3(c.x, c.y, c.z)
    -- zone affichée : centrée à côté de la mallette (jamais dessus), rayon `ev.radius`
    local a, r = math.random() * 2 * math.pi, ev.radius * (0.25 + math.random() * 0.4)
    local zone = vec3(at.x + math.cos(a) * r, at.y + math.sin(a) * r, at.z)
    Admin.hunt = { at = at, prize = prize, by = label(src), untilAt = os.time() + ev.minutes * 60 }
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
