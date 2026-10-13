-- Tests gs_markers (client, hors jeu) : fonction pure du placement libre (PlaceStep : pas de 10 cm / 5 cm / 5°, Maj × 5, repère
-- caméra, passage par 360), ancrage des PNJ (PedAnchor : derrière le point, ou position absolue posée par le staff), entrées
-- staff reprises par un point ou créées en ambiance (UnclaimedStaff), lecture de GlobalState.gsStaffPeds, StaffEntryOf.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
function GetInvokingResource() return 'test' end
loadResource('gs_markers', { R .. 'gs_markers/client/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function near(a, b) return math.abs(a - b) < 1e-6 end

-- Placement libre : fonction pure ---------------------------------------------------------------------------------------
local step = getExport('gs_markers', 'PlaceStep')
local p0 = { x = 100.0, y = 200.0, z = 30.0, heading = 90.0 }
local p = step(p0, { fwd = 1 }, 0.0)
check('avancer d\'un pas, caméra vers le nord : +10 cm en y, rien d\'autre', near(p.x, 100.0) and near(p.y, 200.1) and near(p.z, 30.0) and p.heading == 90.0)
p = step(p0, { fwd = 1 }, 90.0)
check('avancer, caméra tournée à 90° : -10 cm en x', near(p.x, 99.9) and near(p.y, 200.0))
p = step(p0, { fwd = 1 }, 180.0)
check('caméra vers le sud : avancer = -10 cm en y', near(p.y, 199.9) and near(p.x, 100.0))
p = step(p0, { right = 1 }, 0.0)
check('pas à droite, caméra vers le nord : +10 cm en x', near(p.x, 100.1) and near(p.y, 200.0))
p = step(p0, { fwd = -2, right = -1 }, 0.0)
check('reculer de deux pas et un pas à gauche', near(p.x, 99.9) and near(p.y, 199.8))
p = step(p0, { up = 1 }, 0.0)
check('hauteur : +5 cm', near(p.z, 30.05))
p = step(p0, { up = -3 }, 0.0)
check('hauteur : -15 cm', near(p.z, 29.85))
p = step(p0, { turn = 1 }, 0.0)
check('rotation : +5°', p.heading == 95.0)
p = step({ x = 0, y = 0, z = 0, heading = 358.0 }, { turn = 1 }, 0.0)
check('rotation : passage par 360', near(p.heading, 3.0))
p = step({ x = 0, y = 0, z = 0, heading = 2.0 }, { turn = -1 }, 0.0)
check('rotation négative : passage par 0', near(p.heading, 357.0))
p = step(p0, { fwd = 1, up = 1, turn = 1 }, 0.0, 5.0)
check('Maj : pas × 5 (50 cm, 25 cm, 25°)', near(p.y, 200.5) and near(p.z, 30.25) and p.heading == 115.0)
p = step(p0, { fwd = 0.5 }, 0.0)
check('touche maintenue : pas fractionnaire (5 cm)', near(p.y, 200.05))
p = step(p0, {}, 123.0)
check('aucune commande : pose inchangée', p.x == p0.x and p.y == p0.y and p.z == p0.z and p.heading == p0.heading)
check('la pose d\'entrée n\'est pas modifiée', p0.y == 200.0 and p0.heading == 90.0)

-- Ancrage des PNJ ----------------------------------------------------------------------------------------------------------
local anchor = getExport('gs_markers', 'PedAnchor')
local c = vec3(100.0, 100.0, 30.0)
local x, y, z, h, absolute = anchor({ model = 'a', heading = 0.0, distance = 1.2 }, c)
check('PNJ de config : 1,2 m derrière le point (cap 0 : au sud), z indicatif = point - 1, cap gardé, relatif',
    near(x, 100.0) and near(y, 98.8) and near(z, 29.0) and h == 0.0 and absolute == false)
x, y = anchor({ model = 'a', heading = 90.0, distance = 2.0 }, c)
check('cap 90 : 2 m à l\'est du point', near(x, 102.0) and near(y, 100.0))
x, y, z, h = anchor({ model = 'a' }, c)
check('sans cap ni distance : 1,2 m, cap 0', near(y, 98.8) and h == 0.0)
x, y, z, h, absolute = anchor({ model = 'a', heading = 0.0, at = { x = 441.5, y = -982.0, z = 29.7, heading = 180.0 } }, c)
check('PNJ posé par le staff : position et cap absolus, le point n\'intervient plus', x == 441.5 and y == -982.0 and z == 29.7 and h == 180.0 and absolute == true)

-- Entrées du staff : reprises par un point ou créées en ambiance ---------------------------------------------------------
local unclaimed = getExport('gs_markers', 'UnclaimedStaff')
local list = { { id = 1, kind = 'ped' }, { id = 2, kind = 'ped' }, { id = 3, kind = 'prop' } }
local free, claimed = unclaimed(list, { a = { ped = { staffId = 2 } }, b = { ped = { model = 'x' } }, c = {} })
check('entrée reprise par un point : pas recréée en ambiance ; les autres si', #free == 2 and free[1].id == 1 and free[2].id == 3 and claimed[2] == true and not claimed[1])
local add = getExport('gs_markers', 'Add')
check('Add : PNJ staff (position absolue, id repris) accepté sur un point', add('t:duty', { coords = vec3(441.0, -981.9, 30.69), style = 'hidden',
    ped = { model = 's_f_y_cop_01', at = { x = 441.5, y = -982.0, z = 29.7, heading = 180.0 }, staffId = 5 } }))
free, claimed = unclaimed({ { id = 5, kind = 'ped' }, { id = 6, kind = 'prop' } })
check('registre réel : l\'entrée 5 est reprise par le point, la 6 reste à créer ici', claimed[5] == true and #free == 1 and free[1].id == 6)
check('Add : champ ped invalide ignoré sans erreur', add('t:x', { coords = vec3(1.0, 2.0, 3.0), ped = 'pas une table' }))
check('Add : sans coords refusé', not add('t:y', { style = 'hidden' }))
local entryOf = getExport('gs_markers', 'StaffEntryOf')
check('entité inconnue : aucune entrée staff', entryOf(0) == nil and entryOf(12345) == nil and entryOf(nil) == nil)

check('GlobalState.gsStaffPeds suivi (changement d\'état global)', type(W.sbh.gsStaffPeds) == 'function')
W.sbh.gsStaffPeds(nil, nil, { { id = 5, kind = 'ped', model = 'a', x = 1, y = 2, z = 3, heading = 0 }, { id = 6, kind = 'prop', model = 'b', x = 1, y = 2, z = 3 },
    { id = 'x', model = 'c' }, 'rien' })
free = unclaimed()
check('liste du staff relue : entrées valides gardées (flottants), celle reprise par un point exclue de l\'ambiance',
    #free == 1 and free[1].id == 6 and free[1].kind == 'prop' and math.type(free[1].z) == 'float')
W.sbh.gsStaffPeds(nil, nil, nil)
check('liste vidée', #unclaimed() == 0)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
