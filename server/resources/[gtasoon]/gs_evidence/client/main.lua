-- gs_evidence (client) : signale ses tirs et ses blessures (le serveur vérifie), lampe torche de la police (traces
-- visibles, [E] scellé), labo du commissariat, gants et javel (objets).
local Bridge = exports.gs_bridge
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end

-- Tirs → douilles (une fois par rafale, le serveur limite aussi). V10.2 : seul détecteur de tirs du serveur (gs_wanted
-- reçoit l'info côté serveur, plus de 2e boucle) ; la boucle par image ne tourne que pendant qu'une arme à feu est en main.
local shotToken = 0
local function watchShots(weapon)
    shotToken = shotToken + 1
    local token, last = shotToken, 0
    CreateThread(function()
        while cache.weapon == weapon and token == shotToken do
            if IsPedShooting(cache.ped) and GetGameTimer() - last > 1500 then
                last = GetGameTimer()
                TriggerServerEvent('gs_evidence:server:shot', IsPedCurrentWeaponSilenced(cache.ped))
            end
            Wait(0)
        end
    end)
end
local function onWeapon(weapon) if weapon and GetWeaponDamageType(weapon) == 3 then watchShots(weapon) end end -- 3 = balles
lib.onCache('weapon', onWeapon)
CreateThread(function() onWeapon(cache.weapon) end)

-- Blessure → sang au sol
local lastHurt = 0
AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' or args[1] ~= cache.ped then return end
    if GetGameTimer() - lastHurt < 15000 then return end
    lastHurt = GetGameTimer()
    SetTimeout(500, function() TriggerServerEvent('gs_evidence:server:hurt') end)
end)

-- Lampe torche (policier en service) ---------------------------------------------------------------------------
local FLASHLIGHT = GetHashKey('WEAPON_FLASHLIGHT')
local COLORS = { casing = { 255, 196, 0 }, blood = { 200, 20, 30 }, print = { 79, 216, 255 }, tyre = { 200, 200, 200 }, paint = { 162, 75, 255 } }

local function onDutyPolice()
    local j = Bridge:GetJob()
    return j and j.onduty and (j.name == Config.PoliceJob or j.name == 'sheriff')
end

local function text3d(x, y, z, s)
    SetDrawOrigin(x, y, z, 0)
    SetTextFont(4) SetTextScale(0.0, 0.32) SetTextColour(255, 255, 255, 230) SetTextOutline() SetTextCentre(true)
    BeginTextCommandDisplayText('STRING') AddTextComponentSubstringPlayerName(s) EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

CreateThread(function()
    local traces, nextFetch, ui = {}, 0, false
    while true do
        local ped = cache.ped
        if GetSelectedPedWeapon(ped) == FLASHLIGHT and IsPlayerFreeAiming(PlayerId()) and onDutyPolice() then
            if GetGameTimer() > nextFetch then
                nextFetch = GetGameTimer() + 1500
                traces = lib.callback.await('gs_evidence:nearby', false) or {}
            end
            local me, best, bestD = GetEntityCoords(ped), nil, Config.Search.collect
            for _, t in ipairs(traces) do
                local c = COLORS[t.kind] or { 255, 255, 255 }
                DrawMarker(28, t.x, t.y, t.z - 0.95, 0, 0, 0, 0, 0, 0, 0.12, 0.12, 0.12, c[1], c[2], c[3], 200, false, false, 2, false, nil, nil, false)
                local d = #(me - vec3(t.x, t.y, t.z))
                if d < 6.0 then text3d(t.x, t.y, t.z - 0.7, Config.Kinds[t.kind].label .. (t.n > 1 and (' ×' .. t.n) or '')) end
                if d < bestD then best, bestD = t, d end
            end
            if best and not ui then lib.showTextUI('[E] Mettre sous scellé', { icon = 'box-archive' }) ui = true
            elseif not best and ui then lib.hideTextUI() ui = false end
            if best and IsControlJustReleased(0, 38) and not IsNuiFocused() then
                if lib.progressBar({ duration = 3000, label = 'Prélèvement…', canCancel = true,
                    anim = { dict = 'amb@medic@standing@kneel@base', clip = 'base' }, disable = { move = true, car = true, combat = true } }) then
                    notify(lib.callback.await('gs_evidence:collect', false, best.id))
                    nextFetch = 0
                end
                ClearPedTasks(ped)
            end
            Wait(0)
        else
            if ui then lib.hideTextUI() ui = false end
            traces = {}
            Wait(400)
        end
    end
end)

-- Labo du commissariat -----------------------------------------------------------------------------------------
local function labMenu()
    local ok, d = lib.callback.await('gs_evidence:lab', false, 'list')
    if not ok then return notify(false, d) end
    local options = { { title = 'Mes scellés à analyser', icon = 'box-archive', readOnly = true } }
    for _, s in ipairs(d.mine) do
        options[#options + 1] = { title = ('n°%d · %s'):format(s.id, s.label), description = 'Prélevé le ' .. s.date, icon = 'flask', arrow = true,
            onSelect = function() notify(lib.callback.await('gs_evidence:lab', false, 'analyze', s.id)) end }
    end
    if #d.mine == 0 then options[#options + 1] = { title = 'Aucun scellé sur toi', icon = 'circle-info', readOnly = true } end
    options[#options + 1] = { title = 'Résultats du labo', icon = 'microscope', readOnly = true }
    for _, s in ipairs(d.results) do
        options[#options + 1] = { title = ('n°%d · %s'):format(s.id, s.label), icon = s.status == 'done' and 'file-circle-check' or 'hourglass-half',
            description = s.status == 'done' and s.result or ('Analyse en cours : encore %d s'):format(s.left or 0), readOnly = true }
    end
    lib.registerContext({ id = 'gs_evidence_lab', title = 'Labo · Police scientifique', options = options })
    lib.showContext('gs_evidence_lab')
end
AddEventHandler('gs_evidence:client:lab', labMenu)

CreateThread(function()
    exports.gs_markers:Add('gs_evidence:lab', { coords = Config.Lab.coords, style = 'job', label = 'Labo',
        event = 'gs_evidence:client:lab', prompt = 'Labo de la police scientifique', reach = Config.Lab.radius })
end)

-- Objets : gants, javel ---------------------------------------------------------------------------------------
exports('gloves', function()
    notify(lib.callback.await('gs_evidence:gloves', false))
end)

exports('bleach', function()
    if cache.vehicle then return notify(false, 'Descends du véhicule.') end
    if not lib.progressBar({ duration = Config.Clean.duration, label = 'Nettoyage de la scène…', canCancel = true,
        anim = { scenario = 'WORLD_HUMAN_MAID_CLEAN' }, disable = { move = true, car = true, combat = true } }) then return ClearPedTasks(cache.ped) end
    ClearPedTasks(cache.ped)
    notify(lib.callback.await('gs_evidence:clean', false))
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    exports.gs_markers:RemovePrefix('gs_evidence:')
    lib.hideTextUI()
end)
