-- gs_smuggling (client) : contact au port de Paleto, caisses flottantes en mer, plage de livraison, garde-côtes IA.
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error', duration = 7000 }) end end
local run, crates, blip, contact = nil, {}, nil, nil

local function clearRun()
    for _, o in ipairs(crates) do if DoesEntityExist(o) then DeleteEntity(o) end end
    crates = {}
    if blip then RemoveBlip(blip) blip = nil end
    exports.gs_markers:RemovePrefix('gs_smuggling:run')
    run = nil
end

local function point(c, label)
    if blip then RemoveBlip(blip) end
    blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, 478) SetBlipColour(blip, 1) SetBlipRoute(blip, true)
    BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(label) EndTextCommandSetBlipName(blip)
end

local function spawnCrates(c)
    local h = GetHashKey(Config.Crate)
    if not lib.requestModel(h, 5000) then return end
    for i = 1, 3 do
        local o = CreateObject(h, c.x + i * 1.6, c.y, 0.2, false, false, false)
        FreezeEntityPosition(o, true)
        crates[#crates + 1] = o
    end
    SetModelAsNoLongerNeeded(h)
end

AddEventHandler('gs_smuggling:client:contact', function()
    if run then
        if lib.alertDialog({ header = 'Abandonner la cargaison ?', content = 'Le contact ne sera pas content.', centered = true, cancel = true }) == 'confirm' then
            lib.callback.await('gs_smuggling:action', false, 'cancel') clearRun()
        end
        return
    end
    local ok, d = lib.callback.await('gs_smuggling:action', false, 'take')
    if not ok then return notify(false, d) end
    run = { pickup = Config.Pickups[d.pickup], drop = Config.Drops[d.drop] }
    notify(true, '« Trois caisses flottent au large. Prends un bateau, charge-les, et dépose-les sur la plage. Pas de bruit. »')
    point(run.pickup, 'Cargaison en mer')
    spawnCrates(run.pickup)
    exports.gs_markers:Add('gs_smuggling:runload', { coords = run.pickup + vec3(3.0, 0.0, 1.0), style = 'hidden', event = 'gs_smuggling:client:load', prompt = 'Charger les caisses', reach = 25.0 })
end)

AddEventHandler('gs_smuggling:client:load', function()
    if not run then return end
    if not lib.progressBar({ duration = 10000, label = 'Chargement des caisses…', canCancel = true, disable = { move = true, combat = true } }) then return end
    local ok, msg = lib.callback.await('gs_smuggling:action', false, 'load')
    notify(ok, msg)
    if not ok then return end
    for _, o in ipairs(crates) do if DoesEntityExist(o) then DeleteEntity(o) end end
    crates = {}
    exports.gs_markers:Remove('gs_smuggling:runload')
    point(run.drop, 'Plage de livraison')
    exports.gs_markers:Add('gs_smuggling:rundrop', { coords = run.drop, style = 'hidden', event = 'gs_smuggling:client:deliver', prompt = 'Décharger la cargaison', reach = 25.0 })
end)

AddEventHandler('gs_smuggling:client:deliver', function()
    if not run then return end
    if not lib.progressBar({ duration = 8000, label = 'Déchargement…', canCancel = true, disable = { move = true, combat = true } }) then return end
    local ok, msg = lib.callback.await('gs_smuggling:action', false, 'deliver')
    notify(ok, msg)
    if ok then clearRun() end
end)

-- Garde-côtes IA (aucun policier en service) : un bateau rapide prend le contrebandier en chasse
RegisterNetEvent('gs_smuggling:client:coastguard', function()
    local veh = cache.vehicle
    if not veh then return end
    local CG = Config.CoastGuard
    local bh, ph = GetHashKey(CG.boat), GetHashKey(CG.ped)
    if not lib.requestModel(bh, 5000) or not lib.requestModel(ph, 5000) then return end
    local c = GetOffsetFromEntityInWorldCoords(veh, 0.0, -180.0, 0.0)
    local boat = CreateVehicle(bh, c.x, c.y, 0.5, GetEntityHeading(veh), true, false)
    SetVehicleSiren(boat, true)
    local driver = CreatePedInsideVehicle(boat, 6, ph, -1, true, false)
    local gunner = CreatePedInsideVehicle(boat, 6, ph, 0, true, false)
    for _, p in ipairs({ driver, gunner }) do
        SetPedRelationshipGroupHash(p, GetHashKey('COP'))
        GiveWeaponToPed(p, GetHashKey('WEAPON_CARBINERIFLE'), 120, false, true)
        SetPedKeepTask(p, true)
    end
    TaskVehicleChase(driver, cache.ped)
    TaskCombatPed(gunner, cache.ped, 0, 16)
    lib.notify({ title = 'Garde-côtes', description = 'Un bateau des garde-côtes te prend en chasse !', type = 'error', icon = 'ship', duration = 8000 })
    SetTimeout(240000, function()
        for _, e in ipairs({ gunner, driver, boat }) do if DoesEntityExist(e) then SetEntityAsNoLongerNeeded(e) end end
    end)
end)

-- Contact : PNJ créé à l'approche
CreateThread(function()
    local c = Config.Contact
    exports.gs_markers:Add('gs_smuggling:contact', { coords = vec3(c.x, c.y, c.z), style = 'hidden', event = 'gs_smuggling:client:contact', prompt = 'Parler au docker', reach = 2.0 })
    while true do
        local d = #(GetEntityCoords(cache.ped) - vec3(c.x, c.y, c.z))
        if d < 60.0 and not contact then
            local h = GetHashKey(Config.ContactModel)
            if lib.requestModel(h, 5000) then
                contact = CreatePed(4, h, c.x, c.y, c.z - 1.0, c.w, false, true)
                SetEntityInvincible(contact, true) FreezeEntityPosition(contact, true) SetBlockingOfNonTemporaryEvents(contact, true)
                TaskStartScenarioInPlace(contact, 'WORLD_HUMAN_SMOKING', 0, true)
                SetModelAsNoLongerNeeded(h)
            end
        elseif d > 80.0 and contact then DeletePed(contact) contact = nil end
        Wait(2000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearRun()
    exports.gs_markers:RemovePrefix('gs_smuggling:')
    if contact and DoesEntityExist(contact) then DeletePed(contact) end
end)
