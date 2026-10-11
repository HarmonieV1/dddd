-- Tests gs_interiors : portes publiques, portes de métier, portes vers une map ajoutée (`requires`).
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local states = { gsa_mrpd_etendu = 'missing' }
function GetResourceState(res) return states[res] or 'started' end
function SetEntityCoords(ped, x, y, z) W.players[ped - 1000].pos = vec3(x, y, z) end
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
provide('gs_gangs', { GetGang = function() return nil end })
loadResource('gs_interiors', { R .. 'gs_interiors/shared/config.lua', R .. 'gs_interiors/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function door(id) for _, d in ipairs(Config.Doors) do if d.id == id then return d end end end
local function has(list, id) for _, x in ipairs(list) do if x == id then return true end end return false end

local d = door('mrpd_interro')
check('portes du sous-sol de Mission Row déclarées', d ~= nil and door('mrpd_briefing') ~= nil and door('mrpd_reserve') ~= nil)
local out = vec3(d.outside.x, d.outside.y, d.outside.z)
join(1, 'CID1', 'Agent Un', out, { name = 'police', grade = 1, onduty = true })
join(2, 'CID2', 'Civil Deux', out)

-- Map absente : fermé pour tout le monde (sinon arrivée sous la carte)
check('map absente : porte invisible pour la police', not has(cb('gs_interiors:allowed', 1), 'mrpd_interro'))
local ok, msg = cb('gs_interiors:use', 1, 'mrpd_interro', 'outside')
check('map absente : porte fermée', ok == false and msg:find('fermé') ~= nil)
check('map absente : le policier n\'a pas bougé', #(W.players[1].pos - out) < 0.01)
check('porte publique (casino) toujours visible', has(cb('gs_interiors:allowed', 2), 'casino'))

-- Map démarrée : police seulement
states.gsa_mrpd_etendu = 'started'
advance(11000)
check('map démarrée : porte visible pour la police', has(cb('gs_interiors:allowed', 1), 'mrpd_interro'))
check('map démarrée : invisible pour un civil', not has(cb('gs_interiors:allowed', 2), 'mrpd_interro'))
ok = cb('gs_interiors:use', 1, 'mrpd_interro', 'outside')
check('police : téléportée au sous-sol', ok == true and math.abs(W.players[1].pos.z - d.inside.z) < 0.01)
ok, msg = cb('gs_interiors:use', 2, 'mrpd_interro', 'outside')
check('civil : refusé', ok == false and msg:find('clé') ~= nil)
advance(11000)
ok = cb('gs_interiors:use', 1, 'mrpd_interro', 'inside')
check('police : ressort au commissariat', ok == true and #(W.players[1].pos - out) < 0.01)

-- Map arrêtée pendant que quelqu'un est en bas : la sortie reste possible (jamais bloqué sous la carte)
ok = cb('gs_interiors:use', 1, 'mrpd_interro', 'outside')
states.gsa_mrpd_etendu = 'stopped'
advance(11000)
ok = cb('gs_interiors:use', 1, 'mrpd_interro', 'inside')
check('map arrêtée : on peut toujours sortir', ok == true and #(W.players[1].pos - out) < 0.01)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
