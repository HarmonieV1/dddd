-- gs_details (client) · V11.5 « Armes dans le dos ». Les armes longues de l'inventaire (fusils, pompes, mitraillettes,
-- précision) qui ne sont pas en main sont visibles dans le dos du personnage, pour tout le monde : chaque client dessine
-- les objets (locaux, sans réseau) des joueurs proches d'après leur state bag `gsBack`. Pistolets et armes blanches : rien.
-- Coût : une mise à jour à chaque changement d'inventaire ou d'arme, une boucle 1 s pour les voisins.
local B = Config.Back
local mine = {}        -- liste des hash d'armes à montrer (moi), publiée dans le state bag
local objects = {}     -- [serverId] = { [slot] = { hash, obj } }
local currentWeapon    -- hash de l'arme en main (ox_inventory)

local function isLong(name) return B.weapons[name] == true end

--- Ce que je porte dans le dos, d'après mon inventaire ox_inventory (arme en main exclue)
local function compute()
    local list = {}
    local ok, items = pcall(function() return exports.ox_inventory:GetPlayerItems() end) -- [API] ox_inventory
    if not ok or type(items) ~= 'table' then return list end
    for _, it in pairs(items) do
        if it and it.name and isLong(it.name) then
            local hash = joaat(it.name)
            if hash ~= currentWeapon then list[#list + 1] = hash end
            if #list >= B.max then break end
        end
    end
    return list
end

local function same(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end

local pending = false
local function publish()
    if pending then return end
    pending = true
    SetTimeout(400, function() -- plusieurs changements d'inventaire d'un coup → une seule publication
        pending = false
        local list = compute()
        if same(list, mine) then return end
        mine = list
        LocalPlayer.state:set('gsBack', #list > 0 and list or nil, true)
    end)
end

AddEventHandler('ox_inventory:updateInventory', publish)               -- [API] ox_inventory
AddEventHandler('ox_inventory:currentWeapon', function(w)              -- [API] ox_inventory
    currentWeapon = w and w.hash or nil
    publish()
end)
AddEventHandler('gs_bridge:client:playerLoaded', function() SetTimeout(3000, publish) end)

-- Dessin pour les joueurs proches (moi compris) -------------------------------------------------------------
local function removeAll(sid)
    for _, e in pairs(objects[sid] or {}) do if DoesEntityExist(e.obj) then DeleteEntity(e.obj) end end
    objects[sid] = nil
end

local function attach(ped, hash, slot)
    local obj = CreateWeaponObject(hash, 1, 0.0, 0.0, 0.0, true, 1.0, 0)
    if not obj or obj == 0 then return nil end
    local o = B.slots[slot]
    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, B.bone), o.x, o.y, o.z, o.rx, o.ry, o.rz, true, true, false, true, 1, true)
    SetEntityCollision(obj, false, false)
    return obj
end

local function sync(sid, ped, list)
    local cur = objects[sid] or {}
    local want = {}
    for slot = 1, math.min(#list, #B.slots) do want[slot] = list[slot] end
    for slot, e in pairs(cur) do
        if want[slot] ~= e.hash or not DoesEntityExist(e.obj) then
            if DoesEntityExist(e.obj) then DeleteEntity(e.obj) end
            cur[slot] = nil
        end
    end
    for slot, hash in pairs(want) do
        if not cur[slot] then
            local obj = attach(ped, hash, slot)
            if obj then cur[slot] = { hash = hash, obj = obj } end
        end
    end
    objects[sid] = next(cur) and cur or nil
end

CreateThread(function()
    while true do
        local seen = {}
        local me = GetEntityCoords(cache.ped)
        for _, pid in ipairs(GetActivePlayers()) do
            local ped = GetPlayerPed(pid)
            local sid = GetPlayerServerId(pid)
            if ped ~= 0 and DoesEntityExist(ped) and #(GetEntityCoords(ped) - me) < B.range then
                seen[sid] = true
                local list = Player(sid).state.gsBack
                if type(list) == 'table' and #list > 0 and not IsEntityDead(ped) then sync(sid, ped, list) else removeAll(sid) end
            end
        end
        for sid in pairs(objects) do if not seen[sid] then removeAll(sid) end end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for sid in pairs(objects) do removeAll(sid) end
    LocalPlayer.state:set('gsBack', nil, true)
end)
