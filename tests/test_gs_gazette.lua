-- Tests gs_city · La Gazette du dimanche (V11.2) : compteurs de la semaine, une à la une logique, sections, publication
-- (Discord), une seule édition par semaine, remise à zéro.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local posts = {}
provide('gs_discord', { Announce = function(title, text) posts[#posts + 1] = { title = title, text = text } return true end })
SetResourceKvpInt = SetResourceKvpInt or function() end
GetResourceKvpInt = GetResourceKvpInt or function() return 0 end
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_city', { R .. 'gs_city/shared/config.lua', R .. 'gs_city/server/main.lua', R .. 'gs_city/server/gazette.lua' })
local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local south = Config.Districts[2]
local calm = Gazette.compose({ crimes = {}, faitsdivers = 0, rumeurs = {}, guilty = 0, acquitted = 0, juries = 0, legends = {}, plaques = {}, blackouts = {} }, 1)
check('semaine calme : une tranquille', calm.headline:find('tranquille', 1, true) ~= nil)
for _ = 1, 6 do TriggerEvent('gs_wanted:server:reported', 1, 'robbery', 30, vec3(south.center.x, south.center.y, 0.0)) end
TriggerEvent('gs_faitsdivers:server:new', 'Accident', 'Davis')
TriggerEvent('gs_justice:server:verdict', 'guilty'); TriggerEvent('gs_justice:server:verdict', 'acquitted')
TriggerEvent('gs_justice:server:jury', 1, 3, 5)
TriggerEvent('gs_scars:server:plaque', 'Ici, le casse de la banque', vec3(0.0, 0.0, 0.0))
TriggerEvent('gs_rumors:server:realized', 'un sac de billets caché au port')
local e = Gazette.compose(Gazette.week, 7)
check('à la une : le quartier le plus chaud', e.headline == south.label .. ' sous tension')
local text = Gazette.markdown(e)
check('faits divers comptés', text:find('6 incident', 1, true) ~= nil and text:find('1 fait', 1, true) ~= nil)
check('tribunal : verdicts et jury', text:find('1 condamnation', 1, true) ~= nil and text:find('1 jury', 1, true) ~= nil)
check('mémoire et rumeurs', text:find('casse de la banque', 1, true) ~= nil and text:find('sac de billets', 1, true) ~= nil)
TriggerEvent('gs_city:server:blackout', 'east', true)
check('black-out : à la une', Gazette.compose(Gazette.week, 8).headline:find('Nuit noire', 1, true) ~= nil)
TriggerEvent('gs_wanted:server:legend', 2, 'Le Fantôme')
check('légende : priorité absolue à la une', Gazette.compose(Gazette.week, 9).headline == 'Le Fantôme entre dans la légende')
local pub = Gazette.publish()
check('publiée sur Discord avec son numéro', posts[1] and posts[1].title:find('n°1', 1, true) ~= nil and pub.number == 1)
check('semaine remise à zéro', next(Gazette.week.crimes) == nil and #Gazette.week.legends == 0)
check('une seule édition par semaine', not Gazette.due())
-- V12.63 : poursuites et avis de recherche comptés ; édition en cours pour le site (jamais de nom)
check('semaine vide : pas d\'édition en cours', Gazette.draft() == nil)
TriggerEvent('gs_wanted:server:chase', 'Vespucci', 3)
TriggerEvent('gs_wanted:server:fugitive', 'Jean Dupont', 12000)
local d = Gazette.draft()
local dt = d and Gazette.markdown(d) or ''
check('poursuite : à la une de l\'édition en cours', d and d.draft and d.headline == 'Course-poursuite au-dessus de Vespucci')
check('poursuite et avis de recherche dans les faits divers', dt:find('1 poursuite', 1, true) ~= nil and dt:find('12000 $', 1, true) ~= nil)
check('édition en cours : aucun nom de joueur', not dt:find('Jean Dupont', 1, true))
io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
