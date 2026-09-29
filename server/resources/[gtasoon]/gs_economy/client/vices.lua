-- gs_economy (client) : effets de l'alcool et du tabac, branchés sur ox_inventory (client.export des items).
-- ox_inventory consomme l'item via useItem (animation + durée définies dans l'item), on ajoute l'effet ensuite.
local drunk = 0          -- verres récents
local drunkUntil = 0

local function drunkLoop()
    CreateThread(function()
        local ped = PlayerPedId()
        lib.requestAnimSet('move_m@drunk@slightlydrunk', 2000)
        local effects = false
        while GetGameTimer() < drunkUntil do
            if drunk >= 2 then -- effets visibles à partir du 2e verre
                if not effects then
                    effects = true
                    SetPedMovementClipset(PlayerPedId(), 'move_m@drunk@slightlydrunk', 1.0)
                    SetTimecycleModifier('spectator5')
                end
                SetTimecycleModifierStrength(math.min(1.0, 0.15 * drunk))
                ShakeGameplayCam('DRUNK_SHAKE', math.min(1.5, 0.3 * drunk))
            end
            Wait(5000)
        end
        drunk = 0
        LocalPlayer.state:set('gsDrunk', nil, true) -- alcootest police : négatif
        ResetPedMovementClipset(PlayerPedId(), 1.0)
        ClearTimecycleModifier()
        StopGameplayCamShaking(true)
    end)
end

--- Boisson alcoolisée : chaque verre ajoute 2 min d'effet, plus fort à partir de 3 verres.
exports('drink', function(data)
    exports.ox_inventory:useItem(data, function(used) -- [API] ox_inventory
        if not used then return end
        local wasDrunk = GetGameTimer() < drunkUntil
        drunk = drunk + 1
        drunkUntil = math.max(drunkUntil, GetGameTimer()) + 120000
        LocalPlayer.state:set('gsDrunk', drunk, true) -- lu par l'alcootest (gs_police)
        if not wasDrunk then drunkLoop() end
        if drunk >= 5 then lib.notify({ description = 'Tu as un peu trop bu…', type = 'warning' }) end
    end)
end)

--- Paquet de cigarettes : une cigarette par utilisation (le paquet contient 10 usages via la durabilité).
exports('smoke', function(data)
    if exports.gs_bridge:GetItemCount('lighter') < 1 then
        return lib.notify({ description = 'Il te faut un briquet.', type = 'error' })
    end
    exports.ox_inventory:useItem(data, function(used) -- [API] ox_inventory
        if not used then return end
        local ped = PlayerPedId()
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_SMOKING', 0, true)
        lib.notify({ description = 'Une petite pause…', type = 'inform', icon = 'smoking' })
        SetTimeout(15000, function()
            if IsPedUsingScenario(ped, 'WORLD_HUMAN_SMOKING') then ClearPedTasks(ped) end
        end)
    end)
end)
