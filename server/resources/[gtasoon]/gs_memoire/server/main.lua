-- gs_memoire (serveur) · V12 « La mémoire des lieux ». Écoute les événements publics de la ville, les range par lieu,
-- publie les lieux chargés (GlobalState.gsMemoire : position, nombre, genre dominant, dernière phrase), pose une plaque
-- au 10e événement (gs_scars) et souffle un rappel à Radio Los Santos. Aucune identité de joueur n'est stockée.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Memoire = { places = {} } -- [cell] = { x, y, z, n, kinds = { [kind] = n }, last, lastKind, text, plaque }

local function started(r) return GetResourceState(r) == 'started' end
local function cellOf(c) return ('%d:%d'):format(math.floor(c.x / Config.Cell), math.floor(c.y / Config.Cell)) end

--- Genre dominant d'un lieu
local function topKind(p)
    local best, n = 'generic', 0
    for k, v in pairs(p.kinds) do if v > n then best, n = k, v end end
    return best
end

local function publish()
    local list = {}
    for cell, p in pairs(Memoire.places) do
        if p.n >= Config.MinEvents then
            list[#list + 1] = { id = cell, x = p.x, y = p.y, z = p.z, n = p.n, kind = topKind(p), text = p.text, last = p.last }
        end
    end
    table.sort(list, function(a, b) return a.n > b.n end)
    for i = #list, Config.MaxPlaces + 1, -1 do list[i] = nil end
    GlobalState.gsMemoire = list
    return list
end
Memoire.publish = publish

--- Un événement public s'ajoute au lieu. kind : crime, arrest, wedding, race, heist, war, plaque. text : phrase publique (facultative).
function Memoire.record(kind, coords, text, persist)
    if type(coords) ~= 'vector3' and type(coords) ~= 'vector4' and type(coords) ~= 'table' then return nil end
    if not coords.x or (math.abs(coords.x) < 1.0 and math.abs(coords.y) < 1.0) then return nil end
    kind = Config.Lines[kind] and kind or 'generic'
    local cell = cellOf(coords)
    local p = Memoire.places[cell]
    if not p then
        -- centre de la case (pas la position exacte d'un joueur)
        local cx = (math.floor(coords.x / Config.Cell) + 0.5) * Config.Cell
        local cy = (math.floor(coords.y / Config.Cell) + 0.5) * Config.Cell
        p = { x = cx, y = cy, z = coords.z + 0.0, n = 0, kinds = {}, last = 0 }
        Memoire.places[cell] = p
    end
    p.n = p.n + 1
    p.kinds[kind] = (p.kinds[kind] or 0) + 1
    p.last, p.lastKind = os.time(), kind
    text = Security:Sanitize(text or '', 120)
    if text and text ~= '' then p.text = text end
    if persist ~= false then Store.add({ cell = cell, x = p.x, y = p.y, z = p.z, kind = kind, text = text or '', at = p.last }) end
    -- 10e événement : la ville grave une plaque (une seule fois par lieu)
    if p.n == Config.PlaqueAt and not p.plaque and started('gs_scars') then
        p.plaque = true
        local okP = pcall(function()
            return exports.gs_scars:Plaque(vec3(p.x, p.y, p.z), ('Lieu de mémoire : %d fois la ville a tremblé ici'):format(p.n), 'memoire')
        end)
        if not okP then p.plaque = nil end
    end
    publish()
    return cell
end

-- Sources : les événements publics déjà émis par la ville ---------------------------------------------------------
local function pedCoords(src)
    local ped = src and GetPlayerPed(src) or 0
    if ped == 0 then return nil end
    return GetEntityCoords(ped)
end

AddEventHandler('gs_wanted:server:reported', function(_, crimeType, _, coords)
    local label = started('gs_wanted') and select(2, pcall(function() return exports.gs_wanted:CrimeLabel(crimeType) end)) or nil
    Memoire.record((crimeType == 'bank' or crimeType == 'jewelry' or crimeType == 'store') and 'heist' or 'crime', coords, type(label) == 'string' and ('Un ' .. label:lower() .. ' signalé ici.') or nil)
end)
AddEventHandler('gs_police:server:jailed', function(target) Memoire.record('arrest', pedCoords(target), 'Une arrestation devant tout le monde.') end)
AddEventHandler('gs_gangs:server:warWon', function(_, _, label, center) Memoire.record('war', center, ('Une guerre de territoire pour %s.'):format(label or 'ce quartier')) end)
AddEventHandler('gs_scars:server:plaque', function(text, coords) Memoire.record('plaque', coords, text) end)
-- V12 : événements ajoutés aux ressources concernées
AddEventHandler('gs_civil:server:married', function(coords, names) Memoire.record('wedding', coords, ('Le mariage de %s.'):format(names or 'deux citoyens')) end)
AddEventHandler('gs_races:server:won', function(name, circuit, coords) Memoire.record('race', coords, ('%s a gagné « %s ».'):format(name or 'Quelqu\'un', circuit or 'une course')) end)
AddEventHandler('gs_heists:server:done', function(label, coords) Memoire.record('heist', coords, ('Le braquage de %s.'):format(label or 'ce lieu')) end)

-- Radio Los Santos : un rappel de temps en temps -------------------------------------------------------------------
local function street(x, y)
    local ok, name = pcall(function() return GetStreetNameFromHashKey(GetStreetNameAtCoord(x, y, 30.0)) end)
    return ok and name and name ~= '' and name or 'un coin de la ville'
end

function Memoire.radio()
    if not started('gs_lsradio') then return false end
    local pool = {}
    for _, p in pairs(Memoire.places) do if p.n >= Config.Radio.minEvents then pool[#pool + 1] = p end end
    if #pool == 0 then return false end
    local p = pool[math.random(#pool)]
    local line = Config.RadioLines[math.random(#Config.RadioLines)]:format(street(p.x, p.y))
    pcall(function() exports.gs_lsradio:Say(line) end)
    return true
end

exports('Record', function(kind, coords, text) return Memoire.record(kind, coords, text) end)
exports('Places', function() return GlobalState.gsMemoire or {} end)

CreateThread(function()
    Store.init()
    for _, e in ipairs(Store.recent(Config.KeepDays)) do
        Memoire.record(e.kind, vec3(e.x, e.y, e.z), e.text, false)
    end
    -- les plaques déjà posées ne sont pas reposées au redémarrage
    for _, p in pairs(Memoire.places) do if p.n >= Config.PlaqueAt then p.plaque = true end end
    publish()
    while true do
        Wait(Config.Radio.every * 1000)
        Memoire.radio()
    end
end)
