-- gs_onboarding (client) · V12.50 « Spawn patate » : protection d'arrivée et zones calmes aux points d'apparition
-- (réglages : Config.SpawnProtection). Fantôme = les autres joueurs passent à travers et ne peuvent ni frapper ni blesser ;
-- en échange, le protégé ne peut pas attaquer non plus (pas de troll protégé). Les menus de triche ne sont pas couverts
-- ici : c'est le rôle de gs_anticheat.
local P = Config.SpawnProtection
if not P or not P.enabled then return end

local ATTACK = { 24, 25, 140, 141, 142, 143, 257, 263, 264 } -- tir, viser, coups de poing / de pied
local untilT, ghost = 0, false

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
        if ghost or inCalmZone(GetEntityCoords(cache.ped)) then
            DisablePlayerFiring(cache.playerId, true)
            for i = 1, #ATTACK do DisableControlAction(0, ATTACK[i], true) end
            if ghost then SetEntityInvincible(cache.ped, true) end -- un changement de modèle (apparence) recrée le personnage
            Wait(0)
        else
            Wait(400)
        end
    end
end)
