-- gs_animalerie (client) · V12.63. Près de la boutique : animaux exposés (créés chez chaque joueur, invincibles, figés dans leur
-- animation). Employé en service : postes [E] (réserve, gamelles, cages, toilettage, comptoir), animations, carton porté de la
-- réserve aux gamelles, client au comptoir quand le serveur en annonce un. Boucle lente (1,5 s) ; rien loin de la boutique.
local animals = {}      -- [i] = ped
local postsShown = false
local carry = { prop = nil }
local customer = { ped = nil, due = nil }
local onDuty = false
local busy = false

local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end
local function anchor() return GlobalState.gsPetshopAnchor end
local function groundAt(c)
    local found, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 1.5, false)
    return (found and math.abs(gz - c.z) < 2.5) and gz or c.z
end

local function loadModel(name)
    local h = GetHashKey(name)
    if not IsModelInCdimage(h) then return nil end
    return lib.requestModel(h, 5000) and h or nil
end

local function spawnAnimals()
    for i, a in ipairs(Config.Animals) do
        if not animals[i] then
            local at = Config.PostAt(a.post, anchor())
            local h = at and loadModel(a.model)
            if h then
                local p = Config.Around(at, a.offset)
                local ped = CreatePed(28, h, p.x, p.y, groundAt(p), ((at.w or 0.0) + (a.heading or 0.0)) % 360.0, false, true)
                SetModelAsNoLongerNeeded(h)
                SetEntityInvincible(ped, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                SetPedFleeAttributes(ped, 0, false)
                if a.scenario then TaskStartScenarioInPlace(ped, a.scenario, 0, true) end
                SetTimeout(1500, function() if DoesEntityExist(ped) then FreezeEntityPosition(ped, true) end end)
                animals[i] = ped
            end
        end
    end
end

local function clearAnimals()
    for i, ped in pairs(animals) do if DoesEntityExist(ped) then DeleteEntity(ped) end animals[i] = nil end
end

-- Carton de croquettes (accessoire + démarche) ---------------------------------------------------------------------------
local function dropCarry()
    if carry.prop and DoesEntityExist(carry.prop) then DeleteEntity(carry.prop) end
    carry.prop = nil
    ClearPedSecondaryTask(cache.ped)
end

local function startCarry()
    dropCarry()
    local C = Config.Carry
    local h = loadModel(C.model)
    if not h then return end
    local ped = cache.ped
    local prop = CreateObject(h, 0.0, 0.0, 0.0, false, false, false) -- local : seul le porteur en a besoin
    SetModelAsNoLongerNeeded(h)
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, C.bone), C.pos.x, C.pos.y, C.pos.z, C.rot.x, C.rot.y, C.rot.z, true, true, false, true, 1, true)
    if lib.requestAnimDict(C.anim.dict, 3000) then TaskPlayAnim(ped, C.anim.dict, C.anim.clip, 3.0, 3.0, -1, C.anim.flag, 0, false, false, false) end
    carry.prop = prop
    SetTimeout(C.seconds * 1000, function() if carry.prop == prop then dropCarry() end end)
end

-- Client du comptoir -----------------------------------------------------------------------------------------------------
local function clearCustomer()
    if customer.ped and DoesEntityExist(customer.ped) then
        local ped = customer.ped
        TaskWanderStandard(ped, 10.0, 10)
        SetTimeout(8000, function() if DoesEntityExist(ped) then DeleteEntity(ped) end end)
    end
    customer.ped = nil
end

local function spawnCustomer()
    if customer.ped then return end
    local at = Config.PostAt('counter', anchor())
    local models = Config.Customers.models
    local h = at and loadModel(models[math.random(1, #models)])
    if not h then return end
    local p = Config.Around(at, vec3(0.0, 1.2, 0.0)) -- devant le comptoir
    local ped = CreatePed(4, h, p.x, p.y, groundAt(p), ((at.w or 0.0) + 180.0) % 360.0, false, true)
    SetModelAsNoLongerNeeded(h)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
    customer.ped = ped
    lib.notify({ title = 'Animalerie', description = 'Un client attend au comptoir.', type = 'inform', icon = 'paw' })
end

-- Tâches -----------------------------------------------------------------------------------------------------------------
local function doTask(name)
    if busy then return end
    local t = Config.Tasks[name]
    if not t then return end
    if t.needs and not carry.prop then return notify(false, 'Il te faut d\'abord un carton de croquettes (réserve).') end
    busy = true
    if name == 'bowls' then dropCarry() end
    local anim = t.anim and { dict = t.anim.dict, clip = t.anim.clip, flag = t.anim.flag } or nil
    local ok = lib.progressBar({ duration = t.ms, label = t.label .. '…', canCancel = true, disable = { move = true, car = true, combat = true },
        anim = anim or (t.scenario and { scenario = t.scenario }) or nil })
    ClearPedTasks(cache.ped)
    if ok then
        local done, msg = lib.callback.await('gs_animalerie:task', false, name)
        notify(done, msg)
        if done and name == 'stock' then startCarry() end
        if done and name == 'serve' then clearCustomer() end
    end
    busy = false
end
AddEventHandler('gs_animalerie:client:task', doTask)

local ORDER = { 'counter', 'stock', 'bowls', 'cages', 'grooming' }
local TASK_OF = { counter = 'serve', stock = 'stock', bowls = 'bowls', cages = 'cages', grooming = 'grooming' }

local function showPosts(on)
    if on == postsShown then return end
    postsShown = on
    for _, key in ipairs(ORDER) do
        local id = 'gs_animalerie:' .. key
        exports.gs_markers:Remove(id)
        local at = on and Config.PostAt(key, anchor())
        if at then
            local t = Config.Tasks[TASK_OF[key]]
            exports.gs_markers:Add(id, { coords = vec3(at.x, at.y, at.z), style = 'job', label = Config.Posts[key].label:gsub('^Animalerie · ', ''),
                event = 'gs_animalerie:client:task', args = { TASK_OF[key] }, prompt = t.label, reach = Config.Range, distance = 20.0 })
        end
    end
end

local function refreshDuty(j)
    onDuty = j ~= nil and j.name == Config.Job and j.onduty == true
    if not onDuty then showPosts(false) dropCarry() clearCustomer() end
end
AddEventHandler('gs_bridge:client:jobUpdated', refreshDuty)

-- Boucle lente : animaux à l'approche, postes et client pour l'employé en service ------------------------------------------
CreateThread(function()
    Wait(2000)
    pcall(function() refreshDuty(exports.gs_bridge:GetJob()) end)
    local stateAt = 0
    while true do
        local at = Config.PostAt('counter', anchor())
        local near = at and #(GetEntityCoords(cache.ped) - vec3(at.x, at.y, at.z)) < Config.ShowDistance
        if near then spawnAnimals() elseif next(animals) and (not at or #(GetEntityCoords(cache.ped) - vec3(at.x, at.y, at.z)) > Config.ShowDistance + 15.0) then clearAnimals() end
        if onDuty and near then
            showPosts(true)
            if GetGameTimer() >= stateAt then
                stateAt = GetGameTimer() + 15000
                local st = lib.callback.await('gs_animalerie:state', false)
                if st and st.duty and st.customerIn == 0 then spawnCustomer() elseif st and st.customerIn and st.customerIn > 0 then clearCustomer() end
            end
        else
            showPosts(false)
            if customer.ped then clearCustomer() end
        end
        Wait(1500)
    end
end)

-- Les postes suivent un déplacement fait par le staff (F11) ou la position de la map trouvée par le serveur
AddStateBagChangeHandler('gsPetshopAnchor', 'global', function()
    SetTimeout(500, function() clearAnimals() if postsShown then postsShown = false end end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearAnimals() dropCarry()
    if customer.ped and DoesEntityExist(customer.ped) then DeleteEntity(customer.ped) end
    exports.gs_markers:RemovePrefix('gs_animalerie:')
end)
