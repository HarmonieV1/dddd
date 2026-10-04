-- gs_evidence (serveur) · V9 « Appareil photo argentique ». Le serveur décide qui et quoi est sur la photo (joueurs et
-- véhicules devant l'objectif) : le client ne peut pas truquer une photo. Les identités restent côté serveur (KVP) ;
-- l'objet ne porte que le numéro de la photo, le lieu, la date et ce qu'on voit (descriptions, plaques).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local C = Config.Camera

Photo = { wall = {} }

local function zoneOf(c)
    local ok, z = pcall(function() return exports.gs_rumors:Zone(c) end)
    return ok and z or 'Los Santos'
end
local function describe(src)
    local ok, d = pcall(function() return exports.gs_wanted:Describe(src) end)
    return ok and d or 'quelqu\'un'
end
local function store(id, rec) SetResourceKvp('gs_photo:' .. id, json.encode(rec)) end
function Photo.get(id)
    local ok, r = pcall(function() return json.decode(GetResourceKvpString('gs_photo:' .. tostring(id)) or 'null') end)
    return ok and r or nil
end

function Photo.take(src, url)
    if Bridge:GetItemCount(src, C.item) < 1 then return false, 'Il te faut un appareil photo.' end
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    local me, h = GetEntityCoords(ped), math.rad(GetEntityHeading(ped))
    local fwd = vec3(-math.sin(h), math.cos(h), 0.0)
    local function inFrame(c)
        local d = c - me
        local len = #d
        return len > 0.5 and len <= C.range and (d.x * fwd.x + d.y * fwd.y) / len >= C.front
    end
    local subjects, seen = {}, {}
    for _, id in ipairs(GetPlayers()) do
        local p = tonumber(id)
        if p ~= src and inFrame(GetEntityCoords(GetPlayerPed(p))) then
            subjects[#subjects + 1] = { cid = Bridge:GetIdentifier(p), desc = describe(p) }
            seen[#seen + 1] = describe(p)
        end
    end
    local plates = {}
    for _, veh in ipairs(GetAllVehicles()) do
        if #plates < C.maxPlates and inFrame(GetEntityCoords(veh)) then plates[#plates + 1] = (GetVehicleNumberPlateText(veh) or ''):gsub('%s+$', '') end
    end
    local id = ('%d%03d'):format(os.time(), math.random(0, 999))
    local place, date = zoneOf(me), os.date('%d/%m %H:%M')
    store(id, { subjects = subjects, plates = plates, place = place, date = date, by = Bridge:GetIdentifier(src) })
    local what = #seen > 0 and table.concat(seen, ' ; ') or 'personne'
    local md = { photo = id, label = 'Photo · ' .. place, description = ('%s · On y voit : %s%s'):format(date, what,
        #plates > 0 and (' · Plaques : ' .. table.concat(plates, ', ')) or ''), image = type(url) == 'string' and url:match('^https://') and url or nil }
    if not Bridge:AddItem(src, C.photo, 1, md) then return false, 'Plus de place pour la photo.' end
    TriggerEvent('gs_evidence:server:photo', src) -- V9 : biographie
    return true, 'Photo développée.'
end

--- Accrocher au mur (persistant) / décrocher (l'auteur seulement)
local function saveWall() SetResourceKvp('gs_photo_wall', json.encode(Photo.wall)) end
local function publishWall()
    local out = {}
    for i, w in ipairs(Photo.wall) do out[i] = { i = i, x = w.x, y = w.y, z = w.z, label = w.label, image = w.image, text = w.text } end
    GlobalState.gsWallPhotos = out
end

function Photo.hang(src, md)
    if type(md) ~= 'table' or not md.photo then return false end
    local cid = Bridge:GetIdentifier(src)
    local mine = 0
    for _, w in ipairs(Photo.wall) do if w.owner == cid then mine = mine + 1 end end
    if mine >= C.perPlayerWall or #Photo.wall >= C.maxWall then return false, 'Trop de photos accrochées.' end
    if not Bridge:RemoveItem(src, C.photo, 1, { photo = md.photo }) then return false, 'Photo introuvable.' end
    local c = GetEntityCoords(GetPlayerPed(src))
    Photo.wall[#Photo.wall + 1] = { x = c.x, y = c.y, z = c.z + 0.6, owner = cid, photo = md.photo, label = md.label, text = md.description, image = md.image }
    saveWall() publishWall()
    return true, 'Photo accrochée.'
end

function Photo.unhang(src, i)
    local w = Photo.wall[tonumber(i) or 0]
    if not w then return false, 'Plus rien ici.' end
    if w.owner ~= Bridge:GetIdentifier(src) then return false, 'Ce n\'est pas ta photo.' end
    local ped = GetPlayerPed(src)
    if #(GetEntityCoords(ped) - vec3(w.x, w.y, w.z)) > 4.0 then return false, 'Trop loin.' end
    if not Bridge:AddItem(src, C.photo, 1, { photo = w.photo, label = w.label, description = w.text, image = w.image }) then return false, 'Inventaire plein.' end
    table.remove(Photo.wall, tonumber(i))
    saveWall() publishWall()
    return true, 'Photo décrochée.'
end

--- Labo : qui est sur la photo (nom si fiché, sinon profil inconnu)
function Photo.analyze(src, id)
    if not exports.gs_jobs:IsOnDutyAs(src, Config.PoliceJob) then return false, 'Réservé à la police.' end
    local ped = GetPlayerPed(src)
    if ped == 0 or #(GetEntityCoords(ped) - Config.Lab.coords) > Config.Lab.radius + 2.0 then return false, 'Il faut être au labo.' end
    local r = Photo.get(id)
    if not r then return false, 'Photo illisible.' end
    local out = {}
    for _, s in ipairs(r.subjects or {}) do
        local name = s.cid and Store.filed(s.cid)
        out[#out + 1] = name and ('%s (fiché)'):format(name) or ('%s · profil %s'):format(s.desc, Evidence.profile(s.cid or '?'))
    end
    if #(r.plates or {}) > 0 then out[#out + 1] = 'Plaques : ' .. table.concat(r.plates, ', ') end
    if #out == 0 then out[1] = 'Personne d\'identifiable sur ce cliché.' end
    return true, out
end

lib.callback.register('gs_evidence:photo', function(src, action, a)
    if not Security:RateLimit(src, 'gs_evidence:photo', 3, 5000) then return false, 'Doucement.' end
    if action == 'take' then return Photo.take(src, a)
    elseif action == 'hang' then return Photo.hang(src, a)
    elseif action == 'unhang' then return Photo.unhang(src, a)
    elseif action == 'analyze' then return Photo.analyze(src, a) end
    return false
end)

CreateThread(function()
    local ok, w = pcall(function() return json.decode(GetResourceKvpString('gs_photo_wall') or '[]') end)
    Photo.wall = ok and type(w) == 'table' and w or {}
    publishWall()
end)
