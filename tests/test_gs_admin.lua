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
    ListJobs = function() return { { name = 'police', label = 'LSPD', grades = { { grade = 0, label = 'Cadet' } },
        points = { { kind = 'duty', idx = 1, label = 'Prise de service' }, { kind = 'stash', idx = 1, label = 'Coffre' }, { kind = 'garage', idx = 1, label = 'Garage' } } } } end,
})
provide('gs_wanted', { GetHeat = function(s) return heat[s] or 0 end, ClearHeat = function(s) heat[s] = nil cleared[s] = true end })
provide('gs_social', { GetHandle = function() return 'vice_lucia' end, Newsroom = function() return true end })
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
local sanctions, staffLogs, allowedTp = {}, {}, {}
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
provide('gs_security', {
    RateLimit = getExport('gs_security', 'RateLimit'),
    Sanitize = getExport('gs_security', 'Sanitize'),
    LogStaff = function(msg, channel) if channel == 'sanctions' then sanctions[#sanctions + 1] = msg else staffLogs[#staffLogs + 1] = msg end end,
    AllowTeleport = function(src) allowedTp[src] = true end,
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
    vips = function() local l = {} for lic in pairs(W.vips or {}) do l[#l + 1] = { license = lic } end return l end,
    vipSet = function(lic, on) W.vips = W.vips or {} W.vips[lic] = on or nil end,
    -- V12.4 · bannissements RoadLine (posés en jeu, levés en jeu)
    ban = function(lic)
        local b = W.bans and W.bans[lic]
        if not b then return nil end
        if b.until_ts ~= 0 and b.until_ts <= os.time() then W.bans[lic] = nil return nil end
        return b
    end,
    banSet = function(lic, name, untilTs, reason, staff)
        W.bans = W.bans or {}
        W.bans[lic] = { name = name, until_ts = untilTs, reason = reason, staff = staff }
    end,
    banClear = function(lic)
        if not (W.bans and W.bans[lic]) then return false end
        W.bans[lic] = nil
        return true
    end,
    bans = function(search)
        local l = {}
        for lic, b in pairs(W.bans or {}) do
            if not search or search == '' or b.name:find(search, 1, true) then
                l[#l + 1] = { license = lic, name = b.name, until_ts = b.until_ts, reason = b.reason, staff = b.staff }
            end
        end
        return l
    end,
}
-- ACE par principal (V11.5 : nombre de personnages) : group.vip / super-admin posés par les tests
W.principals = {}
function IsPrincipalAceAllowed(principal, ace) return W.principals[principal] ~= nil and W.principals[principal][ace] == true end
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
ok = cb('gs_admin:action', 1, 'giveitem', 4, { item = 'ammo-9', amount = 20, reason = 'test' }); step()
check('V11.5 munitions (tiret) acceptées', ok and W.players[4].items['ammo-9'] == 20)
ok = cb('gs_admin:action', 1, 'giveitem', 4, { item = 'ammo 9', amount = 1, reason = 'test' }); step()
check('nom d\'item avec espace refusé', not ok)

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
-- V12.59 : n'importe quel ped HUMAIN du jeu par son nom ; rien d'autre (caractères, préfixes)
ok = cb('gs_admin:action', 6, 'power', nil, { power = 'animal', model = 'a_m_y_hipster_02' }); step()
check('ped humain du jeu par son nom : accordé', ok)
ok = cb('gs_admin:action', 6, 'power', nil, { power = 'animal', model = 'prop_bin_01a' }); step()
check('objet (pas un ped) : refusé', not ok)
ok = cb('gs_admin:action', 6, 'power', nil, { power = 'animal', model = 'a_m_y_../x' }); step()
check('nom de modèle bizarre : refusé', not ok)
check('chute lunaire retirée des événements généraux', Config.Events.moon == nil and Config.Powers.lowgravity ~= nil)
local ns = getExport('gs_admin', 'NightStats')(0)
check('V12.61 rapport staff : sanctions comptées par type, staff actif listé', type(ns) == 'table' and type(ns.sanctions) == 'table' and type(ns.staff) == 'table' and ns.tickets >= 0)
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

-- Événements en un clic
provide('gs_races', { SetFreeEntry = function(sec) W.freeRaces = sec return true end })
Admin.onDuty[8] = nil
ok = cb('gs_admin:action', 8, 'event', nil, { kind = 'boxing' }); step()
check('événement : mode staff requis', not ok)
Admin.onDuty[8] = os.time()
ok = cb('gs_admin:action', 8, 'event', nil, { kind = 'inconnu' }); step()
check('événement inconnu', not ok)
ok = cb('gs_admin:action', 8, 'event', nil, { kind = 'streetrace' }); step()
check('course de rue : annonce à tous + inscription gratuite', ok and lastClientEvent('gs_admin:client:eventStart', 4) and W.freeRaces == 1800)
ok = cb('gs_admin:action', 2, 'event', nil, { kind = 'boxing' }); step()
check('événement : modo refusé', not ok)

-- V11.5 : personnages (1 par défaut, 2 pour staff / VIP) et statut VIP donné par le fondateur
local slots = getExport('gs_admin', 'CharacterSlots')
check('joueur simple : valeur par défaut de qbx_core', slots('license2:aaa', 'license:4') == nil)
W.principals['identifier.license:4'] = { ['gs.admin.superadmin'] = true }
check('super-admin : 2 personnages', slots('license2:aaa', 'license:4') == 2)
W.principals['identifier.license:4'] = nil
ExecuteCommand = function(c) cmds[#cmds + 1] = c if c:find('add_principal identifier.license:7 group.vip') then W.principals['identifier.license:7'] = { ['gs.vip'] = true } end end
ok = cb('gs_admin:action', 1, 'setvip', 7, { on = true }); step()
check('VIP : réservé au fondateur', not ok)
ok = cb('gs_admin:action', 6, 'setvip', 7, { on = true }); step()
check('fondateur accorde le VIP : principal posé, 2 personnages', ok and W.vips['license:7'] and slots(nil, 'license:7') == 2)
ok = cb('gs_admin:action', 6, 'setvip', 7, { on = false }); step()
check('VIP retiré', ok and not W.vips['license:7'] and cmds[#cmds] == 'remove_principal identifier.license:7 group.vip')

-- V10.1 : modération à distance (bot Discord / panneau web)
local remote = getExport('gs_admin', 'RemoteAction')
local r = remote('players', nil, nil, 'Modo')
check('à distance : liste des joueurs', r.ok and r.text:find('42 ms', 1, true))
r = remote('freeze', 4, '', 'Modo')
check('à distance : geler', r.ok and W.players[4].frozen == true)
r = remote('unfreeze', 4, '', 'Modo')
check('à distance : dégeler', r.ok and W.players[4].frozen == false)
W.players[4].kicked = nil
r = remote('kick', 4, '', 'Modo')
check('à distance : motif obligatoire', not r.ok and not W.players[4].kicked)
r = remote('kick', 999, 'triche', 'Modo')
check('à distance : joueur inconnu', not r.ok)
r = remote('reboot', 4, 'x', 'Modo')
check('à distance : action inconnue refusée', not r.ok)
r = remote('kick', 4, 'triche', 'Modo')
check('à distance : expulser', r.ok and W.players[4].kicked and W.players[4].kicked:find('triche', 1, true))
-- V12.3 : isoler / libérer / réanimer depuis le bot et l'appli
join(9, 'CID9', 'Isolé Distance', here); W.players[9].license = 'license:9'; step()
r = remote('jail', 9, 'Freekill', 'Modo', 999)
check('à distance : isolement, durée bornée', not r.ok)
r = remote('jail', 9, 'Freekill', 'Modo', 20)
check('à distance : isolé 20 min', r.ok and Admin.jailed[9] and Admin.jailed[9].untilTs - os.time() <= 20 * 60)
r = remote('unjail', 9, '', 'Modo')
check('à distance : libéré', r.ok and Admin.jailed[9] == nil)
r = remote('unjail', 9, '', 'Modo')
check('à distance : pas en isolement', not r.ok)
r = remote('revive', 9, '', 'Modo')
check('à distance : réanimé', r.ok and W.players[9].revived)

-- V12.63 : appli staff externe (mot de passe collectif ou code personnel → jeton de session ; blocage après 5 essais ratés)
local handler
SetHttpHandler = function(fn) handler = fn end
local web_convars = { gs_admin_web = 'Alpha:code-tres-long-123,Court:abc', gs_admin_web_password = 'NRL-test!' }
GetConvar = function(k, d) if web_convars[k] ~= nil then return web_convars[k] end return d end
local realDecode = json.decode
json.decode = function(s) return load('return ' .. s)() end -- corps de test écrits en table Lua
local realRes = GetCurrentResourceName
local nTok = 0
GetCurrentResourceName = function() return 'gs_admin_webtest' end
provide('gs_admin_webtest', { RandomToken = function() nTok = nTok + 1 return ('tok%045d'):format(nTok) end, SafeEqual = function(a, b) return a == b end })
dofile(R .. 'gs_admin/server/web.lua')
GetCurrentResourceName = realRes
local Web = AdminWeb
local function call(ip, body) local out Web.handle(ip, body, function(r) out = r end) return out or {} end
local r1 = call('1.2.3.4', '{ action = "login", pseudo = "Modo", password = "NRL-test!" }')
check('web : mot de passe collectif → session au nom du pseudo', r1.ok and r1.who == 'Modo' and type(r1.token) == 'string' and #r1.token >= 32)
check('web : pseudo obligatoire avec le mot de passe collectif', not call('1.2.3.4', '{ action = "login", pseudo = "", password = "NRL-test!" }').ok)
local r2 = call('1.2.3.4', '{ action = "login", password = "code-tres-long-123" }')
check('web : code personnel accepté (nom du code)', r2.ok and r2.who == 'Alpha')
check('web : code trop court ignoré', not call('1.2.3.4', '{ action = "login", password = "abc" }').ok)
do -- V12.63 (backtest) : crypto.js pas chargé → secours /dev/urandom, jeton imprévisible quand même
    local saved = getExport('gs_admin_webtest', 'RandomToken')
    provide('gs_admin_webtest', { RandomToken = function() error('No such export') end, SafeEqual = function(a, b) return a == b end })
    local rs = call('1.2.3.5', '{ action = "login", pseudo = "Secours", password = "NRL-test!" }')
    check('web : sans crypto.js, jeton de secours (/dev/urandom, 48 hex)', rs.ok and type(rs.token) == 'string' and rs.token:match('^%x+$') and #rs.token == 48)
    provide('gs_admin_webtest', { RandomToken = saved, SafeEqual = function(a, b) return a == b end })
end
local tok = r1.token
check('web : action inconnue', not call('1.2.3.4', ('{ token = %q, action = "act", name = "givemoney", id = 9 }'):format(tok)).ok)
check('web : sans session = refusé', call('1.2.3.4', '{ token = "faux", action = "overview" }').auth == false)
for _ = 1, 5 do call('6.6.6.6', '{ action = "login", pseudo = "X", password = "mauvais" }') end
check('web : 5 essais ratés = bloqué même avec le bon mot de passe', not call('6.6.6.6', '{ action = "login", pseudo = "X", password = "NRL-test!" }').ok)
check('web : page servie', handler ~= nil)
local ov = call('1.2.3.4', ('{ token = %q, action = "overview" }'):format(tok))
check('web : vue d\'ensemble (joueurs avec position, tickets, serveur, courbe)', ov.ok and type(ov.data.players) == 'table' and type(ov.data.tickets) == 'table'
    and ov.data.server.version ~= nil and type(ov.data.history) == 'table' and (#ov.data.players == 0 or ov.data.players[1].x ~= nil))
local okA = call('1.2.3.4', ('{ token = %q, action = "act", name = "heal", id = 9 }'):format(tok))
check('web : soigner à distance, journalisé « Web · Modo »', okA.ok and Admin.logs[1].staff == 'Web · Modo' and Admin.logs[1].action == 'heal')
local okT = call('1.2.3.4', ('{ token = %q, action = "act", name = "tp", id = 9, extra = { place = 1 } }'):format(tok))
check('web : téléporter vers un lieu de la liste', okT.ok and okT.text:find(Config.Web.places[1].label, 1, true))
check('web : destination inconnue refusée', not call('1.2.3.4', ('{ token = %q, action = "act", name = "tp", id = 9, extra = { place = 99 } }'):format(tok)).ok)
check('web : dossier d\'un joueur', call('1.2.3.4', ('{ token = %q, action = "dossier", id = 9 }'):format(tok)).ok)
do -- V12.63 : écran (Lives hors jeu) : réponse immédiate, jamais de requête qui attend le joueur
    local peekState, requested = {}, 0
    provide('gs_lives', { Request = function() requested = requested + 1 end, Peek = function() return peekState end })
    local realState = GetResourceState
    GetResourceState = function(r) if r == 'gs_lives' then return 'started' end return realState(r) end
    local f1 = call('1.2.3.4', ('{ token = %q, action = "frame", id = 9 }'):format(tok))
    check('web : écran, première demande : « connexion » tout de suite + capture lancée', f1.wait == true and not f1.ok and requested == 1)
    peekState = { img = 'data:image/jpeg;base64,X', age = 300 }
    local f2 = call('1.2.3.4', ('{ token = %q, action = "frame", id = 9 }'):format(tok))
    check('web : écran, demande suivante : image', f2.ok and f2.img:find('base64'))
    peekState = { err = 'Capture impossible : test.' }
    local f3 = call('1.2.3.4', ('{ token = %q, action = "frame", id = 9 }'):format(tok))
    check('web : écran, échec : la raison est affichée', not f3.ok and f3.text:find('test', 1, true))
    GetResourceState = realState
end
local okL = call('1.2.3.4', ('{ token = %q, action = "logout" }'):format(tok))
check('web : déconnexion = jeton invalide', okL.ok and call('1.2.3.4', ('{ token = %q, action = "overview" }'):format(tok)).auth == false)
check('V12.63 : pas de sanction à distance sur un super-admin', not remote('kick', 1, 'test', 'Web · Modo').ok and GetPlayerName(1) ~= nil)
-- V12.63 (fondateur) · rangs dans l'appli : le fondateur agit sur tout le monde, les autres sur les rangs inférieurs
local function rem(action, id, text, lvl, extra) local ok, msg = Admin.remote(action, id, text, 'Web · Test', extra, lvl) return { ok = ok, text = msg } end
check('appli : fondateur (5) peut avertir un super-admin', rem('warn', 1, 'test rang', 5).ok)
check('appli : super-admin (4) ne sanctionne pas un super-admin', not rem('warn', 1, 'test rang', 4).ok)
check('appli : mot de passe collectif (modérateur) ne bannit pas', (function() local r = rem('ban', 9, 'triche', 2, 1) return not r.ok and r.text:find('rang') end)())
check('appli : admin (3) peut bannir un joueur', rem('ban', 9, 'triche', 3, 1).ok)
remote('unban', nil, W.players[9] and W.players[9].license or 'license:9', 'Web · Test')
web_convars.gs_admin_web = 'Alpha:code-tres-long-123,Fondateur:code-fondateur-99:5'
local rf = call('1.2.3.4', '{ action = "login", password = "code-fondateur-99" }')
check('appli : code personnel avec rang (fondateur)', rf.ok and rf.level == 5 and rf.text:find('Fondateur'))
local rm = call('1.2.3.4', '{ action = "login", pseudo = "Alpha", password = "NRL-test!" }')
check('appli : mot de passe collectif = modérateur, même en tapant « Alpha »', rm.ok and rm.level == Config.Web.collectiveLevel)
check('V12.63 : bannir à distance : durée hors limites refusée', not remote('ban', 9, 'triche', 'Web · Modo', 99999).ok)
check('V12.63 : bannir : durée non entière refusée (0,5 j ne devient pas définitif)', not remote('ban', 9, 'triche', 'Web · Modo', 0.5).ok)
local r3 = call('1.2.3.4', '{ action = "login", pseudo = "Modo", password = "NRL-test!" }')
web_convars.gs_admin_web_password = 'Nouveau-mdp-1'
check('V12.63 : mot de passe changé = anciennes sessions terminées', call('1.2.3.4', ('{ token = %q, action = "overview" }'):format(r3.token)).auth == false)
web_convars.gs_admin_web_https = '1'
local outD
Web.handle('8.8.8.8', '{ action = "login", pseudo = "Modo", password = "Nouveau-mdp-1" }', function(r) outD = r end, true)
check('V12.63 : adresse https active = connexion en clair (port direct) refusée', outD and not outD.ok)
local outH
Web.handle('8.8.8.8', '{ action = "login", pseudo = "Modo", password = "Nouveau-mdp-1" }', function(r) outH = r end, false)
check('V12.63 : par l\'adresse https (Caddy) : accepté', outH and outH.ok)
web_convars.gs_admin_web_https = nil
web_convars.gs_admin_web_password = 'court'
check('web : mot de passe collectif trop court = désactivé', not call('1.2.3.4', '{ action = "login", pseudo = "Modo", password = "court" }').ok)
json.decode = realDecode

-- V11 : redémarrage quotidien annoncé
dofile(R .. 'gs_admin/server/restart.lua')
check('redémarrage : annonce 15 min avant', Admin.restartWarning({ hour = 5, min = 45 }, '06:00') == 15)
check('redémarrage : annonce 1 min avant', Admin.restartWarning({ hour = 5, min = 59 }, '06:00') == 1)
check('redémarrage : passage de minuit', Admin.restartWarning({ hour = 23, min = 55 }, '00:00') == 5)
check('redémarrage : rien hors palier', Admin.restartWarning({ hour = 5, min = 50 }, '06:00') == nil)
check('redémarrage : off = rien', Admin.restartWarning({ hour = 5, min = 45 }, 'off') == nil)

-- V12.4 : bannissements RoadLine, posés ET levés depuis le jeu (super-admin uniquement) ---------------------------
local getBan = getExport('gs_admin', 'GetBan')
local autoBan = getExport('gs_admin', 'AutoBan')
W.bans = {}
sanctions = {}
ok, msg = cb('gs_admin:action', 2, 'ban', 9, { days = 0, reason = 'triche' }); step()
check('ban : modo refusé', not ok and msg == 'Niveau insuffisant.' and not W.bans['license:9'])
ok = cb('gs_admin:action', 1, 'ban', 9, { days = 0 }); step()
check('ban : motif obligatoire', not ok and not W.bans['license:9'])
for _, bad in ipairs({ -1, 1.5, 4000 }) do
    ok = cb('gs_admin:action', 1, 'ban', 9, { days = bad, reason = 'triche' }); step()
    check('ban : durée invalide refusée : ' .. bad, not ok and not W.bans['license:9'])
end
ok = cb('gs_admin:action', 1, 'ban', 7, { days = 0, reason = 'abus' }); step()
check('ban : pas de ban sur un staff de rang supérieur', not ok and not W.bans['license:7'])
ok = cb('gs_admin:action', 1, 'ban', 9, { days = 0, reason = 'Menu de triche' }); step()
check('ban définitif : enregistré par licence', ok and W.bans['license:9'] and W.bans['license:9'].until_ts == 0)
check('ban : joueur expulsé avec le motif', (W.players[9].kicked or ''):find('Menu de triche', 1, true))
check('ban : publié dans les sanctions', #sanctions == 1 and sanctions[1]:find('Bannissement') and sanctions[1]:find('définitif'))
check('ban : note au dossier', getBan('license:9') ~= nil and #Store.notes('license:9') > 0)

ok = cb('gs_admin:action', 2, 'unban', nil, { license = 'license:9' }); step()
check('deban : modo refusé', not ok and W.bans['license:9'])
ok = cb('gs_admin:action', 1, 'unban', nil, {}); step()
check('deban : licence obligatoire', not ok)
ok, msg = cb('gs_admin:action', 1, 'unban', nil, { license = 'license:inconnue' }); step()
check('deban : licence non bannie refusée', not ok and msg:find('pas banni'))
ok = cb('gs_admin:action', 1, 'unban', nil, { license = 'license:9' }); step()
check('deban en jeu : bannissement levé', ok and not W.bans['license:9'] and getBan('license:9') == nil)

-- Liste des bannis (lecture seule, F11) : super-admin uniquement
cb('gs_admin:action', 1, 'ban', 9, { days = 3, reason = 'Pot de miel' }); step()
check('ban temporaire : échéance calculée', W.bans['license:9'].until_ts > os.time())
check('liste des bannis : modo refusé', cb('gs_admin:bans', 2, '') == nil)
local list = cb('gs_admin:bans', 1, '')
check('liste des bannis : super-admin', type(list) == 'table' and #list == 1 and list[1].license == 'license:9')
check('liste des bannis : recherche par pseudo', #cb('gs_admin:bans', 1, 'Isolé') == 1 and #cb('gs_admin:bans', 1, 'Zorro') == 0)
check('V12.35 liste des bannis : date formatée par le serveur (pas de os.date côté client)', list[1] and type(list[1].when) == 'string' and (list[1].when == 'définitif' or list[1].when:find('jusqu', 1, true)))
advance(4 * 86400 * 1000)
check('peine écoulée : bannissement effacé tout seul', getBan('license:9') == nil and W.bans['license:9'] == nil)

-- Ban automatique (pots de miel de gs_security) : jamais sur un staff
staffLogs = {}
ok, msg = autoBan(2, 'Pot de miel déclenché', 0)
check('ban auto : staff signalé, pas banni', not ok and not W.bans['license:2'] and msg:find('Staff'))
check('ban auto : signalement au journal staff', #staffLogs > 0 and staffLogs[#staffLogs]:find('STAFF'))
ok = autoBan(999, 'Pot de miel déclenché', 0)
check('ban auto : joueur absent', not ok)
ok = autoBan(4, 'Pot de miel : event appât déclenché', 0)
check('ban auto : joueur banni définitivement et expulsé', ok and W.bans['license:4']
    and W.bans['license:4'].until_ts == 0 and (W.players[4].kicked or ''):find('triche', 1, true))

-- V12.37 · Placement libre des points (pose vérifiée) et PNJ / objets posés par le staff (super-admin et fondateur) ---------
function GetNumResources() return 0 end
vector3, vector4 = vec3, vec4 -- en jeu ces constructeurs existent ; le mock ne fournit que vec3 / vec4
function StopResource() end
function StartResource() end
local dbRows, dbNext = {}, 1
MySQL = {
    query = { await = function(sql) if sql:find('^SELECT') then return {} end return nil end },
    insert = { await = function(_, p) local id = dbNext dbNext = id + 1 dbRows[id] = p return id end },
    update = function(_, p) dbRows[p[1]] = nil end,
}
loadResource('gs_bridge', { R .. 'gs_bridge/server/points.lua' }) -- vrais exports (SetPoint, CleanPose, AddStaffPed…) ajoutés au gs_bridge simulé
StaffPeds.load()
function LoadResourceFile(res, path)
    local f = io.open(R .. res .. '/' .. path)
    if not f then return nil end
    local s = f:read('a') f:close() return s
end
cb('gs_admin:toggleDuty', 1); step()
local KEY = 'gs_harvest:Config.Buyers.1.coords'
ok, msg = cb('gs_admin:action', 2, 'movepoint', nil, { key = KEY, pose = { x = 100.0, y = 100.0, z = 30.0, heading = 0 } }); step()
check('placement libre : modo refusé', not ok and msg == 'Niveau insuffisant.')
ok, msg = cb('gs_admin:action', 1, 'movepoint', nil, { key = KEY, pose = { x = 103.0, y = 101.0, z = 31.25, heading = 365 } }); step()
check('placement libre : pose de l\'aperçu appliquée (hauteur, cap normalisé), sauvegardée et publiée', ok and GlobalState.gsPoints[KEY]
    and GlobalState.gsPoints[KEY].x == 103.0 and GlobalState.gsPoints[KEY].z == 31.25 and GlobalState.gsPoints[KEY].w == 5.0)
ok, msg = cb('gs_admin:action', 1, 'movepoint', nil, { key = KEY, pose = { x = 300.0, y = 100.0, z = 30.0, heading = 0 } }); step()
check('placement libre : pose à plus de 60 m du staff refusée', not ok and msg:find('Trop loin', 1, true))
ok = cb('gs_admin:action', 1, 'movepoint', nil, { key = KEY, pose = { x = 'x', y = 1, z = 1 } }); step()
check('placement libre : pose invalide refusée', not ok)
ok = cb('gs_admin:action', 1, 'movepoint', nil, { key = KEY }); step()
check('sans pose : posé aux pieds du staff, orienté comme lui (comme avant)', ok and GlobalState.gsPoints[KEY].x == 100.0 and GlobalState.gsPoints[KEY].w == 90.0)

local nearMe = { x = 102.0, y = 100.0, z = 29.0, heading = 180 }
ok, msg = cb('gs_admin:action', 2, 'addstaffped', nil, { kind = 'ped', target = 'libre', model = 'a_m_y_hipster_01', pose = nearMe }); step()
check('PNJ staff : modo refusé', not ok and msg == 'Niveau insuffisant.')
ok, msg = cb('gs_admin:action', 1, 'addstaffped', nil, { kind = 'ped', target = 'job:police:duty', model = 's_f_y_cop_01', scenario = 'WORLD_HUMAN_CLIPBOARD', pose = nearMe }); step()
check('PNJ staff relié à l\'accueil LSPD : ajouté, publié, journalisé', ok and #GlobalState.gsStaffPeds == 1 and GlobalState.gsStaffPeds[1].target == 'job:police:duty'
    and GlobalState.gsStaffPeds[1].heading == 180.0 and GlobalState.gsStaffPeds[1].scenario == 'WORLD_HUMAN_CLIPBOARD' and Admin.logs[1].action == 'addstaffped')
ok, msg = cb('gs_admin:action', 1, 'addstaffped', nil, { kind = 'ped', target = 'job:police:duty1', model = 's_m_y_cop_01', pose = nearMe }); step()
check('un seul PNJ staff par point (job:police:duty1 = job:police:duty)', not ok and msg:find('déjà un PNJ', 1, true))
ok, msg = cb('gs_admin:action', 1, 'addstaffped', nil, { kind = 'ped', target = 'job:police:stash', model = 's_m_y_cop_01', pose = nearMe }); step()
check('rôle hors accueil / direction / garage refusé', not ok and msg:find('Rôle inconnu', 1, true))
ok, msg = cb('gs_admin:action', 1, 'addstaffped', nil, { kind = 'ped', target = 'job:police:duty2', model = 's_m_y_cop_01', pose = nearMe }); step()
check('point inexistant pour ce métier refusé', not ok and msg:find('pas ce point', 1, true))
ok, msg = cb('gs_admin:action', 1, 'addstaffped', nil, { kind = 'ped', target = 'job:taxi:duty', model = 's_m_y_cop_01', pose = nearMe }); step()
check('métier inconnu refusé', not ok and msg == 'Métier inconnu.')
ok, msg = cb('gs_admin:action', 1, 'addstaffped', nil, { kind = 'ped', target = 'gang:zz', model = 'g_m_y_ballasout_01', pose = nearMe }); step()
check('gang inconnu refusé', not ok and msg == 'Gang inconnu.')
ok = cb('gs_admin:action', 1, 'addstaffped', nil, { kind = 'ped', target = 'gang:ballas', model = 'g_m_y_ballasout_01', scenario = 'WORLD_HUMAN_GUARD_STAND', pose = nearMe }); step()
check('PNJ staff relié à un gang : ajouté', ok and #GlobalState.gsStaffPeds == 2 and GlobalState.gsStaffPeds[2].target == 'gang:ballas')
ok, msg = cb('gs_admin:action', 1, 'addstaffped', nil, { kind = 'ped', target = 'libre', model = "s_m'; --", pose = nearMe }); step()
check('modèle injecté refusé', not ok and msg:find('invalide', 1, true))
ok, msg = cb('gs_admin:action', 1, 'addstaffped', nil, { kind = 'ped', target = 'libre', pose = nearMe }); step()
check('modèle obligatoire', not ok and msg == 'Modèle obligatoire.')
ok, msg = cb('gs_admin:action', 1, 'addstaffped', nil, { kind = 'ped', target = 'libre', model = 'a_m_y_beach_01', scenario = 'walk', pose = nearMe }); step()
check('scénario hors WORLD_HUMAN_… refusé', not ok and msg == 'Scénario invalide.')
ok, msg = cb('gs_admin:action', 1, 'addstaffped', nil, { kind = 'ped', target = 'libre', model = 'a_m_y_beach_01', pose = { x = 500.0, y = 500.0, z = 30.0, heading = 0 } }); step()
check('PNJ à plus de 60 m du staff refusé', not ok and msg:find('Trop loin', 1, true))
ok, msg = cb('gs_admin:action', 1, 'addstaffped', nil, { kind = 'car', target = 'libre', model = 'sultan', pose = nearMe }); step()
check('type inconnu refusé', not ok and msg:find('Type invalide', 1, true))
ok = cb('gs_admin:action', 1, 'addstaffped', nil, { kind = 'prop', target = 'job:police:duty', model = 'prop_bench_01a', pose = nearMe }); step()
check('objet relié au même point que le PNJ : accepté (seuls les PNJ sont uniques par point)', ok and #GlobalState.gsStaffPeds == 3 and GlobalState.gsStaffPeds[3].kind == 'prop')
check('cible : normalisation pure', Admin.staffTarget(nil) == 'libre' and Admin.staffTarget('') == 'libre'
    and Admin.staffTarget('job:police:garage1', exports.gs_jobs:ListJobs()) == 'job:police:garage'
    and Admin.staffTarget('gang:ballas', nil, { { name = 'ballas' } }) == 'gang:ballas' and Admin.staffTarget('nimporte') == nil
    and Admin.staffTarget(('x'):rep(60)) == nil)

check('catalogue d\'objets : modo refusé', cb('gs_admin:staffCatalog', 2) == nil); step()
local cat = cb('gs_admin:staffCatalog', 1); step()
local foundBench, foundApos = false, false
for _, c in ipairs(cat or {}) do
    for _, it in ipairs(c.items) do
        if it.model == 'prop_bench_01a' then foundBench = true end
        if it.label == 'Servante d\'atelier' then foundApos = true end
    end
end
check('catalogue d\'objets lu dans gs_builder/shared/config.lua : catégories, modèles, apostrophes rétablies', type(cat) == 'table' and #cat >= 5 and foundBench and foundApos)
check('catalogue : fonction pure, texte absent ou sans catalogue → vide', #Admin.parseCatalog(nil) == 0 and #Admin.parseCatalog('rien') == 0)

ok = cb('gs_admin:action', 1, 'delstaffped', nil, { id = 999 }); step()
check('retrait d\'une entrée inconnue refusé', not ok)
ok = cb('gs_admin:action', 2, 'delstaffped', nil, { id = 1 }); step()
check('retrait : modo refusé', not ok and #GlobalState.gsStaffPeds == 3)
ok, msg = cb('gs_admin:action', 1, 'delstaffped', nil, { id = 1 }); step()
check('retrait : supprimé, publié, message', ok and #GlobalState.gsStaffPeds == 2 and msg:find('retiré', 1, true) and dbRows[1] == nil)

-- V12.63 · Coincé sous la carte (n° 193) : retour auto validé par le serveur (altitude), bouton staff (F10 / F11)
tp(4, vec3(500.0, 500.0, 30.0))
allowedTp[4] = nil
check('coincé : refusé au-dessus du sol', cb('gs_admin:unstuck', 4) == false and not allowedTp[4])
step()
tp(4, vec3(500.0, 500.0, -60.0))
check('coincé : sous la carte → accepté, téléportation autorisée (anti-triche)', cb('gs_admin:unstuck', 4) == true and allowedTp[4])
step()
allowedTp[4] = nil
W.clientEvents = {}
ok, msg = cb('gs_admin:action', 3, 'unstuck', 4); step()
check('coincé : un helper peut ramener un joueur', ok and allowedTp[4] and lastClientEvent('gs_admin:client:unstuck', 4) ~= nil)
ok = cb('gs_admin:action', 4, 'unstuck', 2); step()
check('coincé : un joueur ne peut pas', not ok)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
