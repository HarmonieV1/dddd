-- Tests gs_gigs : offres (points éloignés, pas de doublon d'acceptation), étapes sur place, trajet crédible, paiement,
-- passeur (argent sale, signalement), abandon + délai, expiration.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
local crimes = 0
provide('gs_wanted', { ReportCrime = function() crimes = crimes + 1 return true end })
loadResource('gs_gigs', { R .. 'gs_gigs/shared/config.lua', R .. 'gs_gigs/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end
local P = Config.Points

join(1, 'CID1', 'Coursier', vec3(0.0, 0.0, 0.0))
local l = cb('gs_gigs:list', 1); step()
check('3 offres', #l.offers == Config.OffersPerRefresh and l.active == nil)
local far = true
for _, o in ipairs(Gigs.offers[1].list) do if #(P[o.from] - P[o.to]) < Config.MinDistance then far = false end end
check('A et B assez éloignés', far)
check('offres publiques : pas de coordonnées', l.offers[1].from == nil and l.offers[1].to == nil)

-- Forcer une livraison légale connue
Gigs.offers[1].list = { { id = 9, kind = 'courier', from = 1, to = 2, km = 1, pay = 300 } }
local ok, st = cb('gs_gigs:accept', 1, 8); step()
check('offre inconnue', not ok)
ok, st = cb('gs_gigs:accept', 1, 9); step()
check('accepté : étape 1 vers A', ok and st.stage == 1 and st.coords == P[1])
ok = cb('gs_gigs:accept', 1, 9); step()
check('un seul boulot à la fois', not ok)
ok = cb('gs_gigs:step', 1); step()
check('pas sur place', not ok)
tp(1, P[1])
ok, st = cb('gs_gigs:step', 1)
check('colis récupéré : étape 2 vers B', ok and st.stage == 2 and st.coords == P[2])
tp(1, P[2])
local done
ok, st, done = cb('gs_gigs:step', 1)
check('trajet impossible (téléportation) : refusé, boulot annulé', not ok and Gigs.active[1] == nil and W.players[1].money.cash == 0)

Gigs.offers[1].list = { { id = 10, kind = 'courier', from = 1, to = 2, km = 1, pay = 300 } }
tp(1, P[1])
cb('gs_gigs:accept', 1, 10); step()
cb('gs_gigs:step', 1); advance(120000)
tp(1, P[2])
ok, st, done = cb('gs_gigs:step', 1)
check('livré : payé en liquide', ok and done and W.players[1].money.cash == 300 and Gigs.active[1] == nil)
Gigs.offers[1].list = { { id = 11, kind = 'courier', from = 2, to = 1, km = 1, pay = 300 } }
ok = cb('gs_gigs:accept', 1, 11); step()
check('délai entre deux boulots', not ok)

-- Passeur : argent sale + signalement possible
join(2, 'CID2', 'Passeur', P[3])
cb('gs_gigs:list', 2); step()
Gigs.offers[2].list = { { id = 1, kind = 'smuggler', from = 3, to = 4, km = 1, pay = 900 } }
cb('gs_gigs:accept', 2, 1); step()
fixRandom(0.0)
cb('gs_gigs:step', 2); advance(120000)
fixRandom(nil)
check('passeur : signalé au chargement', crimes == 1)
tp(2, P[4])
ok = cb('gs_gigs:step', 2)
check('passeur : payé en argent sale', ok and W.players[2].items.black_money == 900)

-- Abandon, expiration
join(3, 'CID3', 'Lent', P[5])
cb('gs_gigs:list', 3); step()
Gigs.offers[3].list = { { id = 1, kind = 'courier', from = 5, to = 6, km = 1, pay = 100 }, { id = 2, kind = 'courier', from = 5, to = 6, km = 1, pay = 100 } }
cb('gs_gigs:accept', 3, 1); step()
ok = cb('gs_gigs:cancel', 3); step()
check('abandon', ok and Gigs.active[3] == nil and Gigs.cooldown[3] > os.time())
Gigs.cooldown[3] = 0
cb('gs_gigs:accept', 3, 2); step()
Gigs.active[3].startedAt = os.time() - Config.Timeout - 1
ok, st = cb('gs_gigs:step', 3); step()
check('trop tard : annulé', not ok and st:find('tard') and Gigs.active[3] == nil)

-- Contrats dynamiques
local calm = Gigs.roll(20, {})
local special = 0
for _, o in ipairs(calm) do if o.tag then special = special + 1 end end
check('ville calme : aucune offre spéciale', special == 0)
local stormy = Gigs.roll(20, { storm = true })
local ok2 = true
for _, o in ipairs(stormy) do
    if o.kind == 'courier' and not (o.tag and o.tag:find('urgence')) then ok2 = false end
end
check('tempête : livraisons d\'urgence', ok2)
local hot = Gigs.roll(30, { hot = 'grove', night = true })
local found
for _, o in ipairs(hot) do if o.kind == 'smuggler' then found = o end end
check('quartier chaud : passage risqué mieux payé et plus signalé', found and found.tag:find('risqué') and found.report > Config.Types.smuggler.reportChance)
local list = cb('gs_gigs:list', 4)
check('offres publiques : libellé spécial sans coordonnées', list == nil or (list.offers[1] and list.offers[1].from == nil))

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
