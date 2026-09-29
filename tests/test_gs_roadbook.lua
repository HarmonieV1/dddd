-- Tests gs_roadbook : départ sur place, étapes dans l'ordre, vitesse crédible, photos (étape atteinte, sur place, une fois),
-- arrivée (XP, bonus photos et duo, titres), expiration.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local xp, partner = 0, {}
provide('gs_quests', { AddXP = function(_, n) xp = xp + n return 1 end })
provide('gs_duo', { GetPartner = function(src) return partner[src] end })
provide('gs_social', { GetHandle = function() return nil end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_roadbook', { R .. 'gs_roadbook/shared/config.lua' })
local rows = {}
Store = { init = function() end,
    done = function(cid) local o = {} for k, v in pairs(rows) do local c, r = k:match('^(.-)|(.*)$') if c == cid then o[r] = v end end return o end,
    finish = function(cid, route, _, s) local k = cid .. '|' .. route rows[k] = math.min(rows[k] or s, s) end,
    explorers = function() return {} end }
loadResource('gs_roadbook', { R .. 'gs_roadbook/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(6000) end
local S = Config.Routes.sunset.steps

join(1, 'CID1', 'Routard', vec3(0.0, 0.0, 0.0))
local ok, res = cb('gs_roadbook:start', 1, 'sunset'); step()
check('loin du départ', not ok)
tp(1, S[1].coords)
ok = cb('gs_roadbook:start', 1, 'nimporte'); step()
check('carnet inconnu', not ok)
ok = cb('gs_roadbook:start', 1, 'sunset'); step()
check('carnet commencé', ok and Roadbook.runs[1].step == 1)
ok = cb('gs_roadbook:photo', 1, 2); step()
check('photo d\'une étape pas encore atteinte', not ok)
tp(1, S[3].coords) advance(600000)
ok = cb('gs_roadbook:step', 1); step()
check('étape sautée : refusée', not ok and Roadbook.runs[1].step == 1)
tp(1, S[2].coords)
ok = cb('gs_roadbook:step', 1); step()
check('étape 2 validée', ok and Roadbook.runs[1].step == 2)
ok = cb('gs_roadbook:photo', 1, 2); step()
check('photo au spot', ok)
ok = cb('gs_roadbook:photo', 1, 2); step()
check('photo une seule fois', not ok)
ok = cb('gs_roadbook:photo', 1, 1); step()
check('pas de spot photo à l\'étape 1', not ok)
Roadbook.runs[1].lastAt = GetGameTimer()
tp(1, S[3].coords) advance(100)
ok, res = cb('gs_roadbook:step', 1)
check('trajet impossible : carnet annulé', not ok and Roadbook.runs[1] == nil)

-- Parcours complet, en duo
join(2, 'CID2', 'Duo', S[1].coords)
partner[1] = 2
tp(1, S[1].coords)
cb('gs_roadbook:start', 1, 'sunset'); step()
local done
for i = 2, #S do
    advance(600000) tp(1, S[i].coords) tp(2, S[i].coords)
    if S[i].photo and i < #S then end
    ok, res, done = cb('gs_roadbook:step', 1); step()
    if S[i].photo then cb('gs_roadbook:photo', 1, i); step() end
end
check('arrivée : XP avec bonus duo, titre « Routard »', done and done.duo and done.title == 'Routard' and xp == done.xp and done.xp == math.floor(Config.Routes.sunset.xp * Config.DuoBonus * (1 + done.photos * 0.1)))
check('photos comptées (spots atteints)', done.photos >= 1)
check('carnet enregistré', rows['CID1|sunset'] ~= nil)
local l = cb('gs_roadbook:list', 1)
check('liste : meilleur temps + titre', l and l.title == 'Routard')

-- Expiration
tp(1, S[1].coords)
cb('gs_roadbook:start', 1, 'sunset'); step()
Roadbook.runs[1].startedAt = os.time() - Config.MaxHours * 3600 - 5
tp(1, S[2].coords) advance(600000)
ok, res = cb('gs_roadbook:step', 1)
check('carnet expiré', not ok and res:find('expiré'))

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
