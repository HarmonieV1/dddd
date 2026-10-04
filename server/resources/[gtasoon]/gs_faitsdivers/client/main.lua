-- gs_faitsdivers (client) : alerte + GPS pour les services en service, scène créée à l'approche (corps, voiture
-- accidentée), [E] constatations → le serveur vérifie et paie.
local cases, scene = {}, {} -- cases[id] = fait divers ; scene[id] = { entity, blip }

local function clear(id)
    local s = scene[id]
    if s then
        if s.entity and DoesEntityExist(s.entity) then DeleteEntity(s.entity) end
        if s.blip then RemoveBlip(s.blip) end
    end
    scene[id] = nil
    exports.gs_markers:Remove('gs_faitsdivers:' .. id)
end

local function blip(c)
    local b = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(b, 161) SetBlipColour(b, 3) SetBlipScale(b, 0.9) SetBlipAsShortRange(b, false)
    BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName('Fait divers : ' .. c.label) EndTextCommandSetBlipName(b)
    return b
end

local function add(c, alert)
    if cases[c.id] then return end
    cases[c.id] = c
    scene[c.id] = { blip = blip(c) }
    exports.gs_markers:Add('gs_faitsdivers:' .. c.id, { coords = vec3(c.x, c.y, c.z), style = 'job', label = c.label, event = 'gs_faitsdivers:client:handle',
        args = { c.id }, prompt = c.action, reach = Config.Range, distance = 40.0 })
    if alert then
        PlaySoundFrontend(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', false)
        lib.notify({ title = 'Central · ' .. c.label, description = c.zone .. ' · GPS sur la carte', type = 'warning', icon = c.icon, duration = 12000 })
    end
end

RegisterNetEvent('gs_faitsdivers:client:new', function(c) add(c, true) end)
RegisterNetEvent('gs_faitsdivers:client:closed', function(id) cases[id] = nil clear(id) end)

AddEventHandler('gs_faitsdivers:client:handle', function(id)
    local c = cases[id]
    if not c then return end
    if not lib.progressBar({ duration = Config.Duration, label = c.action .. '…', canCancel = true, anim = { scenario = 'CODE_HUMAN_POLICE_INVESTIGATE' },
        disable = { move = true, car = true, combat = true } }) then return ClearPedTasks(cache.ped) end
    ClearPedTasks(cache.ped)
    local ok, msg = lib.callback.await('gs_faitsdivers:handle', false, id)
    lib.notify({ description = msg, type = ok and 'success' or 'error', duration = 8000 })
end)

-- Scènes visibles à l'approche (objets locaux)
local function build(c)
    local s = scene[c.id]
    if not s or s.entity or not c.model then return end
    local hash = GetHashKey(c.model)
    if not IsModelInCdimage(hash) or not lib.requestModel(hash, 5000) then return end
    if c.kind == 'body' then
        local ped = CreatePed(4, hash, c.x, c.y, c.z - 1.0, math.random(0, 359) + 0.0, false, false)
        SetEntityHealth(ped, 0) SetPedToRagdoll(ped, 10000, 10000, 0, false, false, false)
        s.entity = ped
    elseif c.kind == 'hitrun' then
        local v = CreateVehicle(hash, c.x, c.y, c.z, math.random(0, 359) + 0.0, false, false)
        SetVehicleNumberPlateText(v, c.plate or '')
        SetVehicleEngineHealth(v, 150.0) SetVehicleBodyHealth(v, 200.0) SmashVehicleWindow(v, 0) SmashVehicleWindow(v, 1)
        SetVehicleDamage(v, 0.0, 1.2, 0.2, 800.0, 400.0, true) SetVehicleDoorsLocked(v, 2) FreezeEntityPosition(v, true)
        s.entity = v
    end
    SetModelAsNoLongerNeeded(hash)
end

CreateThread(function()
    while true do
        local me = GetEntityCoords(cache.ped)
        for id, c in pairs(cases) do
            local d = #(me - vec3(c.x, c.y, c.z))
            local s = scene[id]
            if d < 80.0 then build(c)
            elseif d > 120.0 and s and s.entity then if DoesEntityExist(s.entity) then DeleteEntity(s.entity) end s.entity = nil end
        end
        Wait(3000)
    end
end)

-- Prise de service en cours de route : récupérer les affaires ouvertes
CreateThread(function()
    while true do
        Wait(60000)
        local j = exports.gs_bridge:GetJob()
        if j and j.onduty then
            for _, c in ipairs(lib.callback.await('gs_faitsdivers:list', false) or {}) do add(c, false) end
        elseif next(cases) then
            for id in pairs(cases) do clear(id) end
            cases = {}
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then for id in pairs(scene) do clear(id) end end
end)
