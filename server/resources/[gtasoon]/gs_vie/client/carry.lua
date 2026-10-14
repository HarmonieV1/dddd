-- gs_vie (client) · V12.57 Porter / prendre en otage (Alt sur un joueur). L'autre accepte, sauf s'il est menotté,
-- à terre ou mort. X ou /lacher pour lâcher (la personne portée aussi, si elle avait accepté). Une seule boucle,
-- uniquement pendant l'action. Le porteur qui tombe (mort, à terre) lâche automatiquement.
local C = Config.Carry
local active -- { role, kind, other, forced }

local function notify(msg, t) lib.notify({ description = msg, type = t or 'inform' }) end

local function play(a)
    if not IsEntityPlayingAnim(cache.ped, a.dict, a.clip, 3) then
        if not pcall(lib.requestAnimDict, a.dict, 3000) then return end
        TaskPlayAnim(cache.ped, a.dict, a.clip, 8.0, -8.0, -1, a.flag, 0.0, false, false, false)
        RemoveAnimDict(a.dict)
    end
end

local function finish(why)
    if not active then return end
    local a = active
    active = nil
    lib.hideTextUI()
    if a.role == 'carried' then DetachEntity(cache.ped, true, false) end
    ClearPedTasks(cache.ped)
    if a.kind == 'hostage' and a.role == 'carried' then SetPedToRagdoll(cache.ped, 800, 800, 0, false, false, false) end
    if why then notify(why == 'parti' and 'L\'autre personne est partie.' or 'C\'est fini.') end
end

local function release()
    if not active then return end
    if active.role == 'carried' and active.forced then return notify('Tu te débats… en vain.', 'error') end
    TriggerServerEvent('gs_vie:carryRelease')
end

RegisterNetEvent('gs_vie:client:carryStart', function(role, kind, other, forced)
    if active or type(other) ~= 'number' then return end
    active = { role = role, kind = kind, other = other, forced = forced }
    local anim = C.anims[kind]
    local mine = anim[role]
    local canLeave = role == 'carrier' or not forced
    if canLeave then lib.showTextUI('[X] Lâcher') end
    CreateThread(function()
        local otherPed, tries = 0, 0
        while active do
            if otherPed == 0 or not DoesEntityExist(otherPed) then
                local pl = GetPlayerFromServerId(other)
                otherPed = pl ~= -1 and GetPlayerPed(pl) or 0
                tries = tries + 1
                if otherPed == 0 and tries > 50 then TriggerServerEvent('gs_vie:carryRelease') break end
            end
            if otherPed ~= 0 then
                play(mine)
                if role == 'carried' and not IsEntityAttachedToEntity(cache.ped, otherPed) then
                    local o = anim.attach
                    AttachEntityToEntity(cache.ped, otherPed, 0, o.x, o.y, o.z, o.rx, o.ry, o.rz, false, false, false, false, 2, false)
                end
            end
            if role == 'carrier' then
                DisableControlAction(0, 21, true) -- courir
                DisableControlAction(0, 22, true) -- sauter
                DisableControlAction(0, 23, true) -- monter dans un véhicule
                if kind == 'carry' then DisableControlAction(0, 24, true) DisableControlAction(0, 25, true) end
                if IsPedRagdoll(cache.ped) or IsEntityDead(cache.ped) or (LocalPlayer.state['qbx_medical:deathState'] or 1) >= 2 then -- [API] qbx_medical
                    TriggerServerEvent('gs_vie:carryBroken')
                    finish()
                    break
                end
            else
                DisableAllControlActions(0)
                for _, c in ipairs({ 1, 2, 245, 249 }) do EnableControlAction(0, c, true) end -- caméra, chat, micro
            end
            if canLeave and (IsControlJustPressed(0, 73) or IsDisabledControlJustPressed(0, 73)) then release() end
            Wait(0)
        end
    end)
end)

RegisterNetEvent('gs_vie:client:carryStop', function(why) finish(why) end)

RegisterNetEvent('gs_vie:client:carryAsk', function(from, kind)
    local what = kind == 'hostage' and 'te prendre en otage (scène jouée, tu restes sous la menace)' or 'te porter sur son épaule'
    local r = lib.alertDialog({ header = 'Demande', content = ('Quelqu\'un à côté de toi veut %s. Tu acceptes ?'):format(what),
        centered = true, cancel = true, labels = { confirm = 'Accepter', cancel = 'Refuser' } })
    TriggerServerEvent('gs_vie:carryAnswer', from, r == 'confirm')
end)

local function ask(data, kind)
    local target = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
    local ok, msg = lib.callback.await('gs_vie:carryRequest', false, target, kind)
    if msg then notify(msg, ok and 'inform' or 'error') end
end

RegisterCommand('lacher', release, false)

CreateThread(function()
    exports.ox_target:addGlobalPlayer({ -- [API] ox_target
        { name = 'gs_vie_carry', icon = 'fa-solid fa-person-carry-box', label = 'Porter', distance = C.range,
          canInteract = function() return not active and not cache.vehicle end, onSelect = function(d) ask(d, 'carry') end },
        { name = 'gs_vie_hostage', icon = 'fa-solid fa-person-rifle', label = 'Prendre en otage', distance = C.range,
          canInteract = function()
              if active or cache.vehicle then return false end
              local w = GetSelectedPedWeapon(cache.ped)
              for _, n in ipairs(C.hostageWeapons) do if w == joaat(n) then return true end end
              return false
          end, onSelect = function(d) ask(d, 'hostage') end },
    })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and active then finish() end
end)
