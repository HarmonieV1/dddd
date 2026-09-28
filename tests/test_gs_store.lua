-- Tests gs_store : livraison Tebex idempotente, console uniquement, réclamation unique, révocation, déblocages.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_store', { R .. 'gs_store/shared/config.lua' })
local orders, unlocks, prefs = {}, {}, {}
Store = {
    init = function() end,
    addOrder = function(t, p, b) if orders[t] then return false end orders[t] = { transaction = t, package = p, buyer = b, status = 'pending' } return true end,
    pending = function(b) local l = {} for _, o in pairs(orders) do if o.buyer == b and o.status == 'pending' then l[#l + 1] = o end end return l end,
    claim = function(t, b, cid) local o = orders[t] if o and o.buyer == b and o.status == 'pending' then o.status, o.claimed_by = 'claimed', cid return true end return false end,
    revoke = function(t) local o = orders[t] if not o then return nil end local s = o.status o.status = 'revoked'
        for k, u in pairs(unlocks) do if u.transaction == t then unlocks[k] = nil end end return s, o.claimed_by end,
    unlock = function(cid, ty, ref, t) unlocks[cid .. ty .. ref] = { citizenid = cid, type = ty, ref = ref, transaction = t } end,
    unlocks = function(cid) local l = {} for _, u in pairs(unlocks) do if u.citizenid == cid then l[#l + 1] = u end end return l end,
    setPed = function(cid, ped) prefs[cid] = ped end,
    getPed = function(cid) return prefs[cid] end,
}
loadResource('gs_store', { R .. 'gs_store/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(11000) end
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

join(1, 'CID1', 'Alpha Test', vec3(0.0, 0.0, 0.0))
W.players[1].fivem = 'fivem:111'
join(2, 'CID2', 'Autre Joueur', vec3(0.0, 0.0, 0.0))
W.players[2].fivem = 'fivem:222'

-- Livraison Tebex -----------------------------------------------------------------------------------
W.commands.gsstore_deliver(1, { 'TX-1', 'pack_neon_rider', '111' })
check('commande refusée en jeu (même admin)', count(orders) == 0)
W.commands.gsstore_deliver(0, { 'TX-1', 'pack_neon_rider', '111' })
check('commande console enregistrée', orders['TX-1'] and orders['TX-1'].buyer == 'fivem:111')
check('acheteur connecté notifié', W.notes[1] and W.notes[1].msg:find('/boutique') ~= nil)
W.commands.gsstore_deliver(0, { 'TX-1', 'pack_neon_rider', '111' })
check('double livraison ignorée (idempotent)', count(orders) == 1)
W.commands.gsstore_deliver(0, { 'TX-2;drop', 'pack_neon_rider', '111' })
check('transaction malformée refusée', orders['TX-2;drop'] == nil)
W.commands.gsstore_deliver(0, { 'TX-9', 'pack_inconnu', '111' })
check('package inconnu : enregistré quand même (argent encaissé)', orders['TX-9'] ~= nil)

-- Boutique désactivée ----------------------------------------------------------------------------------
local ok, msg = cb('gs_store:claim', 1, 'TX-1'); step()
check('réclamation fermée tant que désactivée', not ok and orders['TX-1'].status == 'pending')
Config.Enabled = true

-- Réclamation ---------------------------------------------------------------------------------------------
ok = cb('gs_store:claim', 2, 'TX-1'); step()
check('impossible de réclamer l\'achat d\'un autre', not ok and orders['TX-1'].status == 'pending')
local data = cb('gs_store:data', 1); step()
check('achat en attente visible', #data.pending == 2)
ok, msg = cb('gs_store:claim', 1, 'TX-1'); step()
check('réclamé', ok and orders['TX-1'].status == 'claimed' and orders['TX-1'].claimed_by == 'CID1')
check('véhicule livré', W.players[1].vehicles == 1)
check('tenue débloquée', unlocks['CID1outfitneon_jacket'] ~= nil)
ok = cb('gs_store:claim', 1, 'TX-1'); step()
check('pas de double réclamation', not ok and W.players[1].vehicles == 1)
ok, msg = cb('gs_store:claim', 1, 'TX-9'); step()
check('package inconnu : réclamation refusée, reste en attente', not ok and orders['TX-9'].status == 'pending')

-- Application -----------------------------------------------------------------------------------------------
check('tenue applicable', cb('gs_store:applyOutfit', 1, 'neon_jacket') ~= nil)
check('skin non possédé refusé', cb('gs_store:applyPed', 1, 'sunset_runner') == nil)
step()
W.commands.gsstore_deliver(0, { 'TX-3', 'skin_sunset', '111' })
cb('gs_store:claim', 1, 'TX-3'); step()
check('skin possédé applicable', cb('gs_store:applyPed', 1, 'sunset_runner') == Config.Peds.sunset_runner.model)
check('skin actif mémorisé', prefs.CID1 == 'sunset_runner')
check('autre joueur : refusé', cb('gs_store:applyPed', 2, 'sunset_runner') == nil)
step()

-- Reconnexion : skin réappliqué ------------------------------------------------------------------------------
W.clientEvents = {}
TriggerEvent('gs_bridge:server:playerUnloaded', 1)
join(1, 'CID1', 'Alpha Test', vec3(0.0, 0.0, 0.0))
W.players[1].fivem = 'fivem:111'
TriggerEvent('gs_bridge:server:playerLoaded', 1)
check('skin réappliqué au chargement', lastClientEvent('gs_store:client:applyPed', 1) ~= nil)

-- Livraison partielle (véhicule en échec) ---------------------------------------------------------------------
Config.Packages.test_casse = { label = 'Test', grants = { { type = 'vehicle', model = 'casse' }, { type = 'outfit', id = 'neon_jacket' } } }
W.commands.gsstore_deliver(0, { 'TX-4', 'test_casse', '111' })
ok, msg = cb('gs_store:claim', 1, 'TX-4'); step()
check('livraison partielle signalée au joueur', ok and msg:find('staff') ~= nil)

-- Révocation ------------------------------------------------------------------------------------------------------
W.commands.gsstore_revoke(0, { 'TX-3' })
check('révocation : skin retiré', cb('gs_store:applyPed', 1, 'sunset_runner') == nil)
step()
W.commands.gsstore_revoke(1, { 'TX-1' })
check('révocation refusée en jeu', orders['TX-1'].status == 'claimed')

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
