-- Tests V12.63 · Animalerie (gs_animalerie) : position de la map lue chez gs_admin (postes rangés autour tant qu'ils ne sont
-- pas placés), service obligatoire, distance au poste, carton de la réserve avant les gamelles, attente entre deux tâches,
-- client au comptoir seulement quand le serveur l'a annoncé, paie en banque, XP de métier limitée.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local duty, tracked = {}, 0
provide('gs_jobs', { IsOnDutyAs = function(src, job) return job == 'animalerie' and duty[src] == true end })
local maps = { maps = { { name = 'gsa_patoche_tacos_pack', places = { { x = 10.0, y = 10.0, z = 30.0 } } },
    { name = 'gsa_patoche_petshop_pack', places = { { x = 300.0, y = -1200.0, z = 29.5 } } } } }
provide('gs_admin', { MapScan = function() return maps end })
provide('gs_quests', { Track = function() tracked = tracked + 1 end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_animalerie', { R .. 'gs_animalerie/shared/config.lua', R .. 'gs_animalerie/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond) if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end end
local function step() advance(11000) end

-- Position de la map et postes
check('postes pas encore placés, map inconnue : rien', Config.PostAt('counter', nil) == nil)
local a = Petshop.findAnchor()
check('map de l\'animalerie trouvée chez gs_admin (pas une autre)', a and a.x == 300.0 and a.y == -1200.0)
GlobalState.gsPetshopAnchor = a
local counter = Config.PostAt('counter', a)
local stock, bowls = Config.PostAt('stock', a), Config.PostAt('bowls', a)
check('postes rangés autour de la map', counter and #(vec3(counter.x, counter.y, counter.z) - vec3(a.x, a.y, a.z)) < 0.01 and #(vec3(stock.x, stock.y, 0) - vec3(a.x, a.y, 0)) > 2.0)
Config.Posts.grooming.coords = vec4(310.0, -1195.0, 29.5, 90.0)
local g = Config.PostAt('grooming', a)
check('poste placé par le staff : sa position exacte', g.x == 310.0 and g.w == 90.0)
local around = Config.Around(vec4(0.0, 0.0, 0.0, 90.0), vec3(0.0, 1.0, 0.0))
check('repère du poste : « devant » suit son orientation', math.abs(around.x + 1.0) < 1e-6 and math.abs(around.y) < 1e-6)

local function at(p) return vec3(p.x, p.y, p.z) end
join(1, 'CID1', 'Soigneur', at(stock))
local ok, msg = cb('gs_animalerie:task', 1, 'stock'); step()
check('hors service : refusé', not ok and msg:find('service'))
duty[1] = true
tp(1, vec3(0.0, 0.0, 0.0))
ok, msg = cb('gs_animalerie:task', 1, 'stock'); step()
check('loin du poste : refusé', not ok and msg:find('Approche'))
tp(1, at(bowls))
ok, msg = cb('gs_animalerie:task', 1, 'bowls'); step()
check('gamelles : il faut le carton de la réserve', not ok and msg:find('carton'))
tp(1, at(stock))
ok = cb('gs_animalerie:task', 1, 'stock'); step()
check('réserve : carton pris, rien de payé', ok and (W.players[1].money.bank or 0) == 0)
tp(1, at(bowls))
ok, msg = cb('gs_animalerie:task', 1, 'bowls'); step()
local bank = W.players[1].money.bank
check('gamelles remplies : payé en banque, XP de métier', ok and bank >= Config.Tasks.bowls.pay[1] and bank <= Config.Tasks.bowls.pay[2] and tracked == 1)
tp(1, at(stock)) cb('gs_animalerie:task', 1, 'stock') step()
tp(1, at(bowls))
ok, msg = cb('gs_animalerie:task', 1, 'bowls'); step()
check('même tâche trop tôt : attente', not ok and msg:find('reviens'))
local cages = Config.PostAt('cages', a)
tp(1, at(cages))
ok = cb('gs_animalerie:task', 1, 'cages'); step()
check('cages nettoyées : payé, XP limitée (une fois par 10 min)', ok and W.players[1].money.bank > bank and tracked == 1)

-- Client au comptoir
tp(1, at(counter))
local st = cb('gs_animalerie:state', 1); step()
check('état : en service, client annoncé dans quelques minutes', st and st.duty and st.customerIn and st.customerIn > 0)
ok, msg = cb('gs_animalerie:task', 1, 'serve'); step()
check('pas de client : rien à servir', not ok and msg:find('client'))
Petshop.nextCustomer[1] = os.time() - 1
st = cb('gs_animalerie:state', 1); step()
check('client arrivé : le client l\'affiche', st and st.customerIn == 0)
bank = W.players[1].money.bank
ok, msg = cb('gs_animalerie:task', 1, 'serve'); step()
check('client servi : payé (+ pourboire possible), prochain client plus tard', ok and W.players[1].money.bank - bank >= Config.Tasks.serve.pay[1] and Petshop.nextCustomer[1] > os.time())
Petshop.nextCustomer[1] = os.time() - Config.Customers.wait - 5
st = cb('gs_animalerie:state', 1); step()
check('client parti s\'il a trop attendu : un autre viendra', st and st.customerIn > 0)

io.write(('animalerie : %d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
