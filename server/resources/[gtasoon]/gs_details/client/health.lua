-- gs_details (client) : antidouleurs (item painkillers, pharmacies) : +30 PV en quelques secondes, pas au-delà du maximum.
-- V12.37 · Dégâts adoucis (demande du fondateur : « pas trop réaliste ») : chaque joueur inflige moins de dégâts (armes à feu,
-- corps à corps, véhicules), donc tout le monde en encaisse moins. 1.0 = valeurs du jeu. Réappliqué toutes les 5 s (le jeu
-- remet 1.0 à chaque réapparition / changement de personnage), jamais par image.
local DAMAGE = { weapon = 0.75, melee = 0.8, vehicle = 0.7 }
CreateThread(function()
    while true do
        local id = PlayerId()
        SetPlayerWeaponDamageModifier(id, DAMAGE.weapon)
        SetPlayerMeleeWeaponDamageModifier(id, DAMAGE.melee)
        SetPlayerVehicleDamageModifier(id, DAMAGE.vehicle)
        Wait(5000)
    end
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
