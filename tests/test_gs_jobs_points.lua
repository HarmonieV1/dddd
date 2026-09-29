-- Tests gs_jobs : points de métier déplaçables (staff) et armurerie de service.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local saved = {}
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_jobs', {
    R .. 'gs_jobs/shared/locale.lua', R .. 'gs_jobs/shared/config.lua',
    R .. 'gs_jobs/shared/locations.lua', R .. 'gs_jobs/shared/jobs.lua',
    R .. 'gs_jobs/server/core.lua',
})
mockDB()
PointsStore = {
    init = function() end,
    all = function() return { { job = 'police', kind = 'duty', idx = 1, x = 1.0, y = 2.0, z = 3.0, w = 0.0 },
                              { job = 'police', kind = 'stash', idx = 9, x = 0.0, y = 0.0, z = 0.0, w = 0.0 } } end,
    save = function(job, kind, idx, c) saved[#saved + 1] = { job = job, kind = kind, idx = idx, c = c } end,
}
loadResource('gs_jobs', {
    R .. 'gs_jobs/server/members.lua', R .. 'gs_jobs/server/stash.lua', R .. 'gs_jobs/server/points.lua',
    R .. 'gs_jobs/server/admin.lua',
})
DB.init()

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end

-- Points chargés depuis la BDD
GSJ.loadPoints()
local P = Jobs.police.points
check('point BDD appliqué', P.duty[1].x == 1.0 and P.duty[1].y == 2.0)
check('point BDD inexistant ignoré', #GlobalState.gsJobPoints == 1)

-- Déplacement par le staff
local ok, err = GSJ.setPoint('police', 'armory', 1, vec4(10.0, 20.0, 30.0, 90.0))
check('armurerie déplacée + sauvegardée + publiée', ok and P.armory[1].x == 10.0 and saved[1].kind == 'armory' and #GlobalState.gsJobPoints == 2)
ok = GSJ.setPoint('police', 'garage_spawn', 1, vec4(5.0, 5.0, 5.0, 180.0))
check('sortie de garage : cap conservé', ok and P.garage[1].spawn.w == 180.0)
ok = GSJ.setPoint('police', 'armory', 1, vec4(11.0, 20.0, 30.0, 0.0))
check('re-déplacement : pas de doublon publié', ok and #GlobalState.gsJobPoints == 3)
check('métier inconnu', not GSJ.setPoint('pompier', 'duty', 1, vec4(0, 0, 0, 0)))
check('type inconnu', not GSJ.setPoint('police', 'toit', 1, vec4(0, 0, 0, 0)))
check('index inexistant', not GSJ.setPoint('police', 'duty', 7, vec4(0, 0, 0, 0)))
check('liste des points (menu staff)', #GSJ.listPoints('police') >= 6)
local jobs = exports.gs_jobs:ListJobs()
check('ListJobs expose les points', jobs[1].points ~= nil)

-- Armurerie
GSJ.checkArmories()
join(1, 'CID1', 'Agent', P.armory[1], { name = 'police', grade = 0, onduty = false })
GSJ.addMembership('CID1', 'police', 0, 'Agent')
W.players[1].job = { name = 'police', grade = 0, onduty = false }
ok, err = cb('gs_jobs:armory', 1, 'handcuffs'); step()
check('hors service : refusé', not ok)
W.players[1].job.onduty = true
tp(1, vec3(0.0, 0.0, 0.0))
ok = cb('gs_jobs:armory', 1, 'handcuffs'); step()
check('trop loin : refusé', not ok)
tp(1, P.armory[1])
ok = cb('gs_jobs:armory', 1, 'handcuffs'); step()
check('menottes : complété jusqu\'au max', ok and W.players[1].items.handcuffs == 2)
ok = cb('gs_jobs:armory', 1, 'handcuffs'); step()
check('déjà équipé', not ok and W.players[1].items.handcuffs == 2)
ok = cb('gs_jobs:armory', 1, 'WEAPON_PISTOL'); step()
check('arme : grade requis', not ok)
ok = cb('gs_jobs:armory', 1, 'repairkit'); step()
check('item hors liste du métier', not ok)
W.players[1].job.grade = 1
ok = cb('gs_jobs:armory', 1, 'ammo-9'); step()
check('munitions au bon grade', ok and W.players[1].items['ammo-9'] == 60)
check('audit armurerie', W.audit[#W.audit].action == 'armory')

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
