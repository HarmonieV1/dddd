-- Tests gs_admin : niveaux, anti-abus staff, tickets, isolement persistant, sanctions publiques, économie staff.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'

-- Natifs et ressources simulés propres au panel
function SetEntityCoords(ped, x, y, z) W.players[ped - 1000].pos = vec3(x, y, z) end
function FreezeEntityPosition(ped, on) W.players[ped - 1000].frozen = on end
function DropPlayer(src, reason) W.players[src].kicked = reason end
function GetPlayerPing() return 42 end
function GetConvarInt(_, d) return d end
local heat, cleared = { [4] = 60 }, {}
provide('gs_jobs', {
    GetMemberships = function() return { police = 2 } end,
    GetOnDutyPlayers = function() return {} end,
    AdminAddContract = function(_, job) if job == 'police' then return true end return false, 'invalid' end,
    AdminRemoveContract = function() return true end,
    AdminSetActive = function(src, job, grade) if job == 'police' then W.players[src].job = { name = job, grade = grade } return true end return false, 'invalid' end,
    ListJobs = function() return { { name = 'police', label = 'LSPD', grades = { { grade = 0, label = 'Cadet' } } } } end,
})
provide('gs_wanted', { GetHeat = function(s) return heat[s] or 0 end, ClearHeat = function(s) heat[s] = nil cleared[s] = true end })
provide('gs_social', { GetHandle = function() return 'vice_lucia' end })
provide('gs_gangs', { GetGang = function(s) if s == 4 then return 'ballas', 1 end end,
    ListGangs = function() return { { name = 'ballas', label = 'Ballas' } } end,
    AdminCreateGang = function(name, label) if name == 'ballas' then return false, 'Ce gang existe déjà.' end if not label then return false, 'Nom affiché obligatoire.' end W.newGang = name return true end,
    SetStash = function(gang, c) if gang ~= 'ballas' then return false end W.gangStash = c return true end,
    AdminSetGarage = function(gang, c, paint) if gang ~= 'ballas' then return false, 'Gang inconnu.' end W.gangGarage = { c = c, paint = paint } return true end,
    AdminSetGang = function(src, gang, grade) if gang and gang ~= 'ballas' then return false, 'Gang inconnu.' end W.players[src].gang = gang and { name = gang, grade = grade } or false return true end })
provide('gs_duo', { GetPartner = function() return nil end, GetDuoLevel = function() return 0 end })
local weatherSet
provide('gs_weather', {
    GetWeather = function() return 'CLEAR' end, GetEvent = function() return nil end,
    SetWeather = function(t) if t == 'RAIN' then weatherSet = t return true end return false end,
    StartEvent = function(id) return id == 'storm' end, StopEvent = function() return true end,
    ListWeathers = function() return { 'CLEAR', 'RAIN' }, { { id = 'storm', label = 'Tempête' } } end,
})
local sanctions, staffLogs = {}, {}
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
provide('gs_security', {
    RateLimit = getExport('gs_security', 'RateLimit'),
    Sanitize = getExport('gs_security', 'Sanitize'),
    LogStaff = function(msg, channel) if channel == 'sanctions' then sanctions[#sanctions + 1] = msg else staffLogs[#staffLogs + 1] = msg end end,
})
loadResource('gs_admin', { R .. 'gs_admin/shared/config.lua' })
local jail, notes = {}, {}
Store = {
    init = function() end, log = function() end, recentLogs = function() return {} end,
    addNote = function(lic, kind, text) notes[#notes + 1] = { license = lic, kind = kind, text = text } end,
    notes = function(lic) local l = {} for _, n in ipairs(notes) do if n.license == lic then l[#l + 1] = n end end return l end,
    jailGet = function(lic) return jail[lic] end,
    jailSet = function(lic, untilTs, reason) jail[lic] = { until_ts = untilTs, reason = reason } end,
    jailClear = function(lic) jail[lic] = nil end,
}
loadResource('gs_admin', { R .. 'gs_admin/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end
local here = vec3(100.0, 100.0, 30.0)

-- 1 super-admin, 2 modo, 3 helper, 4 joueur, 5 modo (même niveau que 2)
join(1, 'CID1', 'Alpha Boss', here); W.players[1].aces = { ['gs.admin.superadmin'] = true }
join(2, 'CID2', 'Modo Un', here); W.players[2].aces = { ['gs.admin.mod'] = true }
join(3, 'CID3', 'Helper Trois', here); W.players[3].aces = { ['gs.admin.helper'] = true }
join(4, 'CID4', 'Vice Lucia', vec3(500.0, 500.0, 30.0))
join(5, 'CID5', 'Modo Deux', here); W.players[5].aces = { ['gs.admin.mod'] = true }
for s = 1, 5 do W.players[s].license = 'license:' .. s end

-- Niveaux --------------------------------------------------------------------------------------------
check('niveaux', Admin.level(1) == 4 and Admin.level(2) == 2 and Admin.level(3) == 1 and Admin.level(4) == 0)
check('joueur : panel refusé', cb('gs_admin:open', 4) == nil)
local data = cb('gs_admin:open', 3)
check('helper : panel ouvert, pas de journal', data and data.level == 1 and #data.logs == 0)
step()

local ok, msg = cb('gs_admin:action', 3, 'kick', 4, { reason = 'test' }); step()
check('helper ne peut pas expulser', not ok and msg == 'Niveau insuffisant.' and not W.players[4].kicked)
ok = cb('gs_admin:action', 2, 'givemoney', 4, { account = 'cash', amount = 100, reason = 'x' }); step()
check('modo ne peut pas donner d\'argent', not ok and W.players[4].money.cash == 0)
ok = cb('gs_admin:action', 4, 'goto', 1); step()
check('joueur ne peut rien faire', not ok)

-- Fiche : données selon le niveau -------------------------------------------------------------------------
local d = cb('gs_admin:dossier', 3, 4); step()
check('fiche helper : pas d\'argent ni licence', d and d.money == nil and d.license == nil and d.heat == 60)
d = cb('gs_admin:dossier', 2, 4); step()
check('fiche modo : licence + notes, pas d\'argent', d.license == 'license:4' and d.notes and d.money == nil)
d = cb('gs_admin:dossier', 1, 4); step()
check('fiche admin : argent', d.money ~= nil)
check('fiche : gang', d.gang == 'ballas (grade 1)')

-- Anti-abus : pas de sanction sur staff de niveau égal / supérieur ------------------------------------------
ok, msg = cb('gs_admin:action', 2, 'kick', 5, { reason = 'abus' }); step()
check('modo ne peut pas expulser un autre modo', not ok and not W.players[5].kicked)
ok = cb('gs_admin:action', 2, 'jail', 1, { minutes = 10, reason = 'x' }); step()
check('modo ne peut pas isoler un admin', not ok and not Admin.jailed[1])
ok = cb('gs_admin:action', 1, 'warn', 2, { reason = 'Rappel du règlement' }); step()
check('admin peut avertir un modo', ok)

-- Motifs obligatoires / montants bornés ------------------------------------------------------------------------
ok, msg = cb('gs_admin:action', 2, 'warn', 4, {}); step()
check('avertissement sans motif refusé', not ok and msg == 'Motif obligatoire.')
for _, bad in ipairs({ 0, -5, 1.5, 999999999 }) do
    ok = cb('gs_admin:action', 1, 'givemoney', 4, { account = 'cash', amount = bad, reason = 'x' }); step()
    check('montant invalide refusé : ' .. bad, not ok)
end
ok = cb('gs_admin:action', 1, 'givemoney', 4, { account = 'coffre', amount = 10, reason = 'x' }); step()
check('compte invalide refusé', not ok)
ok = cb('gs_admin:action', 1, 'givemoney', 4, { account = 'bank', amount = 500, reason = 'remboursement bug' }); step()
check('don d\'argent', ok and W.players[4].money.bank == 500)
ok = cb('gs_admin:action', 1, 'giveitem', 4, { item = 'introuvable', amount = 1, reason = 'x' }); step()
check('item inconnu refusé', not ok)
ok = cb('gs_admin:action', 1, 'giveitem', 4, { item = 'water', amount = 3, reason = 'test' }); step()
check('don d\'item', ok and W.players[4].items.water == 3)

-- Sanctions publiques ---------------------------------------------------------------------------------------------
sanctions = {}
ok = cb('gs_admin:action', 2, 'warn', 4, { reason = 'Conduite hors RP' }); step()
check('avertissement : note + publication', ok and #notes > 0 and #sanctions == 1 and sanctions[1]:find('Conduite hors RP'))
check('publication anonyme (staff absent)', not sanctions[1]:find('Modo'))
check('avertissement affiché au joueur', lastClientEvent('gs_admin:client:warn', 4) ~= nil)

-- Isolement ---------------------------------------------------------------------------------------------------------
ok, msg = cb('gs_admin:action', 2, 'jail', 4, { minutes = 9999, reason = 'x' }); step()
check('durée max', not ok)
ok = cb('gs_admin:action', 2, 'jail', 4, { minutes = 10, reason = 'Freekill' }); step()
check('isolé', ok and Admin.jailed[4] and #(W.players[4].pos - Config.Jail.coords) < 1)
check('isolement persisté (par licence)', jail['license:4'] ~= nil)
tp(4, vec3(0.0, 0.0, 0.0))
Admin.jailTick()
check('évasion : ramené en cellule', #(W.players[4].pos - Config.Jail.coords) < 1)
TriggerEvent('gs_bridge:server:playerUnloaded', 4)
join(4, 'CID4', 'Vice Lucia', vec3(0.0, 0.0, 0.0)); W.players[4].license = 'license:4'
TriggerEvent('gs_bridge:server:playerLoaded', 4)
check('déco/reco : toujours isolé', Admin.jailed[4] ~= nil and #(W.players[4].pos - Config.Jail.coords) < 1)
advance(11 * 60000)
Admin.jailTick()
check('libéré à l\'échéance', Admin.jailed[4] == nil and jail['license:4'] == nil and #(W.players[4].pos - Config.Jail.release) < 1)

-- Tickets ---------------------------------------------------------------------------------------------------------------
net('gs_admin:server:report', 4, '')
check('ticket vide refusé', next(Admin.tickets) == nil)
advance(Config.Report.cooldown + 1)
cb('gs_admin:toggleDuty', 3); step()
W.clientEvents = {}
net('gs_admin:server:report', 4, 'Je suis bloqué sous la map')
local id = next(Admin.tickets)
check('ticket créé', id ~= nil and Admin.tickets[id].message:find('bloqué'))
check('staff en service notifié', lastClientEvent('gs_admin:client:ticket', 3) ~= nil)
check('staff hors service non notifié', lastClientEvent('gs_admin:client:ticket', 2) == nil)
advance(Config.Report.cooldown + 1)
net('gs_admin:server:report', 4, 'encore')
check('un seul ticket ouvert par joueur', #cb('gs_admin:open', 3).tickets == 1)
step()
ok = cb('gs_admin:action', 3, 'ticket_claim', nil, { id = id }); step()
check('ticket pris', ok and Admin.tickets[id].status == 'claimed')
ok = cb('gs_admin:action', 2, 'ticket_claim', nil, { id = id }); step()
check('pas de double prise', not ok)
ok = cb('gs_admin:action', 3, 'ticket_goto', nil, { id = id }); step()
check('aller au ticket', ok and #(W.players[3].pos - W.players[4].pos) < 2)
ok = cb('gs_admin:action', 3, 'ticket_close', nil, { id = id }); step()
check('ticket clôturé', ok and Admin.tickets[id] == nil)

-- Actions diverses ----------------------------------------------------------------------------------------------------
ok = cb('gs_admin:action', 2, 'clearheat', 4); step()
check('recherche effacée', ok and cleared[4])
ok = cb('gs_admin:action', 2, 'freeze', 4); step()
check('figé', ok and W.players[4].frozen == true)
ok = cb('gs_admin:action', 2, 'freeze', 4); step()
check('défigé', ok and W.players[4].frozen == false)
ok = cb('gs_admin:action', 1, 'addjob', 4, { job = 'police', grade = 1 }); step()
check('contrat ajouté', ok)
ok = cb('gs_admin:action', 1, 'weather', nil, { type = 'RAIN', minutes = 20 }); step()
check('météo', ok and weatherSet == 'RAIN')
ok = cb('gs_admin:action', 1, 'announce', nil, { text = 'Redémarrage dans 10 min' }); step()
check('annonce à tous', ok and lastClientEvent('gs_admin:client:announce', -1) ~= nil)
ok = cb('gs_admin:action', 2, 'kick', 4, { reason = 'Insultes' }); step()
check('expulsion', ok and W.players[4].kicked:find('Insultes'))
ok = cb('gs_admin:action', 2, 'goto', 99); step()
check('cible hors ligne refusée', not ok)
ok = cb('gs_admin:action', 1, 'nimporte', 4); step()
check('action inconnue refusée', not ok)

-- Menu rapide (F11) : mode staff obligatoire, niveaux par pouvoir, métier/gang de test, véhicules, items fondateur --
join(6, 'CID6', 'Fondateur', here); W.players[6].aces = { ['gs.admin.founder'] = true }; W.players[6].license = 'license:6'
join(7, 'CID7', 'Testeur', here); W.players[7].license = 'license:7'
check('niveau fondateur', Admin.level(6) == 5)
check('menu rapide refusé au joueur', cb('gs_admin:quick', 7) == nil)
local q = cb('gs_admin:quick', 6); step()
check('menu rapide fondateur : jobs + gangs', q and q.level == 5 and q.ranks and #q.jobs == 1 and #q.gangs == 1 and not q.onDuty)
q = cb('gs_admin:quick', 3); step()
check('menu rapide helper : pas de jobs', q and #q.jobs == 0)
ok, msg = cb('gs_admin:action', 6, 'power', nil, { power = 'noclip' }); step()
check('pouvoir hors mode staff refusé', not ok and msg:find('mode staff'))
cb('gs_admin:toggleDuty', 6); step()
ok = cb('gs_admin:action', 6, 'power', nil, { power = 'noclip' }); step()
check('vol libre accordé en mode staff', ok)
ok = cb('gs_admin:action', 6, 'power', nil, { power = 'teleportall' }); step()
check('pouvoir inconnu refusé', not ok)
ok = cb('gs_admin:action', 6, 'power', nil, { power = 'animal', model = 'a_c_husky' }); step()
check('animal de la liste accordé', ok)
ok = cb('gs_admin:action', 6, 'power', nil, { power = 'animal', model = 'mp_m_freemode_01' }); step()
check('modèle hors liste refusé', not ok)
ok = cb('gs_admin:action', 3, 'power', nil, { power = 'noclip' }); step()
check('helper : pas de vol libre', not ok)
ok = cb('gs_admin:action', 3, 'power', nil, { power = 'names' }); step()
check('helper : noms des joueurs', ok)
ok = cb('gs_admin:action', 6, 'spectate', 7); step()
check('spectate : coords envoyées au staff seulement', ok and lastClientEvent('gs_admin:client:spectate', 6).args[1] == 7)
ok = cb('gs_admin:action', 6, 'spectate', 6); step()
check('pas de spectate sur soi', not ok)
ok = cb('gs_admin:action', 6, 'setjob', 6, { job = 'police', grade = 0 }); step()
check('se mettre un métier', ok and W.players[6].job.name == 'police')
ok = cb('gs_admin:action', 2, 'setjob', 2, { job = 'police', grade = 0 }); step()
check('modo : pas de métier de test', not ok)
ok = cb('gs_admin:action', 6, 'setgang', 7, { gang = 'ballas', grade = 3 }); step()
check('mettre un joueur dans un gang', ok and W.players[7].gang.name == 'ballas' and W.players[7].gang.grade == 3)
ok = cb('gs_admin:action', 6, 'setgang', 7, { gang = 'none' }); step()
check('retirer du gang', ok and W.players[7].gang == false)
ok = cb('gs_admin:action', 6, 'spawnveh', nil, { model = 'sultan', vtype = 'automobile' }); step()
local spawned
for id, e in pairs(W.entities) do if e.model == 'sultan' then spawned = id end end
check('véhicule staff créé, staff au volant', ok and spawned and W.entities[spawned].driver == 6)
ok = cb('gs_admin:action', 6, 'spawnveh', nil, { model = "sultan'; --", vtype = 'automobile' }); step()
check('modèle injecté refusé', not ok)
ok = cb('gs_admin:action', 6, 'spawnveh', nil, { model = 'sultan', vtype = 'fusee' }); step()
check('type inconnu refusé', not ok)
W.entities[spawned].pos = vec3(900.0, 0.0, 0.0)
ok = cb('gs_admin:action', 6, 'delveh', nil, { netId = spawned }); step()
check('suppression : trop loin', not ok and W.entities[spawned])
W.entities[spawned].pos = here
ok = cb('gs_admin:action', 6, 'delveh', nil, { netId = spawned }); step()
check('véhicule supprimé', ok and not W.entities[spawned])
ok = cb('gs_admin:action', 6, 'giveitem', 7, { item = 'water', amount = 5 }); step()
check('fondateur : don sans motif', ok and W.players[7].items.water == 5)
ok = cb('gs_admin:action', 1, 'giveitem', 7, { item = 'water', amount = 1 }); step()
check('super-admin : motif toujours obligatoire', not ok)
ok = cb('gs_admin:action', 6, 'removeitem', 7, { item = 'water', amount = 50 }); step()
check('retrait plafonné au stock', ok and W.players[7].items.water == 0)
ok = cb('gs_admin:action', 1, 'removeitem', 7, { item = 'water', amount = 1 }); step()
check('retrait réservé au fondateur', not ok)
ok = cb('gs_admin:action', 6, 'dropitem', nil, { item = 'sandwich', amount = 3 }); step()
check('dépôt au sol', ok and W.drops and W.drops[1].items[1][1] == 'sandwich')
check('liste des items : super-admin et fondateur', cb('gs_admin:items', 2) == nil and #cb('gs_admin:items', 6) == 1)

-- Admin (niveau 3) : plus d'argent ni d'items -------------------------------------------------------------------
join(8, 'CID8', 'Admin Simple', here); W.players[8].aces = { ['gs.admin.admin'] = true }; W.players[8].license = 'license:8'
step()
ok, msg = cb('gs_admin:action', 8, 'givemoney', 7, { account = 'cash', amount = 100, reason = 'x' }); step()
check('admin ne peut plus donner d\'argent', not ok and msg == 'Niveau insuffisant.')
ok = cb('gs_admin:action', 8, 'giveitem', 7, { item = 'water', amount = 1, reason = 'x' }); step()
check('admin ne peut plus donner d\'items', not ok)

-- Rangs : fondateur seul, jusqu'à super-admin, appliqués tout de suite (principals) et enregistrés ----------------
local cmds, ranks = {}, {}
function ExecuteCommand(c) cmds[#cmds + 1] = c end
Store.rankSet = function(lic, rank) ranks[lic] = rank end
ok, msg = cb('gs_admin:action', 1, 'setrank', 7, { rank = 2 }); step()
check('super-admin ne peut pas promouvoir', not ok and msg == 'Niveau insuffisant.')
ok = cb('gs_admin:action', 8, 'setrank', 7, { rank = 1 }); step()
check('admin ne peut pas promouvoir', not ok)
ok = cb('gs_admin:action', 6, 'setrank', 7, { rank = 5 }); step()
check('pas de fondateur créé en jeu', not ok)
ok = cb('gs_admin:action', 6, 'setrank', 6, { rank = 1 }); step()
check('pas de changement de son propre rang', not ok)
cmds = {}
ok = cb('gs_admin:action', 6, 'setrank', 7, { rank = 4 }); step()
check('fondateur promeut super-admin', ok and ranks['license:7'] == 4 and cmds[#cmds] == 'add_principal identifier.license:7 group.superadmin')
check('anciens groupes retirés avant', #cmds == 5 and cmds[1]:find('^remove_principal identifier.license:7'))
cmds = {}
ok = cb('gs_admin:action', 6, 'setrank', 7, { rank = 0 }); step()
check('fondateur rétrograde', ok and ranks['license:7'] == 0 and #cmds == 4)
W.players[7].aces = { ['gs.admin.founder'] = true }
ok = cb('gs_admin:action', 6, 'setrank', 7, { rank = 1 }); step()
check('un fondateur ne se rétrograde pas en jeu', not ok)
step()
ok = cb('gs_admin:action', 6, 'creategang', nil, { name = 'Aztecas', label = 'Varrios Los Aztecas', color = 3 }); step()
check('créer un gang (identifiant en minuscules)', ok and W.newGang == 'aztecas')
ok = cb('gs_admin:action', 6, 'creategang', nil, { name = 'ballas', label = 'Doublon', color = 3 }); step()
check('gang existant refusé', not ok)
ok = cb('gs_admin:action', 2, 'creategang', nil, { name = 'x', label = 'X', color = 3 }); step()
check('modo : pas de création de gang', not ok)
ok = cb('gs_admin:action', 6, 'gangplace', nil, { gang = 'ballas', kind = 'stash' }); step()
check('planque placée à la position du staff', ok and W.gangStash and W.gangStash.x == W.players[6].pos.x)
ok = cb('gs_admin:action', 6, 'gangplace', nil, { gang = 'ballas', kind = 'garage', paint = 145 }); step()
check('garage placé avec couleur', ok and W.gangGarage.paint == 145 and W.gangGarage.c.w == 90.0)
W.clientEvents = {}
cb('gs_admin:toggleDuty', 6); step()
check('fin du mode staff : pouvoirs coupés côté client', lastClientEvent('gs_admin:client:powersOff', 6) ~= nil)
ok = cb('gs_admin:action', 6, 'spawnveh', nil, { model = 'sultan', vtype = 'automobile' }); step()
check('hors mode staff : plus de véhicule', not ok)

-- Journal ---------------------------------------------------------------------------------------------------------------
check('journal alimenté', #Admin.logs > 5)

-- txAdmin : bans publiés -----------------------------------------------------------------------------------------------
sanctions = {}
TriggerEvent('txAdmin:events:playerBanned', { targetName = 'Tricheur', reason = 'Menu de triche', expiration = false })
check('ban txAdmin publié', #sanctions == 1 and sanctions[1]:find('Bannissement') and sanctions[1]:find('définitif'))

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
