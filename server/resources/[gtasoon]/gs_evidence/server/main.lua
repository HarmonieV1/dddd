-- gs_evidence (serveur) · V8 « Enquêtes avec preuves ». Les traces naissent des faits constatés par le serveur (tir,
-- blessure, crime signalé ou non par gs_wanted) ; la police les ramasse (scellé = objet), le labo les analyse.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local JobsApi  = exports.gs_jobs

Evidence = { traces = {}, seals = {}, nextId = 0, nextSeal = 0, count = 0 }

local function now() return os.time() end
local function isPolice(src) return JobsApi:IsOnDutyAs(src, Config.PoliceJob) end
local function toVec3(c) return vec3(c.x + 0.0, c.y + 0.0, c.z + 0.0) end
local function pedOf(src) local p = GetPlayerPed(src) return p ~= 0 and p or nil end

--- Profil inconnu stable (même personne = même code) : relie les scènes sans révéler l'identité.
function Evidence.profile(cid)
    local h = 5381
    for i = 1, #cid do h = (h * 33 + cid:byte(i)) % 1048573 end
    return ('P-%05X'):format(h)
end

local function raining()
    if GetResourceState('gs_weather') ~= 'started' then return false end
    local ok, w = pcall(function() return exports.gs_weather:GetWeather() end)
    return ok and Config.RainWeathers[w] == true
end

-- Traces --------------------------------------------------------------------------------------------------------

--- Ajoute une trace (ou incrémente une trace identique toute proche). data.key = ce qui identifie l'auteur.
function Evidence.add(kind, coords, data)
    if not Config.Kinds[kind] or not coords then return nil end
    coords = toVec3(coords)
    for _, t in pairs(Evidence.traces) do
        if t.kind == kind and t.key == data.key and #(t.coords - coords) <= Config.MergeRadius and now() - t.at <= 120 then
            t.n, t.at = t.n + 1, now()
            return t
        end
    end
    if Evidence.count >= Config.MaxTraces then Evidence.decay(true) end
    Evidence.nextId = Evidence.nextId + 1
    local t = { id = Evidence.nextId, kind = kind, coords = coords, at = now(), n = 1 }
    for k, v in pairs(data) do t[k] = v end
    Evidence.traces[t.id] = t
    Evidence.count = Evidence.count + 1
    return t
end

local function remove(id)
    if Evidence.traces[id] then Evidence.traces[id] = nil Evidence.count = Evidence.count - 1 end
end

--- Les traces vieillissent (plus vite sous la pluie pour le sang et les pneus). force = retirer la plus vieille.
function Evidence.decay(force)
    local wet, t0 = raining(), now()
    local oldest
    for id, t in pairs(Evidence.traces) do
        local k = Config.Kinds[t.kind]
        local age = (t0 - t.at) * ((wet and k.rain) or 1)
        if age > k.decay * 60 then remove(id)
        elseif not oldest or t.at < Evidence.traces[oldest].at then oldest = id end
    end
    if force and oldest then remove(oldest) end
end

function Evidence.hasGloves(src)
    return Player(src).state.gsGloves == true and Bridge:GetItemCount(src, Config.Items.gloves) > 0
end

--- Empreintes laissées sur une scène (sans gants).
function Evidence.touch(src, coords)
    if Evidence.hasGloves(src) then return nil end
    local cid = Bridge:GetIdentifier(src)
    if not cid then return nil end
    return Evidence.add('print', coords, { key = cid, cid = cid })
end

--- Arme en main (ox_inventory) : nom, numéro de série, propriétaire enregistré.
local function currentWeapon(src)
    local ok, w = pcall(function() return exports.ox_inventory:GetCurrentWeapon(src) end) -- [API] ox_inventory
    if not ok or type(w) ~= 'table' then return {} end
    local md = w.metadata or {}
    return { label = w.label or w.name, serial = md.serial, registered = md.registered }
end

-- Tir : douilles au sol (le client signale qu'il tire, le serveur lit l'arme et la position)
RegisterNetEvent('gs_evidence:server:shot', function(silenced)
    local src = source
    if not Security:RateLimit(src, 'gs_evidence:shot', 1, 1500) then return end
    local ped = pedOf(src)
    if not ped or GetSelectedPedWeapon(ped) == GetHashKey('WEAPON_UNARMED') or isPolice(src) then return end
    TriggerEvent('gs_evidence:server:shotFired', src, silenced == true) -- V10.2 : gs_wanted (signalement), un seul détecteur
    local w = currentWeapon(src)
    Evidence.add('casing', GetEntityCoords(ped), { key = w.serial or tostring(GetSelectedPedWeapon(ped)),
        weapon = w.label or 'Arme à feu', serial = w.serial, registered = w.registered })
end)

-- Blessure : du sang au sol (le serveur vérifie que le joueur est vraiment blessé)
RegisterNetEvent('gs_evidence:server:hurt', function()
    local src = source
    if not Security:RateLimit(src, 'gs_evidence:hurt', 1, 15000) then return end
    local ped, cid = pedOf(src), Bridge:GetIdentifier(src)
    if not ped or not cid or GetEntityHealth(ped) >= Config.Blood.health then return end
    Evidence.add('blood', GetEntityCoords(ped), { key = cid, cid = cid })
end)

-- Crime (gs_wanted, signalé ou non) : empreintes, traces de pneus, éclats de peinture
AddEventHandler('gs_wanted:server:crime', function(src, crimeType, coords, veh)
    if Config.PrintCrimes[crimeType] then Evidence.touch(src, coords) end
    if veh and veh ~= 0 and DoesEntityExist(veh) then
        local plate = (GetVehicleNumberPlateText(veh) or ''):gsub('%s+$', '')
        local vtype = GetVehicleType(veh)
        Evidence.add('tyre', coords, { key = plate, plate = plate, vtype = vtype })
        if GetVehicleBodyHealth(veh) < Config.Paint.body then
            Evidence.add('paint', coords, { key = plate, plate = plate, color = GetVehicleColours(veh) })
        end
    end
end)

-- Gants : enfiler / retirer (objet requis)
lib.callback.register('gs_evidence:gloves', function(src)
    if Bridge:GetItemCount(src, Config.Items.gloves) <= 0 then return false, 'Il te faut des gants.' end
    local on = Player(src).state.gsGloves ~= true
    Player(src).state:set('gsGloves', on or nil, true)
    return true, on and 'Gants enfilés : pas d\'empreintes.' or 'Gants retirés.'
end)

-- Javel : efface les traces autour (pas les scellés déjà ramassés)
lib.callback.register('gs_evidence:clean', function(src)
    if not Security:RateLimit(src, 'gs_evidence:clean', 1, Config.Clean.duration - 1000) then return false, 'Doucement.' end
    local ped = pedOf(src)
    if not ped then return false end
    if not Bridge:RemoveItem(src, Config.Items.bleach, 1) then return false, 'Il te faut de la javel.' end
    local me, n = GetEntityCoords(ped), 0
    for id, t in pairs(Evidence.traces) do
        if #(t.coords - me) <= Config.Clean.radius then remove(id) n = n + 1 end
    end
    return true, n > 0 and 'Scène nettoyée.' or 'Rien à nettoyer ici… a priori.'
end)

-- Police : traces visibles à la lampe torche
lib.callback.register('gs_evidence:nearby', function(src)
    if not isPolice(src) or not Security:RateLimit(src, 'gs_evidence:nearby', 4, 2000) then return {} end
    local ped = pedOf(src)
    if not ped then return {} end
    local me, out = GetEntityCoords(ped), {}
    for _, t in pairs(Evidence.traces) do
        if #(t.coords - me) <= Config.Search.range then
            out[#out + 1] = { id = t.id, kind = t.kind, n = t.n, x = t.coords.x, y = t.coords.y, z = t.coords.z }
        end
    end
    return out
end)

-- Police : mise sous scellé (l'objet « scellé » porte son numéro)
lib.callback.register('gs_evidence:collect', function(src, id)
    if not Security:RateLimit(src, 'gs_evidence:collect', 3, 3000) then return false, 'Doucement.' end
    if not isPolice(src) then return false, 'Réservé à la police en service.' end
    local t = Evidence.traces[tonumber(id)]
    local ped = pedOf(src)
    if not t or not ped then return false, 'Plus rien ici.' end
    if #(GetEntityCoords(ped) - t.coords) > Config.Search.collect then return false, 'Trop loin.' end
    Evidence.nextSeal = Evidence.nextSeal + 1
    local s = { id = Evidence.nextSeal, status = 'sealed', by = Bridge:GetIdentifier(src), byName = Bridge:GetName(src), at = now(),
        date = os.date('%d/%m %H:%M') }
    for k, v in pairs(t) do if s[k] == nil and k ~= 'id' then s[k] = v end end
    s.trace = t.id
    local label = ('Scellé n°%d · %s'):format(s.id, Config.Kinds[t.kind].label)
    if not Bridge:AddItem(src, Config.Items.bag, 1, { seal = s.id, label = label, description = s.date }) then
        Evidence.nextSeal = Evidence.nextSeal - 1
        return false, 'Inventaire plein.'
    end
    Evidence.seals[s.id] = s
    remove(t.id)
    return true, label
end)

-- Labo ----------------------------------------------------------------------------------------------------------

-- Même origine : même personne (sang / empreintes), même véhicule (pneus / peinture), même arme (douilles)
local GROUP = { blood = 'person', print = 'person', tyre = 'vehicle', paint = 'vehicle', casing = 'weapon' }
local function linked(s)
    local out = {}
    for id, o in pairs(Evidence.seals) do
        if id ~= s.id and o.key and o.key == s.key and GROUP[o.kind] == GROUP[s.kind] then out[#out + 1] = id end
    end
    table.sort(out)
    return out
end

--- Résultat d'analyse (texte brut pour la police)
function Evidence.analyze(s)
    local r
    if s.kind == 'casing' then
        r = ('%s · n° de série %s'):format(s.weapon or 'Arme à feu', s.serial or 'limé')
        r = r .. (s.registered and (' · enregistrée au nom de ' .. s.registered) or ' · arme non enregistrée')
    elseif s.kind == 'blood' or s.kind == 'print' then
        local name = s.cid and Store.filed(s.cid)
        r = name and ('Correspond à %s (fiché)'):format(name) or ('Profil inconnu %s (personne non fichée)'):format(Evidence.profile(s.cid or '?'))
    elseif s.kind == 'tyre' then
        r = ('Pneus de %s'):format(({ automobile = 'voiture', bike = 'deux-roues', quadbike = 'quad' })[s.vtype] or 'véhicule')
    elseif s.kind == 'paint' then
        local ok, name = pcall(function() return exports.gs_wanted:ColorName(s.color) end)
        name = ok and name or nil
        r = ('Peinture %s'):format(name or ('teinte n°' .. tostring(s.color)))
    end
    local links = linked(s)
    if #links > 0 then
        local l = {}
        for _, id in ipairs(links) do l[#l + 1] = 'n°' .. id end
        r = r .. ' · même origine que les scellés ' .. table.concat(l, ', ')
    end
    return r
end

local function atLab(src)
    local ped = pedOf(src)
    return ped and #(GetEntityCoords(ped) - Config.Lab.coords) <= Config.Lab.radius + 2.0
end

local function view(s)
    return { id = s.id, kind = s.kind, label = Config.Kinds[s.kind].label, status = s.status, date = s.date, by = s.byName,
        left = s.readyAt and math.max(0, s.readyAt - now()) or nil, result = s.result }
end

function Evidence.lab(src, action, id)
    if not isPolice(src) then return false, 'Réservé à la police en service.' end
    if not atLab(src) then return false, 'Il faut être au labo du commissariat.' end
    local cid = Bridge:GetIdentifier(src)
    for _, s in pairs(Evidence.seals) do -- analyses terminées
        if s.status == 'analyzing' and now() >= s.readyAt then s.status, s.result = 'done', Evidence.analyze(s) end
    end
    if action == 'analyze' then
        local s = Evidence.seals[tonumber(id)]
        if not s or s.status ~= 'sealed' then return false, 'Scellé introuvable.' end
        if not Bridge:RemoveItem(src, Config.Items.bag, 1, { seal = s.id }) then return false, 'Il faut avoir le scellé sur toi.' end
        s.status, s.readyAt = 'analyzing', now() + Config.Lab.seconds
        return true, ('Scellé n°%d en analyse (%d min).'):format(s.id, math.ceil(Config.Lab.seconds / 60))
    end
    local mine, others = {}, {}
    for _, s in pairs(Evidence.seals) do
        if s.status == 'sealed' and s.by == cid then mine[#mine + 1] = view(s)
        elseif s.status ~= 'sealed' then others[#others + 1] = view(s) end
    end
    table.sort(mine, function(a, b) return a.id < b.id end)
    table.sort(others, function(a, b) return a.id > b.id end)
    for i = Config.Lab.history + 1, #others do others[i] = nil end
    return true, { mine = mine, results = others }
end

lib.callback.register('gs_evidence:lab', function(src, action, id)
    if not Security:RateLimit(src, 'gs_evidence:lab', 6, 5000) then return false, 'Doucement.' end
    return Evidence.lab(src, action, id)
end)

--- Fichage (arrestation) : empreintes et ADN enregistrés au nom de la personne
function Evidence.file(cid, name)
    if not cid then return false end
    Store.file(cid, name or cid)
    return true
end

CreateThread(function()
    Store.init()
    while true do Wait(60000) Evidence.decay() end
end)

exports('Touch', Evidence.touch)
exports('File', function(src) return Evidence.file(Bridge:GetIdentifier(src), Bridge:GetName(src)) end)
exports('IsFiled', function(cid) return Store.filed(cid) ~= nil end)

-- V10.1 · Preuves recevables : texte d'une pièce pour le tribunal (scellé analysé ou photo développée)
exports('CourtPiece', function(kind, ref)
    if kind == 'seal' then
        local s = Evidence.seals[tonumber(ref) or -1]
        if s and s.status == 'analyzing' and now() >= (s.readyAt or 0) then s.status, s.result = 'done', Evidence.analyze(s) end
        if not s or s.status ~= 'done' then return nil end
        return ('Scellé n°%d · %s (%s) : %s'):format(s.id, Config.Kinds[s.kind].label, s.date, s.result)
    elseif kind == 'photo' then
        local r = Photo and Photo.get(ref)
        if not r then return nil end
        return ('%s · %s'):format(r.label or 'Photo', r.text or '')
    end
end)
