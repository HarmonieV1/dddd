-- gs_city (client) · V11.2 « Black-out de quartier » : dans un quartier en panne, l'éclairage de la ville est coupé pour toi
-- (les phares restent allumés). Hors du quartier, on rend la main à la météo (orage avec coupure, gs_weather).
-- Transformateurs : [E] → Saboter (crochet) ou Réparer (payé par la mairie).
local B = Config.Blackout
local applied = false

local function districtAt(c)
    local p, best, bestD = vec2(c.x, c.y), nil, nil
    for _, d in ipairs(Config.Districts) do
        local dist = #(p - d.center)
        if dist <= d.radius and (not bestD or dist < bestD) then best, bestD = d, dist end
    end
    return best
end

CreateThread(function()
    while true do
        local d = districtAt(GetEntityCoords(cache.ped))
        local on = d and ((GlobalState.gsBlackout or {})[d.id] or 0) > GetCloudTimeAsInt()
        if on then
            SetArtificialLightsState(true) -- réappliqué à chaque passage : la météo ne rallume pas le quartier
            SetArtificialLightsStateAffectsVehicles(false)
            applied = true
        elseif applied then
            SetArtificialLightsState((GlobalState.gsWeather or {}).blackout == true)
            applied = false
        end
        Wait(2000)
    end
end)

AddEventHandler('gs_city:client:transformer', function(id)
    local t = (GlobalState.gsBlackout or {})[id]
    local dark = t and t > GetCloudTimeAsInt()
    if not lib.progressBar({ duration = dark and B.repair or B.sabotage, label = dark and 'Remise en service du transformateur…' or 'Sabotage du transformateur…',
        canCancel = true, anim = { scenario = 'WORLD_HUMAN_WELDING' }, disable = { move = true, car = true, combat = true } }) then return ClearPedTasks(cache.ped) end
    ClearPedTasks(cache.ped)
    local ok, msg
    if dark then ok, msg = lib.callback.await('gs_city:blackoutRepair', false, id)
    else ok, msg = lib.callback.await('gs_city:blackoutSabotage', false, id) end
    lib.notify({ description = msg, type = ok and 'success' or 'error' })
end)

CreateThread(function()
    for id, tr in pairs(B.transformers) do
        exports.gs_markers:Add('gs_city:transformer:' .. id, { coords = tr.coords, style = 'hidden', label = tr.label,
            event = 'gs_city:client:transformer', args = { id }, prompt = 'Transformateur : saboter / réparer', reach = B.range, snap = true })
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if applied then SetArtificialLightsState(false) end
    for id in pairs(B.transformers) do exports.gs_markers:Remove('gs_city:transformer:' .. id) end
end)
