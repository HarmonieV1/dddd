-- Tests gs_city (Los Santos réactif) : quartier d'un point, tension qui monte avec les crimes signalés (gs_wanted),
-- niveaux publiés (GlobalState.gsCity), brèves Weazel, redescente avec le temps, exports lus par gs_wanted.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local news = {}
provide('gs_social', { Newsroom = function(kind, text) news[#news + 1] = { kind = kind, text = text } return true end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_city', { R .. 'gs_city/shared/config.lua', R .. 'gs_city/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local davis = vec3(100.0, -1750.0, 29.0)      -- South Los Santos
local ocean = vec3(-5000.0, -5000.0, 0.0)     -- hors de tout quartier

check('quartier trouvé', City.district(davis).id == 'south')
check('hors quartier', City.district(ocean) == nil)
check('calme au départ', getExport('gs_city', 'GetLevel')(davis) == 1)
check('facteur de signalement neutre', getExport('gs_city', 'ReportFactor')(davis) == 1.0)

join(1, 'CID1', 'Suspect', davis)
TriggerEvent('gs_wanted:server:reported', 1, 'robbery', 30, davis)
check('un braquage : encore calme', City.level(City.heat.south) == 1 and #news == 0)
TriggerEvent('gs_wanted:server:reported', 1, 'gunshot', 15, davis)
check('braquage + coups de feu : tendu', City.level(City.heat.south) == 2)
check('niveau publié', (GlobalState.gsCity or {}).south == 2)
check('brève « incidents »', #news == 1 and news[1].text:find('South Los Santos', 1, true) ~= nil)
TriggerEvent('gs_wanted:server:reported', 1, 'bank', 60, nil) -- sans coords : position du suspect
check('banque : chaud', City.level(City.heat.south) == 3 and GlobalState.gsCity.south == 3)
check('brève « sous tension »', #news == 2 and news[2].text:find('sous tension', 1, true) ~= nil)
check('témoins plus prompts', getExport('gs_city', 'ReportFactor')(davis) > 1.0)
check('police IA renforcée', getExport('gs_city', 'NpcBonus')(davis) == 1)
check('autre quartier non touché', getExport('gs_city', 'GetLevel')(vec3(300.0, 300.0, 100.0)) == 1)
City.add(davis, 1000)
check('tension plafonnée', City.heat.south == Config.MaxHeat)
TriggerEvent('gs_wanted:server:reported', 1, 'robbery', 30, ocean)
check('crime hors quartier ignoré', next(City.heat, nil) == 'south' and next(City.heat, 'south') == nil)

-- Redescente : ~2 / minute
local n = #news
for _ = 1, 40 do City.decay() end
check('redescendu à tendu', City.level(City.heat.south) == 2)
for _ = 1, 100 do City.decay() end
check('retour au calme', City.heat.south == nil and (GlobalState.gsCity or {}).south == nil)
check('brève « retour au calme »', news[#news].text:find('Retour au calme', 1, true) ~= nil and #news > n)

local st = cb('gs_city:status', 1)
check('/quartiers : tous les quartiers', type(st) == 'table' and #st == #Config.Districts)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
