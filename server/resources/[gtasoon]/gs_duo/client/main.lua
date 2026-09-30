-- gs_duo (client) : menu /duo, blip du partenaire, étapes de contrat.
local info
local partnerBlip
local step -- { point, blip }

RegisterNetEvent('gs_duo:client:info', function(data) info = data end)

-- Blip du partenaire (position envoyée par le serveur toutes les 3 s, même hors de portée réseau)
RegisterNetEvent('gs_duo:client:partner', function(coords)
    if not coords then
        if partnerBlip then RemoveBlip(partnerBlip) partnerBlip = nil end
        return
    end
    if not partnerBlip then
        partnerBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(partnerBlip, 280)
        SetBlipColour(partnerBlip, 48)
        SetBlipScale(partnerBlip, 0.9)
        SetBlipCategory(partnerBlip, 7)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Partenaire')
        EndTextCommandSetBlipName(partnerBlip)
    else
        SetBlipCoords(partnerBlip, coords.x, coords.y, coords.z)
    end
end)

RegisterNetEvent('gs_duo:client:invite', function(fromName)
    local answer = lib.alertDialog({
        header = 'Proposition de duo',
        content = ('**%s** veut faire équipe avec toi. Un duo est durable : contrats à deux, chaleur partagée, position visible.'):format(fromName),
        centered = true, cancel = true, labels = { confirm = 'Faire équipe', cancel = 'Refuser' },
    })
    TriggerServerEvent('gs_duo:server:answer', answer == 'confirm')
end)

-- Étapes de contrat ----------------------------------------------------------------------------------
local function clearStep()
    if not step then return end
    step.point:remove()
    RemoveBlip(step.blip)
    lib.hideTextUI()
    step = nil
end

RegisterNetEvent('gs_duo:client:contractStep', function(s)
    clearStep()
    local c = s.coords
    local blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, 478)
    SetBlipColour(blip, 48)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, 48)
    local shown, busy = false, false
    local text = ('[E] %s (%d/%d)'):format(s.label, s.index, s.total)
    local point = lib.points.new({ coords = c, distance = 60.0 })
    function point:nearby()
        DrawMarker(1, c.x, c.y, c.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 5.0, 5.0, 0.6, 90, 200, 255, 70, false, false, 2, false, nil, nil, false)
        local inside = self.currentDistance <= 5.0
        if inside ~= shown and not busy then
            shown = inside
            if inside then lib.showTextUI(text) else lib.hideTextUI() end
        end
        if inside and not busy and IsControlJustReleased(0, 38) then
            busy, shown = true, false
            lib.hideTextUI()
            CreateThread(function()
                if lib.progressBar({ duration = s.duration, label = s.label, canCancel = true, disable = { move = true, car = true, combat = true } }) then
                    local ok, msg = lib.callback.await('gs_duo:contractStep', false)
                    if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end
                end
                busy = false
            end)
        end
    end
    function point:onExit() if shown then lib.hideTextUI() shown = false end end
    step = { point = point, blip = blip }
end)

RegisterNetEvent('gs_duo:client:contractEnd', function(reason)
    if not step then return end
    clearStep()
    if reason == 'cancel' then lib.notify({ description = 'Contrat annulé.', type = 'error' }) end
end)

-- Menu /duo --------------------------------------------------------------------------------------------
local function invite()
    local target = lib.getClosestPlayer(GetEntityCoords(cache.ped), Config.InviteRange, false)
    if not target then return lib.notify({ description = 'Personne à proximité.', type = 'error' }) end
    local ok, msg = lib.callback.await('gs_duo:invite', false, GetPlayerServerId(target))
    lib.notify({ description = msg, type = ok and 'success' or 'error' })
end

local function openMenu()
    info = lib.callback.await('gs_duo:info', false)
    local options = {}
    if not info then
        options[1] = { title = 'Proposer un duo au joueur le plus proche', icon = 'handshake', onSelect = invite }
    else
        local progress = info.nextXp and math.floor(info.xp / info.nextXp * 100) or 100
        options[#options + 1] = {
            title = ('%s · %s (niv. %d)'):format(info.name, info.levelLabel, info.level),
            description = info.nextXp and ('%d / %d XP'):format(info.xp, info.nextXp) or 'Niveau max',
            icon = 'link', progress = progress, colorScheme = 'pink', readOnly = true,
        }
        options[#options + 1] = {
            title = info.partnerOnline and ('Partenaire : %s'):format(info.partnerName) or 'Partenaire hors ligne',
            icon = info.partnerOnline and 'user-check' or 'user-clock', readOnly = true,
        }
        if info.contract then
            options[#options + 1] = { title = 'Abandonner le contrat', icon = 'xmark',
                onSelect = function() TriggerServerEvent('gs_duo:server:contractCancel') end }
        else
            options[#options + 1] = { title = 'Prendre un contrat à deux', icon = 'box', disabled = not info.partnerOnline,
                onSelect = function()
                    local ok, msg = lib.callback.await('gs_duo:contractStart', false)
                    lib.notify({ description = msg, type = ok and 'success' or 'error' })
                end }
        end
        options[#options + 1] = { title = 'Renommer le duo', icon = 'pen',
            onSelect = function()
                local input = lib.inputDialog('Nom du duo', { { type = 'input', label = 'Nom', max = Config.NameMaxLength, required = true } })
                if input then
                    local ok, msg = lib.callback.await('gs_duo:rename', false, input[1])
                    lib.notify({ description = msg, type = ok and 'success' or 'error' })
                end
            end }
        options[#options + 1] = { title = 'Rompre le duo', icon = 'heart-crack', iconColor = '#ff2e88',
            onSelect = function()
                if lib.alertDialog({ header = 'Rompre le duo', content = 'Le niveau de lien sera perdu. Sûr ?', centered = true, cancel = true }) == 'confirm' then
                    TriggerServerEvent('gs_duo:server:leave')
                end
            end }
    end
    lib.registerContext({ id = 'gs_duo', title = 'Duo', options = options })
    lib.showContext('gs_duo')
end

RegisterCommand('duo', openMenu, false)
RegisterKeyMapping('duo', 'Menu duo', 'keyboard', 'F7')
