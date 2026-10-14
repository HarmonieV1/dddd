-- gs_onboarding (client) · V12.50 protection d'arrivée et zones calmes aux points d'apparition ; V12.51 anti « spawn patate »
-- (spam de clics = coups de poing enchaînés) : un coup au corps à corps toutes les 0,8 s au plus (réglages : Config.SpawnProtection). Fantôme = les autres joueurs passent à travers et ne peuvent ni frapper ni blesser ;
-- en échange, le protégé ne peut pas attaquer non plus (pas de troll protégé). Les menus de triche ne sont pas couverts
-- ici : c'est le rôle de gs_anticheat.
local P = Config.SpawnProtection
if not P or not P.enabled then return end

local ATTACK = { 24, 25, 140, 141, 142, 143, 257, 263, 264 } -- tir, viser, coups de poing / de pied
local untilT, ghost = 0, false
local HIT = { 24, 140, 141, 142, 257, 263, 264 } -- touches qui lancent un coup au corps à corps
local GROUP_UNARMED, GROUP_MELEE = 2685387236, 3566412244
local hitBlockUntil, nextScan, calm, fight = 0, 0, false, false

--- Faut-il surveiller le spam de coups ? À pied, mains nues ou arme blanche, un autre joueur à portée.
local function canFight(pos)
    if cache.vehicle then return false end
    local group = GetWeapontypeGroup(GetSelectedPedWeapon(cache.ped))
    if group ~= GROUP_UNARMED and group ~= GROUP_MELEE then return false end
    return lib.getClosestPlayer(pos, P.meleeWatchRange, false) ~= nil
end

--- Anti-spam : le clic qui lance un coup passe, les suivants sont bloqués pendant meleeCooldown ms.
local function antiSpam(now)
    if now < hitBlockUntil then
        for i = 1, #HIT do DisableControlAction(0, HIT[i], true) end
        return
    end
    for i = 1, #HIT do
        if IsControlJustPressed(0, HIT[i]) then hitBlockUntil = now + P.meleeCooldown return end
    end
end

local function setGhost(on)
    ghost = on
    SetLocalPlayerAsGhost(on)
    if on then
        SetGhostedEntityAlpha(170)
        SetEntityInvincible(cache.ped, true)
    elseif not GetPlayerInvincible(cache.playerId) then -- invincibilité du staff (F11) : on n'y touche pas
        SetEntityInvincible(cache.ped, false)
    end
end

local function protect(seconds)
    untilT = GetGameTimer() + seconds * 1000
    setGhost(true)
    lib.notify({ description = ('Protection d\'arrivée : %d s, personne ne peut te toucher (et tu ne peux pas attaquer).'):format(seconds), type = 'inform', duration = 6000 })
end

local function inCalmZone(pos)
    for _, z in ipairs(P.zones) do
        if #(pos - z) < P.radius then return true end
    end
    return false
end

AddEventHandler('QBCore:Client:OnPlayerLoaded', function() -- [API] qbx_core
    local bus = Config.Arrival and Config.Arrival.enabled and P.busExtra or 0
    SetTimeout(1500, function() protect(P.seconds + bus) end)
end)

CreateThread(function()
    local wasDead = false
    while true do
        local now = GetGameTimer()
        local dead = LocalPlayer.state['qbx_medical:deathState'] == 3 or IsEntityDead(cache.ped) -- [API] qbx_medical : 3 = mort
        if wasDead and not dead then protect(P.seconds) end -- réapparition ou réanimation
        wasDead = dead
        if ghost and now >= untilT then
            setGhost(false)
            lib.notify({ description = 'Protection d\'arrivée terminée.', type = 'inform' })
        end
        if now >= nextScan then -- tests coûteux : 2 à 3 fois par seconde seulement
            nextScan = now + 400
            local pos = GetEntityCoords(cache.ped)
            calm, fight = inCalmZone(pos), canFight(pos)
        end
        if ghost or calm then
            DisablePlayerFiring(cache.playerId, true)
            for i = 1, #ATTACK do DisableControlAction(0, ATTACK[i], true) end
            if ghost then SetEntityInvincible(cache.ped, true) end -- un changement de modèle (apparence) recrée le personnage
            Wait(0)
        elseif fight then
            antiSpam(now)
            Wait(0)
        else
            Wait(250)
        end
    end
end)
