-- Tests gs_evidence V10.1 « Chantage » : cible sur la photo, face à face, montant, payer (argent + photo remise),
-- refuser / pas de réponse (fuite presse + rumeur), photo à usage unique, déconnexion.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local jstore = {}
json.encode = function(t) jstore[#jstore + 1] = t return 'J' .. #jstore end
json.decode = function(s) if s == 'null' then return nil end if s == '[]' then return {} end return jstore[tonumber(s:sub(2))] end
local news, rumors = {}, {}
provide('gs_jobs', { IsOnDutyAs = function() return false end, GetOnDutyPlayers = function() return {} end })
provide('gs_wanted', { Describe = function(src) return 'Homme, veste rouge' end })
provide('gs_rumors', { Zone = function() return 'Vespucci' end, Add = function(t, d) rumors[#rumors + 1] = d end })
provide('gs_social', { Newsroom = function(kind, text) news[#news + 1] = text return true end })
local held = {} -- [src] = { [photoId] = true }
provide('ox_inventory', { GetItemCount = function(src, _, md) return (held[src] and held[src][md.photo]) and 1 or 0 end })
Store = { init = function() end, filed = function() return nil end }
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_evidence', { R .. 'gs_evidence/shared/config.lua', R .. 'gs_evidence/server/main.lua', R .. 'gs_evidence/server/photo.lua',
    R .. 'gs_evidence/server/blackmail.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end
local function photo(id, cids)
    local subjects = {}
    for _, c in ipairs(cids) do subjects[#subjects + 1] = { cid = c, desc = 'Homme' } end
    SetResourceKvp('gs_photo:' .. id, json.encode({ subjects = subjects, place = 'Vespucci', text = 'Homme, veste rouge', label = 'Photo · Vespucci' }))
end

join(1, 'CID1', 'Maître Chanteur', vec3(0.0, 0.0, 30.0))
join(2, 'CID2', 'Victime Riche', vec3(1.0, 0.0, 30.0)) W.players[2].money.cash = 10000
join(3, 'CID3', 'Passant', vec3(2.0, 0.0, 30.0))
join(4, 'CID4', 'Loin', vec3(500.0, 0.0, 30.0))
local B = Config.Blackmail

photo('P1', { 'CID2' }) held[1] = { P1 = true }
local ok, msg = cb('gs_evidence:blackmail', 1, 'start', 'P1', 3, 1000); step()
check('cible absente de la photo : refusé', not ok)
ok = cb('gs_evidence:blackmail', 1, 'start', 'P1', 2, B.min - 1); step()
check('montant trop bas : refusé', not ok)
ok = cb('gs_evidence:blackmail', 3, 'start', 'P1', 2, 1000); step()
check('sans la photo sur soi : refusé', not ok)
photo('P9', { 'CID4' }) held[1].P9 = true
ok = cb('gs_evidence:blackmail', 1, 'start', 'P9', 4, 1000); step()
check('trop loin : refusé', not ok)

ok = cb('gs_evidence:blackmail', 1, 'start', 'P1', 2, 3000); step()
check('chantage lancé, la cible voit la photo', ok and lastClientEvent('gs_evidence:client:blackmail', 2) ~= nil)
ok = cb('gs_evidence:blackmail', 1, 'start', 'P1', 2, 3000); step()
check('pas deux chantages en même temps sur la même cible', not ok)
local before1 = W.players[1].money.cash
ok = cb('gs_evidence:blackmail', 2, 'answer', true); step()
check('payé : argent transféré', ok and W.players[2].money.cash == 7000 and W.players[1].money.cash == before1 + 3000)
check('payé : la victime récupère la photo', (W.players[2].items[Config.Camera.photo] or 0) == 1)
check('payé : pas de fuite', #news == 0)
held[1].P1 = true
ok = cb('gs_evidence:blackmail', 1, 'start', 'P1', 2, 1000); step()
check('photo déjà utilisée : refusée', not ok)

-- Refus : fuite
photo('P2', { 'CID2', 'CID3' }) held[1].P2 = true
cb('gs_evidence:blackmail', 1, 'start', 'P2', 3, 500); step()
ok = cb('gs_evidence:blackmail', 3, 'answer', false); step()
check('refus : la photo fuite (presse + rumeur)', ok and #news == 1 and #rumors == 1 and news[1]:find('veste rouge', 1, true))

-- Pas de réponse : fuite au bout du délai
photo('P3', { 'CID2' }) held[1].P3 = true
cb('gs_evidence:blackmail', 1, 'start', 'P3', 2, 500); step()
os.time = (function(t) return function() return t() + B.answerSeconds + 5 end end)(os.time)
Blackmail.tick()
check('sans réponse : fuite', #news == 2 and Blackmail.pending[2] == nil)

-- Pas les moyens : fuite
photo('P4', { 'CID3' }) held[1].P4 = true
W.players[3].money.cash, W.players[3].money.bank = 0, 0
cb('gs_evidence:blackmail', 1, 'start', 'P4', 3, 5000); step()
cb('gs_evidence:blackmail', 3, 'answer', true); step()
check('pas les moyens : la photo fuite quand même', #news == 3 and W.players[1].money.cash == before1 + 3000)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
