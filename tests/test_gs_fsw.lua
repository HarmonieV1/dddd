-- Tests gs_admin/server/fsw.lua (V12.21) : écritures disque de maps.js, chargement sans « package », racine verrouillée.
local base = os.tmpname(); os.remove(base); os.execute('mkdir -p "' .. base .. '"')
local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local savedPackage, invoker = package, 'gs_admin'
package = nil -- FiveM peut ne pas fournir « package » : le fichier doit se charger quand même
local H = {}
GetCurrentResourceName = function() return 'gs_admin' end
GetInvokingResource = function() return invoker end
AddEventHandler = function(n, f) H[n] = f end
-- Ressources simulées + SaveResourceFile (écrit dans un dossier existant, ne crée pas de dossier, comme FiveM)
local RES = { gs_admin = base .. '/server-data/resources//[gtasoon]/gs_admin', gsa_zz_fusion_occlusion = base .. '/server-data/resources/[gtasoon]/gsa_zz_fusion_occlusion' }
local ORDER = { 'gs_admin', 'gsa_zz_fusion_occlusion' }
GetNumResources = function() return #ORDER end
GetResourceByFindIndex = function(i) return ORDER[i + 1] end
GetResourcePath = function(n) return RES[n or 'gs_admin'] end
local saved, rawOpen = {}, io.open
SaveResourceFile = function(res, rel, data, len)
    local f = rawOpen(RES[res] .. '/' .. rel, 'wb'); if not f then return false end
    f:write(data:sub(1, len)); f:close(); saved[#saved + 1] = res .. ':' .. rel; return true
end
os.execute('mkdir -p "' .. RES.gsa_zz_fusion_occlusion .. '/stream"')
local okLoad, err = pcall(dofile, 'server/resources/[gtasoon]/gs_admin/server/fsw.lua')
package = savedPackage
check('chargé sans package : ' .. tostring(err), okLoad and H['gs_admin:fsWrite'] and H['gs_admin:fsRemove'])
local function call(ev, ...)
    local r, w
    local a = table.pack(...)
    a[a.n + 1] = function(ok, why) r, w = ok, why end
    H[ev](table.unpack(a, 1, a.n + 1))
    return r, w
end
local target = base .. '/server-data/resources/[gtasoon]/gsa_zz_fusion_occlusion/stream/x_occl_01.ymap'
check('écrit (dossier créé)', call('gs_admin:fsWrite', target, 'AAEC/w==') == true)
local f = io.open(target, 'rb'); local data = f and f:read('a'); if f then f:close() end
check('octets binaires intacts', data == '\0\1\2\255')
check('écrit par SaveResourceFile (API FiveM)', saved[1] == 'gsa_zz_fusion_occlusion:stream/x_occl_01.ymap')
-- io.open bloqué (serveur du 12/10) : SaveResourceFile suffit
local realOpen = io.open
io.open = function(path, mode) if mode and mode:find('w') then return nil end return realOpen(path, mode) end
check('io.open bloqué : écrit quand même', call('gs_admin:fsWrite', target, 'AQID') == true)
io.open = realOpen
local f2 = io.open(target, 'rb'); local d2 = f2 and f2:read('a'); if f2 then f2:close() end
check('contenu réécrit', d2 == '\1\2\3')
check('hors du dossier serveur : refusé', call('gs_admin:fsWrite', '/etc/roadline_test', 'AA==') == false)
check('remontée « .. » : refusée', call('gs_admin:fsWrite', base .. '/server-data/../../x', 'AA==') == false)
invoker = 'autre_ressource'
check('autre ressource : refusée', call('gs_admin:fsWrite', target, 'AA==') == false)
invoker = 'gs_admin'
check('suppression', call('gs_admin:fsRemove', target) == true and io.open(target) == nil)
os.execute('rm -rf "' .. base .. '"')
print(('fsw (écritures des maps) : %d réussis, %d échoués'):format(passed, failed))
if failed > 0 then os.exit(1) end
