-- Tests gs_vie (V12.57) : poubelles (délais par benne et par joueur, plafond horaire, butin, portée), passagers bavards
-- (vraie rumeur ou phrase de secours), porter / otage (accord, sans accord si menotté ou à terre, arme, distance,
-- qui peut lâcher, départ d'un joueur), résumé de la mesure de charge.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local cuffedSet = {}
provide('gs_police', { IsCuffed = function(src) return cuffedSet[src] == true end })
local rumor
provide('gs_rumors', { Random = function() return rumor end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_vie', { R .. 'gs_vie/shared/config.lua', R .. 'gs_vie/server/main.lua', R .. 'gs_vie/server/carry.lua', R .. 'gs_vie/server/perf.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local D = Config.Dumpster

-- Poubelles ------------------------------------------------------------------------------------------------------
local bin = vec3(100.0, 200.0, 30.0)
join(1, 'CID1', 'Fouineur', vec3(101.0, 200.0, 30.0))
check('benne trop loin refusée', not Vie.search(1, vec3(500.0, 500.0, 30.0)))
check('coordonnées invalides refusées', not Vie.search(1, 'x') and not Vie.search(1, { x = 'a' }))
fixRandom(0.99) -- dernier objet de la table (cigarettes)
local ok, msg, item, n = Vie.search(1, bin)
check('fouille : objet trouvé et donné', ok and item == 'gs_cigarettes' and n == 1 and W.players[1].items.gs_cigarettes == 1)
local bin2 = vec3(103.0, 200.0, 30.0)
ok = Vie.search(1, bin2)
check('autre benne trop tôt : délai joueur', not ok)
advance((D.playerCooldown + 1) * 1000)
ok, msg = Vie.search(1, bin)
check('même benne : vide pour un moment', not ok and msg:find('vide'))
advance((D.playerCooldown + 1) * 1000)
fixRandom(0.0)
ok, msg, item = Vie.search(1, bin2)
check('rien trouvé (cas le plus fréquent)', ok and item == nil and msg:find('ordures'))
advance(D.cooldown * 60000 + 1000)
fixRandom(0.5)
ok = Vie.search(1, bin)
check('benne de nouveau pleine après son délai', ok)
-- plafond horaire
Vie.searches[1] = {}
for i = 1, D.perHour do Vie.searches[1][i] = os.time() - 100 end
ok, msg = Vie.search(1, vec3(102.0, 201.0, 30.0))
check('plafond par heure', not ok and msg:find('heure'))
Vie.searches[1] = {}
W.players[1].full = true
advance(D.cooldown * 60000 + 1000)
fixRandom(0.99)
ok, msg = Vie.search(1, bin)
check('poches pleines : rien donné', ok and msg:find('pleines'))
W.players[1].full = nil
fixRandom()
-- tirage : chaque objet existe, « rien » possible
local seen = {}
for i = 1, 2000 do local it = Vie.roll() seen[it or 'rien'] = true end
check('tirage : rien et ferraille possibles', seen.rien and seen.scrapmetal)

-- Passagers bavards ------------------------------------------------------------------------------------------------
rumor = 'Paraît que ça a tiré, du côté de Grove Street.'
fixRandom(0.1)
check('passager : vraie rumeur de la ville', Vie.rumor() == rumor)
rumor = nil
local r = Vie.rumor()
local inFallback = false
for _, f in ipairs(Config.Passengers.fallback) do if f == r then inFallback = true end end
check('passager : phrase de secours sans rumeur', inFallback)
fixRandom()

-- Porter / otage ---------------------------------------------------------------------------------------------------
for _, w in ipairs(Config.Carry.hostageWeapons) do assert(joaat(w) ~= joaat('WEAPON_UNARMED'), 'mock : collision ' .. w) end
join(2, 'CID2', 'Porteur', vec3(0.0, 0.0, 0.0))
join(3, 'CID3', 'Porté', vec3(1.0, 0.0, 0.0))
join(4, 'CID4', 'Loin', vec3(50.0, 0.0, 0.0))
ok = Carry.request(2, 4, 'carry')
check('trop loin refusé', not ok)
ok = Carry.request(2, 2, 'carry')
check('soi-même refusé', not ok)
ok = Carry.request(2, 3, 'voler')
check('action inconnue refusée', not ok)
ok, msg = Carry.request(2, 3, 'carry')
local ask = lastClientEvent('gs_vie:client:carryAsk', 3)
check('demande envoyée à l\'autre', ok and ask and ask.args[1] == 2 and ask.args[2] == 'carry' and not Carry.links[2])
check('deuxième demande en attente refusée', not Carry.request(4, 3, 'carry'))
check('réponse d\'un autre joueur ignorée', not Carry.answer(3, 4, true))
check('accord : porté', Carry.answer(3, 2, true) and Carry.links[2].role == 'carrier' and Carry.links[3].role == 'carried')
check('déjà occupé', not Carry.request(4, 3, 'carry'))
check('la personne portée (d\'accord) peut descendre', Carry.release(3) and not Carry.links[2] and not Carry.links[3])
-- refus
Carry.request(2, 3, 'carry')
check('refus : rien ne se passe', not Carry.answer(3, 2, false) and not Carry.links[2] and W.notes[2].msg:find('Refusé'))
-- délai dépassé
Carry.request(2, 3, 'carry')
advance((Config.Carry.askTimeout + 1) * 1000)
check('accord trop tard ignoré', not Carry.answer(3, 2, true) and not Carry.links[2])
-- otage : arme obligatoire
ok, msg = Carry.request(2, 3, 'hostage')
check('otage sans arme refusé', not ok and msg:find('arme'))
W.players[2].weapon = joaat('WEAPON_PISTOL')
-- menotté : sans accord, et ne peut pas se libérer
cuffedSet[3] = true
ok = Carry.request(2, 3, 'hostage')
check('menotté : pris sans accord', ok and Carry.links[3] and Carry.links[3].forced)
check('menotté : ne peut pas se libérer', not Carry.release(3) and Carry.links[3])
check('le preneur lâche', Carry.release(2) and not Carry.links[3])
cuffedSet[3] = nil
-- à terre : porté sans accord
W.players[3].downed = true
ok = Carry.request(2, 3, 'carry')
check('à terre : porté sans accord', ok and Carry.links[2] and Carry.links[2].forced)
check('porteur à terre ne peut pas porter', not Carry.request(3, 4, 'carry'))
-- départ d'un joueur : lien coupé des deux côtés
W.players[3].downed = nil
source = 3
TriggerEvent('playerDropped')
check('départ : lien coupé', not Carry.links[2] and not Carry.links[3] and lastClientEvent('gs_vie:client:carryStop', 2).args[1] == 'parti')
-- porteur qui tombe
Carry.start(2, 4, 'carry', false)
net('gs_vie:carryBroken', 4)
check('seul le porteur peut signaler sa chute', Carry.links[2] ~= nil)
net('gs_vie:carryBroken', 2)
check('porteur tombé : lâché', not Carry.links[2] and not Carry.links[4])

-- Mesure de charge -------------------------------------------------------------------------------------------------
local s = Perf.summary({ 0, 2, 4, 150, 1, 0, 3, 0, 2, 300 })
check('mesure : moyenne, pire, accrocs', math.abs(s.avg - 46.2) < 0.01 and s.max == 300 and s.spikes == 2 and s.p95 == 300)
check('mesure : vide', Perf.summary({}).n == 0)
check('mesure : ligne lisible', Perf.line(3, 12, s):find('12 joueur%(s%)') and Perf.line(3, 12, s):find('2 accroc'))
check('mesure : réservée au staff', W.commands.perfserveur ~= nil and (function() W.commands.perfserveur(2, {}) return not Perf.running end)())

-- V12.63 · EMS : nettoyer les plaies (secours en service, à portée, jamais soi-même)
do
    join(41, 'EMS41', 'Secouriste', vec3(900.0, 900.0, 30.0))
    join(42, 'PAT42', 'Patient', vec3(901.0, 900.0, 30.0))
    local okE = cb('gs_vie:emsClean', 41, 42)
    check('nettoyer les plaies : réservé aux secours en service', not okE)
    W.players[41].job = { name = Config.Gestures.emsJob, grade = 0, onduty = true }
    W.clientEvents = {}
    okE = cb('gs_vie:emsClean', 41, 42)
    check('nettoyer les plaies : le patient est nettoyé', okE and lastClientEvent('gs_vie:client:cleaned', 42))
    check('nettoyer les plaies : pas soi-même', not cb('gs_vie:emsClean', 41, 41))
    tp(42, vec3(950.0, 900.0, 30.0))
    check('nettoyer les plaies : à portée seulement', not cb('gs_vie:emsClean', 41, 42))
end
io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
