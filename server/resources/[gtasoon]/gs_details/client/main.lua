-- gs_details (client) : /me /do (texte 3D), mains en l'air (X). Dessin seulement quand un texte est affiché.
local bubbles = {} -- [serverId] = { text, color, untilAt }

RegisterNetEvent('gs_details:client:me', function(src, kind, text)
    bubbles[src] = { text = (kind == 'do' and '* ' or '') .. text, color = kind == 'do' and { 255, 196, 0 } or { 200, 160, 255 },
        untilAt = GetGameTimer() + Config.Me.seconds * 1000 }
    if bubbles._running then return end
    bubbles._running = true
    CreateThread(function()
        while true do
            local any = false
            for id, b in pairs(bubbles) do
                if id ~= '_running' then
                    if GetGameTimer() > b.untilAt then bubbles[id] = nil
                    else
                        any = true
                        local pid = GetPlayerFromServerId(id)
                        if pid ~= -1 then
                            local c = GetPedBoneCoords(GetPlayerPed(pid), 31086, 0.0, 0.0, 0.0) -- tête
                            local onScreen, x, y = GetScreenCoordFromWorldCoord(c.x, c.y, c.z + 0.45)
                            if onScreen then
                                SetTextFont(4) SetTextScale(0.0, 0.38) SetTextCentre(true) SetTextOutline()
                                SetTextColour(b.color[1], b.color[2], b.color[3], 240)
                                BeginTextCommandDisplayText('STRING')
                                AddTextComponentSubstringPlayerName(b.text)
                                EndTextCommandDisplayText(x, y)
                            end
                        end
                    end
                end
            end
            if not any then break end
            Wait(0)
        end
        bubbles._running = nil
    end)
end)

RegisterCommand('me', function(_, args)
    local text = table.concat(args, ' ')
    if text ~= '' then TriggerServerEvent('gs_details:server:me', 'me', text) end
end, false)
RegisterCommand('do', function(_, args)
    local text = table.concat(args, ' ')
    if text ~= '' then TriggerServerEvent('gs_details:server:me', 'do', text) end
end, false)
TriggerEvent('chat:addSuggestion', '/me', 'Action de ton personnage (visible autour de toi)', { { name = 'action' } })
TriggerEvent('chat:addSuggestion', '/do', 'Décrire la scène (visible autour de toi)', { { name = 'description' } })

-- Mains en l'air ---------------------------------------------------------------------------------------------------
local handsUp = false

local function setHandsUp(on)
    local ped = PlayerPedId()
    if on and (IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or LocalPlayer.state.gsCuffed) then return end
    handsUp = on
    LocalPlayer.state:set('gsHandsUp', on or nil, true)
    if not on then ClearPedSecondaryTask(ped) return end
    lib.requestAnimDict('missminuteman_1ig_2', 2000)
    TaskPlayAnim(ped, 'missminuteman_1ig_2', 'handsup_base', 8.0, -8.0, -1, 49, 0, false, false, false)
    CreateThread(function()
        while handsUp do
            DisableControlAction(0, 24, true) DisableControlAction(0, 25, true) DisableControlAction(0, 140, true)
            if not IsEntityPlayingAnim(PlayerPedId(), 'missminuteman_1ig_2', 'handsup_base', 3) then setHandsUp(false) break end
            Wait(0)
        end
    end)
end

RegisterCommand('mainsenlair', function() setHandsUp(not handsUp) end, false)
RegisterKeyMapping('mainsenlair', 'Mains en l\'air', 'keyboard', Config.HandsUpKey)

-- Menus cliquables (ox_lib context) : METTRE-A-JOUR règle ox_lib pour garder les déplacements menu ouvert
-- (ZQSD, sprint). Ici on bloque seulement la caméra et le tir tant qu'un menu est ouvert (la souris sert au menu).
local LOOK_AND_FIRE = { 1, 2, 24, 25, 68, 69, 70, 91, 92, 106, 114, 140, 141, 142, 143, 257, 263, 264 }
CreateThread(function()
    while true do
        if lib.getOpenContextMenu() then -- [API] ox_lib
            for _, c in ipairs(LOOK_AND_FIRE) do DisableControlAction(0, c, true) end
            Wait(0)
        else
            Wait(250)
        end
    end
end)
