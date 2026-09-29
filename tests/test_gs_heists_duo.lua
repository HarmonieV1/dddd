-- Tests gros coups en duo : partenaire, rôles, phases (pirate → conducteur → fuite), distance, durée réelle, alarme,
-- paiement 50/50, échec (à terre, trop long), cooldown.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local police, reports = { 8, 9, 10, 11 }, {}
provide('gs_jobs', {
    GetOnDutyPlayers = function() return police end,
    IsOnDutyAs = function(src) for _, p in ipairs(police) do if p == src then return true end end return false end,
})
local blinded = 0
provide('gs_wanted', { BlindCameras = function() blinded = blinded + 1 return 1 end, ReportCrime = function(src, crime, _, opts) reports[#reports + 1] = { src = src, crime = crime, alarm = opts and opts.alarm } return true end })
local partner = {}
provide('gs_duo', { GetPayBonus = function() return 1.0 end, GetPartner = function(src) return partner[src] end })
provide('gs_quests', { Reward = function() return 1 end })
provide('gs_weather', { GetGameTime = function() return 14, 0, 0 end, GetEvent = function() return nil end })
provide('gs_gangs', { GetGang = function() return nil end, GetTerritoryAt = function() return nil end, GetTerritoryOwner = function() return nil end, AddInfluence = function() return true end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
function GetPedInVehicleSeat(veh) return W.entities[veh] and W.entities[veh].driver and (1000 + W.entities[veh].driver) or 0 end
loadResource('gs_heists', { R .. 'gs_heists/shared/config.lua', R .. 'gs_heists/server/main.lua', R .. 'gs_heists/server/duo.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end
local S = Config.Big.fleeca_legion
local ARMED = 99
local function off(dx) return vec3(S.center.x + dx, S.center.y, S.center.z) end

join(1, 'CID1', 'Alpha', S.center) join(2, 'CID2', 'Bravo', S.center)
join(3, 'CID3', 'Solo', S.center)
for _, s in ipairs({ 1, 2, 3 }) do W.players[s].weapon = ARMED end
partner[1], partner[2] = 2, 1

local ok, msg = cb('gs_heists:bigStart', 3, 'fleeca_legion', 'hacker'); step()
check('sans partenaire : refusé', not ok)
ok = cb('gs_heists:bigStart', 1, 'fleeca_legion', 'boss'); step()
check('rôle inconnu', not ok)
ok = cb('gs_heists:bigStart', 1, 'inconnu', 'hacker'); step()
check('site inconnu', not ok)
police = { 8, 9 }
ok, msg = cb('gs_heists:bigStart', 1, 'fleeca_legion', 'hacker'); step()
check('pas assez de policiers', not ok and msg:find('policiers'))
police = { 8, 9, 10, 11 }
tp(2, vec3(5000.0, 0.0, 0.0))
ok = cb('gs_heists:bigStart', 1, 'fleeca_legion', 'hacker'); step()
check('partenaire absent du site', not ok)
tp(2, S.center)
W.players[1].weapon = nil
ok = cb('gs_heists:bigStart', 1, 'fleeca_legion', 'hacker'); step()
check('sans arme', not ok)
W.players[1].weapon = ARMED
ok = cb('gs_heists:bigStart', 1, 'fleeca_legion', 'hacker'); step()
check('coup lancé : rôles', ok and Big.sessions.fleeca_legion.hacker == 1 and Big.sessions.fleeca_legion.driver == 2)
ok = cb('gs_heists:bigStart', 2, 'fleeca_legion', 'driver'); step()
check('déjà dans un coup', not ok)

-- Phase 1 : pirate seulement, au terminal
ok = cb('gs_heists:bigBegin', 2); step()
check('le conducteur ne pirate pas', not ok)
tp(1, off(20.0))
ok = cb('gs_heists:bigBegin', 1); step()
check('pirate loin du terminal', not ok)
tp(1, S.terminal)
ok, msg = cb('gs_heists:bigBegin', 1)
check('piratage démarré', ok and msg == S.hackAction)
ok = cb('gs_heists:bigFinish', 1)
check('piratage trop court', not ok and Big.sessions.fleeca_legion.phase == 'hack')
cb('gs_heists:bigBegin', 1); advance(S.hackAction)
fixRandom(0.99)
ok = cb('gs_heists:bigFinish', 1); step()
fixRandom(nil)
check('piratage : alarme coupée, caméras aveuglées, phase coffres', blinded == 1 and ok and Big.sessions.fleeca_legion.phase == 'loot' and reports[#reports].alarm == false)

-- Phase 2 : conducteur, deux coffres
ok = cb('gs_heists:bigBegin', 1, 1); step()
check('le pirate ne vide pas les coffres', not ok)
tp(2, S.vault[1])
cb('gs_heists:bigBegin', 2, 1); advance(S.lootAction)
ok = cb('gs_heists:bigFinish', 2); step()
check('coffre 1 vidé', ok and Big.sessions.fleeca_legion.done[1] and Big.sessions.fleeca_legion.phase == 'loot')
ok = cb('gs_heists:bigBegin', 2, 1); step()
check('coffre déjà vidé', not ok)
tp(2, S.vault[2])
cb('gs_heists:bigBegin', 2, 2); advance(S.lootAction)
ok = cb('gs_heists:bigFinish', 2); step()
check('coffre 2 vidé : fuite', ok and Big.sessions.fleeca_legion.phase == 'escape')

-- Phase 3 : fuite
local veh = CreateVehicleServerSetter(0, 'automobile', 0, 0, 0)
W.entities[veh].driver = 2
W.players[2].vehicle = veh
tp(2, off(100.0)) tp(1, S.center)
Big.tick()
check('fuite : pas encore assez loin', Big.sessions.fleeca_legion ~= nil)
tp(2, off(S.escapeDistance + 50.0)) tp(1, S.center)
Big.tick()
check('fuite : pirate trop loin du conducteur', Big.sessions.fleeca_legion ~= nil)
tp(1, off(S.escapeDistance + 20.0))
fixRandom(0.0)
Big.tick()
fixRandom(nil)
check('fuite réussie : session close, cooldown', Big.sessions.fleeca_legion == nil and Big.cooldowns.fleeca_legion > os.time())
check('butin 50 / 50 en argent sale', (W.players[1].items.black_money or 0) == (W.players[2].items.black_money or -1) and W.players[1].items.black_money >= S.reward[1] // 2)

-- Cooldown
tp(1, S.center) tp(2, S.center)
ok, msg = cb('gs_heists:bigStart', 1, 'fleeca_legion', 'driver'); step()
check('cooldown après un coup', not ok and msg:find('surveillance'))
Big.cooldowns.fleeca_legion = nil

-- Échec : un des deux à terre
ok = cb('gs_heists:bigStart', 1, 'fleeca_legion', 'driver'); step()
check('nouveau coup', ok)
W.players[2].downed = true
Big.tick()
check('un des deux à terre : échec', Big.sessions.fleeca_legion == nil and (W.players[1].items.black_money or 0) > 0)
W.players[2].downed = nil
Big.cooldowns.fleeca_legion = nil

-- Échec : temps de fuite dépassé
cb('gs_heists:bigStart', 1, 'fleeca_legion', 'hacker'); step()
local sess = Big.sessions.fleeca_legion
sess.phase, sess.escapeAt = 'escape', os.time() - S.escapeTime - 5
Big.tick()
check('fuite trop lente : échec', Big.sessions.fleeca_legion == nil)

-- Cayo Perico : repérage obligatoire, pas de minimum de police, cible principale, gardes à l'alarme --------------
local C = Config.Big.cayo
police = {}
tp(1, C.start) tp(2, C.start)
ok, msg = cb('gs_heists:bigStart', 1, 'cayo', 'hacker'); step()
check('cayo : repérage exigé', not ok and msg:find('Repérage'))
ok = cb('gs_heists:scout', 1, 'cayo', 1); step()
check('repérage : trop loin', not ok)
for i, c in ipairs(C.scout) do tp(1, c) ok, msg = cb('gs_heists:scout', 1, 'cayo', i); step() end
check('repérage terminé', ok and msg:find('terminé') and Big.hasScouted(1, 'cayo'))
tp(1, C.start)
ok = cb('gs_heists:bigStart', 2, 'cayo', 'driver'); step()
local cs = Big.sessions.cayo
check('cayo lancé sans police (repérage du partenaire compte)', ok and cs and cs.primary and cs.primary.mult)
Big.scouted.CID1.cayo[1] = os.time() - C.scoutValid - 10
check('repérage périmé après 48 h', not Big.hasScouted(1, 'cayo'))
local counts = {}
for _ = 1, 400 do local p = Big.pickPrimary(C) counts[p.label] = (counts[p.label] or 0) + 1 end
check('panthère rare', (counts['Statue de la panthère'] or 0) < 60 and (counts['Diamant rose'] or 0) > 0)
C.hackFail = 1.0
tp(1, C.terminal)
cb('gs_heists:bigBegin', 1); advance(C.hackAction)
ok = cb('gs_heists:bigFinish', 1); step()
check('alarme cayo : gardes envoyés au pirate', ok and lastClientEvent('gs_heists:client:guards', 1).args[1] == 'cayo')

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
