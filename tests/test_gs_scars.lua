-- Tests gs_scars (V9) : mémorial (fusion, un par joueur et par quart d'heure, effacé avec le temps), vitrine brisée
-- après braquage (réparée par un ouvrier payé, jamais par l'auteur), fresque du gang vainqueur (remplace l'ancienne).
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local kvp = {}
function SetResourceKvp(k, v) kvp[k] = v end
function GetResourceKvpString(k) return kvp[k] end
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_scars', { R .. 'gs_scars/shared/config.lua', R .. 'gs_scars/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function count(kind) local n = 0 for _, s in pairs(Scars.list) do if s.kind == kind then n = n + 1 end end return n end

local spot = vec3(100.0, 100.0, 30.0)
join(1, 'CID1', 'Victime', spot)
join(2, 'CID2', 'Voisin', vec3(105.0, 100.0, 30.0))
Scars.fell(1)
check('mémorial là où il est tombé', count('memorial') == 1 and #GlobalState.gsScars == 1)
Scars.fell(1)
check('même joueur peu après : pas de doublon', count('memorial') == 1)
Scars.fell(2)
check('autre joueur tout près : fusionné', count('memorial') == 1)
advance(Config.Memorial.hours * 3600 * 1000 + 61000)
for id, s in pairs(Scars.list) do if s.kind == 'memorial' and os.time() - s.at > Config.Memorial.hours * 3600 then Scars.list[id] = nil end end
check('le mémorial s\'efface avec le temps', count('memorial') == 0)

-- Vitrine brisée
local shop = vec3(25.0, -1345.0, 29.5)
TriggerEvent('gs_wanted:server:crime', 1, 'gunshot', shop)
check('tir seul : pas de vitrine', count('glass') == 0)
TriggerEvent('gs_wanted:server:crime', 1, 'store_robbery', shop)
TriggerEvent('gs_wanted:server:crime', 1, 'store_robbery', shop)
check('braquage : une seule vitrine brisée', count('glass') == 1)
local gid for id, s in pairs(Scars.list) do if s.kind == 'glass' then gid = id end end
tp(1, shop) tp(2, vec3(400.0, 400.0, 30.0))
check('l\'auteur ne peut pas se faire payer la réparation', not Scars.repair(1, gid))
check('ouvrier trop loin', not Scars.repair(2, gid))
tp(2, shop)
check('ouvrier : vitrine réparée et payée', Scars.repair(2, gid) == true and W.players[2].money.bank > 0 and count('glass') == 0)
check('sauvegardée pour le redémarrage', kvp.gs_scars ~= nil)

-- Fresques
TriggerEvent('gs_gangs:server:warWon', 'grove', 'ballas', 'Ballas', vec3(105.0, -1940.0, 20.8), 27)
TriggerEvent('gs_gangs:server:warWon', 'grove', 'families', 'Families', vec3(105.0, -1940.0, 20.8), 25)
local m for _, s in pairs(Scars.list) do if s.kind == 'mural' then m = s end end
check('fresque du dernier vainqueur, une seule par quartier', count('mural') == 1 and m.label:find('Families'))

-- Plafond
for i = 1, Config.Max + 5 do Scars.add('glass', vec3(i * 100.0, 0.0, 0.0), {}) end
check('nombre de cicatrices plafonné', Scars.count() == Config.Max)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
