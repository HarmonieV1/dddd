-- gs_insurance (serveur) · V12 « Le registre des véhicules disparus ». Une voiture déclarée volée et jamais retrouvée
-- refait surface après `Config.Lost.afterHours` : à la casse, dans un garage louche, ou aux enchères de la fourrière.
-- Le carnet (gs_carnet, par plaque) reste intact. Une rumeur circule ; le propriétaire peut enquêter et la récupérer :
-- s'il avait touché l'indemnité, l'assurance la reprend (sans pénalité), le dossier passe en « recovered ».
local Bridge = exports.gs_bridge
local L = Config.Lost

Lost = { list = {}, spawned = {} } -- list[vehicleId] = { id, plate, model, fate, x, y, z, w, at } ; spawned[vehicleId] = entité

local function now() return os.time() end
local function started(r) return GetResourceState(r) == 'started' end

local function pick(list) return list[math.random(#list)] end

--- Choix du sort d'un véhicule jamais retrouvé
function Lost.fateOf(c)
    local roll, acc = math.random(), 0
    for _, f in ipairs(L.fates) do
        acc = acc + f.weight
        if roll <= acc then return f.id end
    end
    return L.fates[#L.fates].id
end

--- Le véhicule refait surface (appelé par le tick 48 h après la déclaration)
function Lost.surface(c)
    if Lost.list[c.id] then return false end
    local model = Store.modelOf(c.id)
    if not model then return false end
    local fate = Lost.fateOf(c)
    local entry = { id = c.id, plate = c.plate, model = model, fate = fate, at = now() }
    if fate == 'encheres' then
        -- aux enchères de la fourrière (gs_auction écoute cet événement) : le propriétaire peut la racheter samedi
        TriggerEvent('gs_police:server:impounded', GetHashKey(model), c.plate)
    else
        local place = pick(fate == 'casse' and L.places.casse or L.places.garage)
        entry.x, entry.y, entry.z, entry.w = place.x, place.y, place.z, place.w
    end
    Lost.list[c.id] = entry
    Store.lostSet(entry)
    -- la ville en parle (sans dire où exactement)
    local zone = ''
    if entry.x and started('gs_rumors') then
        pcall(function() zone = exports.gs_rumors:Zone(vec3(entry.x, entry.y, entry.z)) or '' end)
    end
    local hint = fate == 'encheres' and 'elle serait aux enchères de la fourrière samedi' or
        (fate == 'casse' and ('elle aurait été vue à la casse, du côté de %s'):format(zone) or ('elle dormirait dans un garage louche, du côté de %s'):format(zone))
    if started('gs_rumors') then
        pcall(function() exports.gs_rumors:Add(('une voiture volée a refait surface'):format(), ('Plaque %s : %s.'):format(c.plate, hint)) end)
    end
    local src = Bridge:GetSourceByIdentifier(c.cid)
    if src then Bridge:Notify(src, ('Un tuyau sur ta %s (%s) : %s. Si tu la reprends, l\'assurance récupère son indemnité, sans pénalité.'):format(model, c.plate, hint), 'inform') end
    return true
end

--- Apparition physique quand un joueur approche (entité serveur, plaque d'origine, une seule fois)
function Lost.tick()
    local t = now()
    for id, e in pairs(Lost.list) do
        if e.x and not Lost.spawned[id] then
            for _, pid in ipairs(GetPlayers()) do
                local ped = GetPlayerPed(tonumber(pid))
                if ped ~= 0 and #(GetEntityCoords(ped) - vec3(e.x, e.y, e.z)) < L.spawnRange then
                    local veh = CreateVehicleServerSetter(GetHashKey(e.model), 'automobile', e.x, e.y, e.z, e.w or 0.0)
                    if veh and veh ~= 0 then
                        Lost.spawned[id] = veh
                        SetTimeout(1500, function() if DoesEntityExist(veh) then SetVehicleNumberPlateText(veh, e.plate:sub(1, 8)) end end)
                    end
                    break
                end
            end
        elseif e.x and Lost.spawned[id] and not DoesEntityExist(Lost.spawned[id]) then
            Lost.spawned[id] = nil -- détruite ou nettoyée : elle réapparaîtra à la prochaine approche
        end
        if t - e.at > L.keepDays * 86400 then Lost.forget(id) end
    end
end

function Lost.forget(id)
    local e = Lost.list[id]
    if not e then return end
    Lost.list[id] = nil
    Lost.spawned[id] = nil
    Store.lostClear(id)
end

--- Le propriétaire reprend le volant : dossier « recovered », indemnité reprise si elle avait été versée
function Lost.recovered(c, src)
    local e = Lost.list[c.id]
    if not e then return false end
    local taken = 0
    if c.status == 'paid' then
        if Bridge:RemoveMoney(src, 'bank', c.amount, 'reprise indemnité assurance') or Bridge:RemoveMoney(src, 'cash', c.amount, 'reprise indemnité assurance') then taken = c.amount end
    end
    c.status = 'recovered'
    Store.saveClaim(c)
    Lost.forget(c.id)
    Bridge:Notify(src, taken > 0 and ('Mors Mutual : véhicule retrouvé, indemnité de %d $ reprise. Bon retour au volant.'):format(taken)
        or (c.status == 'recovered' and c.amount > 0 and taken == 0 and 'Mors Mutual : véhicule retrouvé. L\'indemnité versée reste due (passe à l\'agence).' or 'Mors Mutual : véhicule retrouvé, dossier classé.'), 'success')
    return true
end

--- Les dossiers de vol jamais clos depuis `afterHours` refont surface
function Lost.scan(claims)
    local n = 0
    for _, c in pairs(claims) do
        if (c.status == 'pending' or c.status == 'paid') and now() - c.at >= L.afterHours * 3600 and not Lost.list[c.id] then
            if Lost.surface(c) then n = n + 1 end
        end
    end
    return n
end

exports('LostVehicles', function() local l = {} for _, e in pairs(Lost.list) do l[#l + 1] = { plate = e.plate, model = e.model, fate = e.fate } end return l end)

CreateThread(function()
    Wait(3000)
    for _, e in ipairs(Store.lostAll()) do Lost.list[e.id] = e end
    while true do
        Wait(L.tick * 1000)
        Lost.scan(Claims.list)
        Lost.tick()
    end
end)
