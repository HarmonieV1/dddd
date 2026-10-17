-- gs_vie (serveur) · V12.64 · Salle de sport : un exercice = begin (au bon endroit) → animation → finish (durée réelle
-- vérifiée, toujours sur place) ; `session` exercices différents en `window` s = bonus d'endurance de `hours` h, gardé en KVP
-- (reconnexion, redémarrage).
local Security, Bridge = exports.gs_security, exports.gs_bridge
local G = Config.Gym
Gym = { pending = {}, sessions = {} } -- pending[src] = { kind, place, readyAt } ; sessions[cid] = { done = { kind = true }, startedAt }

local function now() return os.time() end
local EX = {}
for _, e in ipairs(G.exercises) do EX[e.id] = e end

--- Lieu de sport où se trouve le joueur (index) ou nil
function Gym.placeOf(src)
    for i, p in ipairs(G.places) do if Security:InRange(src, p.coords, p.radius) then return i end end
end

function Gym.bonusLeft(cid)
    local untilAt = cid and GetResourceKvpInt('gym:' .. cid) or 0
    return math.max(0, untilAt - now())
end

local function session(cid)
    local s = Gym.sessions[cid]
    if not s or now() - s.startedAt > G.window then s = { done = {}, startedAt = now() } Gym.sessions[cid] = s end
    return s
end

lib.callback.register('gs_vie:gymStatus', function(src)
    if not Security:RateLimit(src, 'gs_vie:gymStatus', 6, 10000) then return nil end
    local cid = Bridge:GetIdentifier(src)
    if not cid then return nil end
    local s = session(cid)
    local n = 0
    for _ in pairs(s.done) do n = n + 1 end
    return { done = s.done, count = n, need = G.session, bonus = Gym.bonusLeft(cid), left = math.max(0, G.window - (now() - s.startedAt)) }
end)

lib.callback.register('gs_vie:gymBegin', function(src, kind)
    if not Security:RateLimit(src, 'gs_vie:gymBegin', 4, 10000) then return false, 'Doucement.' end
    if not EX[kind] then return false, 'Exercice inconnu.' end
    local place = Gym.placeOf(src)
    if not place then return false, 'Il faut être à une salle de sport.' end
    if GetVehiclePedIsIn(GetPlayerPed(src), false) ~= 0 then return false, 'Descends du véhicule.' end
    local p0 = Gym.pending[src] -- V12.64 (relecture) : un exercice resté en plan (client planté) expire tout seul
    if p0 and GetGameTimer() - (p0.at or 0) < G.duration + 15000 then return false, 'Un exercice à la fois.' end
    Gym.pending[src] = { kind = kind, place = place, readyAt = GetGameTimer() + G.duration - 750, at = GetGameTimer() }
    return true, G.duration
end)

lib.callback.register('gs_vie:gymFinish', function(src)
    if not Security:RateLimit(src, 'gs_vie:gymFinish', 4, 10000) then return false, 'Doucement.' end
    local p = Gym.pending[src]
    Gym.pending[src] = nil
    if not p or GetGameTimer() < p.readyAt then return false, 'Exercice interrompu.' end
    if Gym.placeOf(src) ~= p.place then return false, 'Tu as quitté la salle.' end
    local cid = Bridge:GetIdentifier(src)
    if not cid then return false end
    local s = session(cid)
    if s.done[p.kind] then return true, ('%s : déjà fait dans cette séance, change d\'exercice.'):format(EX[p.kind].label) end
    s.done[p.kind] = true
    local n = 0
    for _ in pairs(s.done) do n = n + 1 end
    if n < G.session then return true, ('%s : bien joué ! Séance %d/%d.'):format(EX[p.kind].label, n, G.session) end
    Gym.sessions[cid] = nil
    local untilAt = now() + G.hours * 3600
    SetResourceKvpInt('gym:' .. cid, untilAt)
    TriggerClientEvent('gs_vie:client:gymBonus', src, untilAt - now())
    if GetResourceState('gs_quests') == 'started' then pcall(function() exports.gs_quests:Track(src, 'gym') end) end
    return true, ('Séance terminée ! Bonus d\'endurance pendant %d h : plus de souffle au sprint et en apnée.'):format(G.hours)
end)

RegisterNetEvent('gs_vie:server:gymCancel', function()
    if Security:RateLimit(source, 'gs_vie:gymCancel', 5, 10000) then Gym.pending[source] = nil end
end)

AddEventHandler('gs_bridge:server:playerLoaded', function(src)
    local left = Gym.bonusLeft(Bridge:GetIdentifier(src))
    if left > 0 then TriggerClientEvent('gs_vie:client:gymBonus', src, left) end
end)
AddEventHandler('playerDropped', function() Gym.pending[source] = nil end)
