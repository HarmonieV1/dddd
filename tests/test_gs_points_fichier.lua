-- Tests de gs_bridge/server/points_fichier.lua : les points déplacés (KVP) voyagent dans points-deplaces.json
-- (export automatique / forcé, import au démarrage une seule fois par marque, jamais de fichier vide créé).
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'

-- JSON minimal fidèle (le mock n'encode pas) : objets, tableaux, chaînes, nombres, booléens
local function enc(v)
    local t = type(v)
    if t == 'table' then
        if next(v) == nil then return '[]' end
        if #v > 0 then
            local out = {}
            for i, x in ipairs(v) do out[i] = enc(x) end
            return '[' .. table.concat(out, ',') .. ']'
        end
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys)
        local out = {}
        for i, k in ipairs(keys) do out[i] = ('"%s":%s'):format(k, enc(v[k])) end
        return '{' .. table.concat(out, ',') .. '}'
    elseif t == 'string' then return '"' .. v .. '"'
    elseif t == 'boolean' then return v and 'true' or 'false'
    else return tostring(v) end
end
local function dec(s)
    -- décodeur minimal pour les formes écrites par enc()
    local pos = 1
    local function ws() pos = s:find('%S', pos) or #s + 1 end
    local val
    local function str()
        local e = s:find('"', pos + 1, true); local r = s:sub(pos + 1, e - 1); pos = e + 1; return r
    end
    val = function()
        ws()
        local c = s:sub(pos, pos)
        if c == '{' then
            pos = pos + 1; local o = {}
            ws(); if s:sub(pos, pos) == '}' then pos = pos + 1; return o end
            while true do
                ws(); local k = str(); ws(); pos = pos + 1 -- ':'
                o[k] = val(); ws()
                local d = s:sub(pos, pos); pos = pos + 1
                if d == '}' then return o end
            end
        elseif c == '[' then
            pos = pos + 1; local a = {}
            ws(); if s:sub(pos, pos) == ']' then pos = pos + 1; return a end
            while true do
                a[#a + 1] = val(); ws()
                local d = s:sub(pos, pos); pos = pos + 1
                if d == ']' then return a end
            end
        elseif c == '"' then return str()
        elseif s:sub(pos, pos + 3) == 'true' then pos = pos + 4; return true
        elseif s:sub(pos, pos + 4) == 'false' then pos = pos + 5; return false
        else
            local e = s:find('[,%]}]', pos) or #s + 1
            local n = tonumber(s:sub(pos, e - 1)); pos = e; return n
        end
    end
    local ok, r = pcall(val)
    if not ok then error('json invalide') end
    return r
end
json = { encode = enc, decode = dec }

local kvp, files, printed = {}, {}, {}
function GetResourceKvpString(k) return kvp[k] end
function SetResourceKvp(k, v) kvp[k] = v end
function GetCurrentResourceName() return 'gs_bridge' end
function LoadResourceFile(res, name) return files[res .. '/' .. name] end
local saveOk = true
function SaveResourceFile(res, name, data) if not saveOk then return false end; files[res .. '/' .. name] = data; return true end
function IsDuplicityVersion() return true end
local realPrint = print
print = function(...) printed[#printed + 1] = table.concat({ ... }, ' ') end
local notified = {}
function TriggerClientEvent(ev, src, data) notified[#notified + 1] = { ev = ev, src = src, data = data } end
W.players[1] = { name = 'Fondateur', aces = { admin = true } }
W.players[2] = { name = 'Joueur', aces = {} }

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function load() dofile(R .. 'gs_bridge/server/points_fichier.lua') end
local FILE = 'gs_bridge/points-deplaces.json'

-- 1. Serveur neuf : rien en KVP, pas de fichier → aucun fichier créé, même forcé
load()
check('démarrage sans fichier : pas d\'import', #printed == 0)
check('auto sans point : pas de fichier', PointsFichier.export('auto') == false and files[FILE] == nil)
check('forcé sans point : pas de fichier', PointsFichier.export('console', true) == false and files[FILE] == nil)

-- 2. Le staff déplace deux points et en retire un (comme points.lua le fait) → export auto à la minute suivante
kvp.gs_points = enc({ ['gs_harvest:Config.Buyers.1.coords'] = { x = 1.5, y = 2.5, z = 3.5 }, ['gs_jobs:Config.Zone.center'] = { x = 10, y = 20, z = 30, w = 90 } })
kvp.gs_points_off = enc({ ['gs_rental:Config.Points.4.coords'] = true })
check('export auto après changement', PointsFichier.export('auto') == true and files[FILE] ~= nil)
local data = dec(files[FILE])
check('fichier : 2 points, 1 retiré, marque, auteur', data.points['gs_jobs:Config.Zone.center'].w == 90
    and data.off['gs_rental:Config.Points.4.coords'] == true and data.stamp ~= nil and data.par == 'auto')
check('marque mémorisée en KVP', kvp.gs_points_fichier == data.stamp)
check('rien de neuf : pas de réécriture', PointsFichier.export('auto') == false)
local before = files[FILE]
check('forcé : réécrit (nouvelle marque)', PointsFichier.export('console', true) == true and files[FILE] ~= before)

-- 3. Même serveur qui redémarre : son propre fichier n'est pas réimporté (marque identique)
printed = {}
load()
check('redémarrage : pas de réimport de son propre fichier', #printed == 0)
check('redémarrage : KVP intacts', kvp.gs_points:find('gs_jobs:Config.Zone.center', 1, true) ~= nil)

-- 4. Le VPS reçoit ce fichier avec [gtasoon] : KVP vides → import au démarrage, une seule fois
local fichier = files[FILE]
kvp = {}; files = { [FILE] = fichier }; printed = {}
load()
check('VPS : import au démarrage', #printed == 1 and printed[1]:find('2 point%(s%) déplacé%(s%) et 1 retiré') ~= nil)
check('VPS : KVP points écrits', dec(kvp.gs_points)['gs_harvest:Config.Buyers.1.coords'].z == 3.5)
check('VPS : KVP retirés écrits', dec(kvp.gs_points_off)['gs_rental:Config.Points.4.coords'] == true)
check('VPS : marque reprise', kvp.gs_points_fichier == dec(fichier).stamp)
check('VPS : rien à réexporter juste après l\'import', PointsFichier.export('auto') == false and files[FILE] == fichier)
printed = {}
load()
check('VPS redémarre : pas de second import', #printed == 0)

-- 5. Le VPS avait ses propres points et reçoit un fichier du PC : le PC est la référence
kvp = { gs_points = enc({ ['gs_x:Config.A'] = { x = 1, y = 1, z = 1 } }) }; files = { [FILE] = fichier }; printed = {}
load()
check('PC référence : points du VPS remplacés', dec(kvp.gs_points)['gs_x:Config.A'] == nil and dec(kvp.gs_points)['gs_jobs:Config.Zone.center'] ~= nil)

-- 6. Remise à zéro voulue sur le PC : le fichier existe déjà → il suit (vide), pour effacer aussi sur le VPS
kvp = { gs_points = enc({ ['gs_x:Config.A'] = { x = 1, y = 1, z = 1 } }), gs_points_off = '[]' }; files = {}; printed = {}
load()
check('PC : premier export', PointsFichier.export('auto') == true)
kvp.gs_points = '[]'
check('PC : remise à zéro exportée (fichier existant)', PointsFichier.export('auto') == true and next(dec(files[FILE]).points) == nil)

-- 7. Fichier abîmé ou sans marque : ignoré sans planter
kvp = {}; files = { [FILE] = '{pas du json' }; printed = {}
check('fichier abîmé : import ignoré', (pcall(load)) and #printed == 0 and kvp.gs_points == nil)
files = { [FILE] = enc({ points = { a = { x = 1, y = 1, z = 1 } } }) }
load()
check('fichier sans marque : ignoré', kvp.gs_points == nil)

-- 8. /pointsexport : console et staff ACE admin seulement
kvp = { gs_points = enc({ ['gs_x:Config.A'] = { x = 1, y = 1, z = 1 } }) }; files = {}; printed = {}; notified = {}
load()
W.commands.pointsexport(2)
check('/pointsexport joueur : refusé', files[FILE] == nil and #notified == 0)
W.commands.pointsexport(1)
check('/pointsexport staff : fichier écrit + notification', files[FILE] ~= nil and notified[1] and notified[1].data.type == 'success'
    and dec(files[FILE]).par == 'Fondateur')
files = {}; printed = {}
W.commands.pointsexport(0)
check('/pointsexport console : fichier écrit + ligne console', files[FILE] ~= nil and dec(files[FILE]).par == 'console' and #printed == 1)
saveOk = false; files = {}; notified = {}
W.commands.pointsexport(1)
check('écriture refusée : message, pas de marque changée', files[FILE] == nil and notified[1].data.type == 'inform')
saveOk = true

print = function(...) io.stdout:write(table.concat({ ... }, ' '), '\n') end
print(('test_gs_points_fichier : %d réussis, %d échoués'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
