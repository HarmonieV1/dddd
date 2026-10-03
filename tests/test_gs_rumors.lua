-- Tests gs_rumors (V8) : rumeurs nées des signalements (jamais d'identité sauf visage connu), gratuite vague / payante
-- détaillée, quartiers, arrestations ; indic' (pas sur son gang, payant, activité des gangs, receleur, fuite).
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local gangOf = {}
provide('gs_gangs', { GetGang = function(src) return gangOf[src] end, ListGangs = function() return { { name = 'ballas', label = 'Ballas' }, { name = 'vagos', label = 'Vagos' } } end,
    FenceLocation = function() return vec3(-1200.0, -1450.0, 4.0) end })
provide('gs_wanted', { CrimeLabel = function(t) return t == 'store_robbery' and 'Braquage de supérette' or nil end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_rumors', { R .. 'gs_rumors/shared/config.lua', R .. 'gs_rumors/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end

join(1, 'CID1', 'Curieux', vec3(0.0, 0.0, 0.0))
check('rien à raconter', Rumors.free():find('Calme plat'))
check('quartiers : Grove Street', Rumors.zone(vec3(110.0, -1930.0, 20.0)) == 'Grove Street' and Rumors.zone(vec3(-140.0, 6340.0, 31.0)) == 'Paleto Bay')

TriggerEvent('gs_wanted:server:report', { label = 'Braquage de supérette', coords = vec3(110.0, -1930.0, 20.0), desc = { 'Homme', 'masqué', 'Voiture (bleu)' } })
check('rumeur trop fraîche : pas encore gratuite', Rumors.free():find('Calme plat'))
advance(Config.FreeMinAge * 60000 + 1000)
local f = Rumors.free()
check('gratuite : vague, avec le quartier', f:find('Grove Street') and f:find('grabuge') and not f:find('masqué'))
W.players[1].money.cash = 100
check('payante : refusée sans argent', not Rumors.paid(1))
W.players[1].money.cash = 1000
local ok, d = Rumors.paid(1)
check('payante : détails des témoins', ok and d[1]:find('masqué') and d[1]:find('Voiture %(bleu%)') and W.players[1].money.cash == 1000 - Config.Price)
TriggerEvent('gs_wanted:server:report', { label = 'Coups de feu', coords = vec3(1900.0, 3750.0, 32.0), desc = {}, named = 'Tony Star' })
ok, d = Rumors.paid(1)
check('visage connu : nommé dans la rumeur', d[1]:find('Tony Star') and d[1]:find('Sandy Shores'))
TriggerEvent('gs_police:server:jailed', 1)
ok, d = Rumors.paid(1)
check('arrestation : nom (public)', d[1]:find('Curieux') and d[1]:find('Bolingbroke'))
advance(Config.MaxAge * 60000 + 60000)
check('trop vieux : oublié', Rumors.paid(1) == false)

-- Indic'
local inf = Config.Informants[1].coords
join(2, 'CID2', 'Vago', vec3(inf.x, inf.y, inf.z)) gangOf[2] = 'vagos'
join(3, 'CID3', 'Balla', vec3(500.0, 500.0, 0.0)) gangOf[3] = 'ballas'
TriggerEvent('gs_gangs:server:activity', 'ballas', 'fence', vec3(20.0, -1700.0, 29.0), 12)
gangOf[4] = 'ballas' join(4, 'CID4', 'Balla2', vec3(0.0, 0.0, 0.0))
TriggerEvent('gs_wanted:server:crime', 4, 'store_robbery', vec3(-1200.0, -1450.0, 4.0))
check('indic : loin de lui, personne', not Rumors.indic(3, 'vagos'))
check('indic : pas sur son propre gang', not Rumors.indic(2, 'vagos'))
W.players[2].money.cash = 100
check('indic : en liquide', not Rumors.indic(2, 'ballas'))
W.players[2].money.cash = 5000
fixRandom(0.0) -- tuyau receleur + fuite
ok, d = Rumors.indic(2, 'ballas')
local all = table.concat(d, ' | ')
check('indic : livraison au receleur et coup des Ballas', ok and all:find('receleur %(12') and all:find('braquage de supérette') and all:find('Davis'))
check('indic : position du receleur', all:find('Leur receleur traîne du côté de Vespucci'))
check('l\'indic balance : les Ballas sont prévenus (gang de l\'acheteur)', W.notes[3] and W.notes[3].msg:find('Vagos'))
fixRandom(0.99)
W.notes[3] = nil
advance(11000)
ok, d = Rumors.indic(2, 'vagos' == 'x' and 'x' or 'ballas')
check('pas de fuite à chaque fois', ok and W.notes[3] == nil)
fixRandom()

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
