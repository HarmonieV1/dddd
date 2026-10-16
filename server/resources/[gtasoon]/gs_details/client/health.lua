-- gs_details (client) : antidouleurs (item painkillers, pharmacies) : +30 PV en quelques secondes, pas au-delà du maximum.
-- V12.37 · Dégâts adoucis (demande du fondateur : « pas trop réaliste ») : chaque joueur inflige moins de dégâts (armes à feu,
-- corps à corps, véhicules), donc tout le monde en encaisse moins. 1.0 = valeurs du jeu. Réappliqué toutes les 5 s (le jeu
-- remet 1.0 à chaque réapparition / changement de personnage), jamais par image.
-- V12.63 (backtest : « dégâts réalistes, toutes armes confondues ») : multiplicateur selon la FAMILLE de l'arme en main
-- (Config.Damage), relu toutes les 500 ms et réappliqué seulement quand l'arme change (ou toutes les 5 s : le jeu remet 1.0
-- à chaque réapparition). Taser : temps au sol minimum réglé ici aussi (Config.Taser.groundMs).
local D = Config.Damage
local function norm(h) h = tonumber(h) or 0 return h < 0 and h + 4294967296 or h end
local GROUP_MULT, BLADE, UNARMED_G, MELEE_G = {}, {}, norm(GetHashKey('GROUP_UNARMED')), norm(GetHashKey('GROUP_MELEE'))
for name, m in pairs(D.groups) do GROUP_MULT[norm(GetHashKey(name))] = m end
for _, w in ipairs(D.blades) do BLADE[norm(GetHashKey(w))] = true end
local function modifiers(weapon)
    local g = norm(GetWeapontypeGroup(weapon))
    local melee = (g == UNARMED_G and D.unarmed) or (g == MELEE_G and (BLADE[norm(weapon)] and D.blade or D.blunt)) or D.unarmed
    return GROUP_MULT[g] or D.weapon, melee
end
CreateThread(function()
    local last, refreshAt = nil, 0
    while true do
        local weapon = GetSelectedPedWeapon(cache.ped)
        if weapon ~= last or GetGameTimer() >= refreshAt then
            last, refreshAt = weapon, GetGameTimer() + 5000
            local id = PlayerId()
            local w, m = modifiers(weapon)
            SetPlayerWeaponDamageModifier(id, w)
            SetPlayerMeleeWeaponDamageModifier(id, m)
            SetPlayerVehicleDamageModifier(id, D.vehicle)
            SetPedMinGroundTimeForStungun(cache.ped, Config.Taser.groundMs)
        end
        Wait(500)
    end
end)

--- V12.63 · Touché par un taser : écran électrisé + tremblement, puis sonné (léger tremblement) ; jamais mortel.
local tasedUntil = 0
local function tased()
    local T = Config.Taser
    if GetGameTimer() < tasedUntil then return end
    tasedUntil = GetGameTimer() + T.fxMs
    AnimpostfxPlay('Dont_tazeme_bro', 0, true)
    ShakeGameplayCam('DRUNK_SHAKE', T.shake)
    PlaySoundFrontend(-1, 'Hit_1', 'LONG_PLAYER_SWITCH_SOUNDS', true)
    SetTimeout(T.fxMs, function()
        AnimpostfxStop('Dont_tazeme_bro')
        AnimpostfxPlay('DrugsDrivingOut', 0, false)
        ShakeGameplayCam('DRUNK_SHAKE', T.shake * 0.35)
        SetTimeout(T.dazedMs, function() StopGameplayCamShaking(false) AnimpostfxStop('DrugsDrivingOut') end)
    end)
end
-- V12.41 · Balle dans la tête = à terre en un tir (cohérence RP, demande du fondateur). Vu par la VICTIME (le seul jeu
-- qui sait vraiment quel os a été touché) : arme à balles uniquement (pas de poing, couteau, taser, balle en caoutchouc,
-- extincteur), tireur = un autre joueur ou un PNJ. Le reste (corps, jambes) ne change pas : dégâts adoucis ci-dessus.
-- V12.59 (backtest du 15/10) :
--  · tête = MORT tout de suite, immobile (état « mort » de qbx_medical, réanimable par l'EMS), sans passer par
--    le « dernier souffle » où l'on se tortille et rampe au sol : réservé aux blessures au corps ;
--  · casque : n'est plus une quasi-immunité. Il encaisse UNE balle dans la tête (puis 2 min de répit), la suivante tue.
local HEAD = 31086 -- SKEL_Head
local BULLET = 3   -- type de dégâts « balle »
local NOT_LETHAL = { [GetHashKey('WEAPON_STUNGUN')] = true, [GetHashKey('WEAPON_STUNGUN_MP')] = true }
local HELMET_COOLDOWN = 120000
local helmetSaved = 0
local function deathState() return LocalPlayer.state['qbx_medical:deathState'] or 1 end -- [API] qbx_medical : 1 vivant, 2 à terre, 3 mort
local function killNow(ped)
    SetEntityHealth(ped, 0)
    -- qbx_medical met d'abord « à terre » (2) : dès que c'est fait, 2e mise à zéro = mort (3), allongé sans bouger.
    -- (SetTimeout et pas CreateThread : gs_details est au plafond de threads client de check_perf.py)
    local deadline = GetGameTimer() + 4000
    local function step()
        local st = deathState()
        if st == 2 then return SetTimeout(150, function() if deathState() == 2 then SetEntityHealth(cache.ped, 0) end end) end
        if st < 2 and GetGameTimer() < deadline then SetTimeout(50, step) end
    end
    SetTimeout(50, step)
end
AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    local ped = cache.ped
    local victim, attacker, weapon = args[1], args[2], args[7]
    if victim == ped and weapon and NOT_LETHAL[weapon] then return tased() end -- V12.63 : taser
    if victim ~= ped or attacker == ped or not weapon or NOT_LETHAL[weapon] then return end
    if GetWeaponDamageType(weapon) ~= BULLET then return end
    if IsEntityDead(ped) or GetPlayerInvincible(PlayerId()) then return end -- staff invincible : jamais
    if deathState() >= 3 then return end
    local hit, bone = GetPedLastDamageBone(ped)
    if not hit or bone ~= HEAD then return end
    ClearPedLastDamageBone(ped)
    if GetPedPropIndex(ped, 0) >= 0 and IsPedWearingHelmet(ped) and GetGameTimer() > helmetSaved then
        helmetSaved = GetGameTimer() + HELMET_COOLDOWN -- le casque a encaissé : la prochaine balle dans la tête tue
        lib.notify({ description = 'Ton casque a arrêté la balle… pas sûr qu\'il tienne la prochaine.', type = 'warning' })
        return
    end
    killNow(ped)
end)

-- Les blessures par zone du corps, saignements et fractures sont gérés par qbx_medical.
exports('painkillers', function(data)
    if not lib.progressBar({ duration = 2500, label = 'Tu prends un antidouleur…', canCancel = true,
        anim = { dict = 'mp_suicide', clip = 'pill' }, disable = { car = false, combat = true } }) then return end
    exports.ox_inventory:useItem(data, function(used) -- [API] ox_inventory : consommé seulement si l'action va au bout
        if not used then return end
        CreateThread(function()
            for _ = 1, 6 do
                local ped = cache.ped
                local hp, max = GetEntityHealth(ped), GetEntityMaxHealth(ped)
                if hp <= 0 or hp >= max then break end
                SetEntityHealth(ped, math.min(max, hp + 5))
                Wait(1000)
            end
        end)
        lib.notify({ description = 'La douleur s\'estompe.', type = 'success' })
    end)
end)
