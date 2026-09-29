-- Tests gs_onboarding : liste blanche (convar, contournement staff, licence), règlement (version, acceptation, refus),
-- accueil des nouveaux, commande /whitelist.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_onboarding', { R .. 'gs_onboarding/shared/config.lua' })
local accepted, wl = {}, {}
Store = {
    init = function() end,
    rulesVersion = function(l) return accepted[l] or 0 end,
    acceptRules = function(l, v) accepted[l] = v end,
    isWhitelisted = function(l) return wl[l] ~= nil end,
    addWhitelist = function(l, by) wl[l] = by end,
    removeWhitelist = function(l) local had = wl[l] ~= nil wl[l] = nil return had end,
}
local done = { }
provide('gs_quests', { HasDone = function(src, id) return done[src] == true end })
local convars = {}
function GetConvar(k, d) return convars[k] or d end
local dropped = {}
function DropPlayer(src, why) dropped[src] = why end
loadResource('gs_onboarding', { R .. 'gs_onboarding/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end

join(1, 'CID1', 'Nouveau', vec3(0.0, 0.0, 0.0))
W.players[1].license = 'license:aaa'
join(2, 'CID2', 'Staff', vec3(0.0, 0.0, 0.0))
W.players[2].license = 'license:bbb'
W.players[2].aces = { ['gs.admin.helper'] = true, ['gs.admin.mod'] = true }

-- Liste blanche
check('liste blanche désactivée par défaut : accès libre', (Onboarding.check(1)))
convars.gs_whitelist = 'true'
local ok, msg = Onboarding.check(1)
check('liste blanche : refusé + lien Discord', not ok and msg:find('Discord'))
check('staff : passe toujours', (Onboarding.check(2)))
W.commands.whitelist(1, { 'add', '1' })
check('un joueur ne peut pas s\'ajouter', wl['license:aaa'] == nil)
W.commands.whitelist(2, { 'add', '1', 'candidature', 'validée' })
check('staff ajoute par id serveur', wl['license:aaa'] ~= nil and (Onboarding.check(1)))
W.commands.whitelist(0, { 'add', 'license:ccc' })
check('console ajoute par licence', wl['license:ccc'] == 'console')
W.commands.whitelist(2, { 'remove', 'license:aaa' })
check('retrait', wl['license:aaa'] == nil and not (Onboarding.check(1)))
ok, msg = Onboarding.command(2, { 'add', 'nimporte' })
check('cible invalide', not ok)
convars.gs_whitelist = nil

-- Règlement
TriggerEvent('gs_bridge:server:playerLoaded', 1)
check('règlement demandé au nouveau', Onboarding.pendingRules[1] and lastClientEvent('gs_onboarding:client:rules', 1) ~= nil)
check('accueil « premier jour » envoyé', lastClientEvent('gs_onboarding:client:welcome', 1) ~= nil)
ok = cb('gs_onboarding:accept', 1, true); step()
check('accepté : version enregistrée', ok and accepted['license:aaa'] == Config.RulesVersion and not Onboarding.pendingRules[1])
W.events = W.events or {}
local before = #W.clientEvents
TriggerEvent('gs_bridge:server:playerLoaded', 1)
check('déjà accepté : pas redemandé', Onboarding.pendingRules[1] == nil)
Config.RulesVersion = Config.RulesVersion + 1
TriggerEvent('gs_bridge:server:playerLoaded', 1)
check('nouvelle version : redemandé', Onboarding.pendingRules[1] == true)
cb('gs_onboarding:accept', 1, false); step()
check('refus : déconnecté', dropped[1] ~= nil)
done[2] = true
Onboarding.pendingRules = {}
W.clientEvents = {}
TriggerEvent('gs_bridge:server:playerLoaded', 2)
check('ancien joueur (premier jour fini) : pas d\'accueil', lastClientEvent('gs_onboarding:client:welcome', 2) == nil)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
