-- Tests gsa_zz_fusion_occlusion/server.lua (V12.24) : la ressource de fusion écrit elle-même dans son dossier stream.
local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local H, saved, invoker = {}, {}, 'gs_admin'
GetCurrentResourceName = function() return 'gsa_zz_fusion_occlusion' end
GetInvokingResource = function() return invoker end
AddEventHandler = function(n, f) H[n] = f end
SaveResourceFile = function(res, rel, data, len) saved[#saved + 1] = { res = res, rel = rel, data = data:sub(1, len) }; return true end
dofile('server/resources/[gtasoon]/gsa_zz_fusion_occlusion/server.lua')
local function save(file, b64) local r, w; H['gsa_fusion:save'](file, b64, function(ok, why) r, w = ok, why end); return r, w end
check('écrit dans SON dossier stream', save('apa_ss1_occl_01.ymap', 'AAEC/w==') == true and saved[1].res == 'gsa_zz_fusion_occlusion'
    and saved[1].rel == 'stream/apa_ss1_occl_01.ymap' and saved[1].data == '\0\1\2\255')
check('chemin piégé refusé', save('../../server.cfg', 'AA==') == false and #saved == 1)
check('autre extension refusée', save('x.lua', 'AA==') == false)
invoker = 'autre_ressource'
check('seulement gs_admin', save('a_occl_01.ymap', 'AA==') == false and #saved == 1)
invoker = 'gs_admin'
SaveResourceFile = function() return false end
local ok, why = save('a_occl_01.ymap', 'AA==')
check('refus de SaveResourceFile expliqué', ok == false and why and why:find('stream'))
print(('ressource de fusion : %d réussis, %d échoués'):format(passed, failed))
if failed > 0 then os.exit(1) end
