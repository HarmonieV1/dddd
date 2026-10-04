-- Tests gs_justice · preuves recevables (V10.1) : verser une photo (quitte l'inventaire) ou un scellé analysé, au
-- tribunal, affaire ouverte, police / avocat seulement, pas de doublon ; le juge retient ou écarte ; compte des retenues.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local jstore = {}
json.encode = function(t) jstore[#jstore + 1] = t return 'J' .. #jstore end
json.decode = function(s) if s == '[]' then return {} end return jstore[tonumber(s:sub(2))] end
local duty = {}
provide('gs_jobs', { IsOnDutyAs = function(src, job) return duty[src] == job end, GetOnDutyPlayers = function() return {} end })
provide('gs_evidence', { CourtPiece = function(kind, ref)
    if kind == 'seal' then return ref == '7' and 'Scellé n°7 · Douille : Pistolet AB123' or nil end
    return ref == 'P1' and 'Photo · Vespucci · On y voit : Homme' or nil
end })
local cases = { [1] = { id = 1, status = 'open' }, [2] = { id = 2, status = 'closed' } }
Store = { get = function(id) return cases[id] end }
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_justice', { R .. 'gs_justice/shared/config.lua', R .. 'gs_justice/server/pieces.lua' })
local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end
local court = Config.Court
join(1, 'CID1', 'Agent', court) duty[1] = 'police'
join(2, 'CID2', 'Juge', court) duty[2] = 'judge'
join(3, 'CID3', 'Civil', court)
join(4, 'CID4', 'Avocat loin', vec3(court.x + 500.0, court.y, court.z)) duty[4] = 'lawyer'
local photo = Config.Pieces.photoItem
W.players[1].items[photo] = 1

local ok = cb('gs_justice:pieces', 3, 'deposit', 1, 'photo', 'P1'); step()
check('civil : refusé', not ok)
ok = cb('gs_justice:pieces', 4, 'deposit', 1, 'seal', '7'); step()
check('hors du tribunal : refusé', not ok)
ok = cb('gs_justice:pieces', 1, 'deposit', 2, 'seal', '7'); step()
check('affaire jugée : refusé', not ok)
ok = cb('gs_justice:pieces', 1, 'deposit', 1, 'seal', '8'); step()
check('scellé pas analysé : refusé', not ok)
ok = cb('gs_justice:pieces', 1, 'deposit', 1, 'photo', 'P1'); step()
check('photo versée : elle quitte l\'inventaire', ok and (W.players[1].items[photo] or 0) == 0)
ok = cb('gs_justice:pieces', 1, 'deposit', 1, 'seal', '7'); step()
check('scellé analysé versé', ok)
ok = cb('gs_justice:pieces', 1, 'deposit', 1, 'seal', '7'); step()
check('pas deux fois la même pièce', not ok)
local _, l = cb('gs_justice:pieces', 2, 'list', 1); step()
check('le juge voit les 2 pièces en attente', #l == 2 and l[1].status == 'pending')
ok = cb('gs_justice:pieces', 1, 'decide', 1, 1, true); step()
check('un policier ne tranche pas', not ok)
cb('gs_justice:pieces', 2, 'decide', 1, 1, true); step()
cb('gs_justice:pieces', 2, 'decide', 1, 2, false); step()
check('une retenue, une écartée', Pieces.retained(1) == 1)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
