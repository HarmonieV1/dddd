-- Tests gs_bridge/server/carkeys.lua (V12.26) : clés de véhicule en objet par-dessus qbx_vehiclekeys.
local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local H, EX, notes, client = {}, {}, {}, {}
local inv = {}            -- [src] = { slots }
local vehicles = { [5001] = { plate = 'ABC 123 ', model = 111, pos = vector3 and nil, state = { sessionId = 7 } },
                   [5002] = { plate = 'ZZZ', model = 222, state = { sessionId = 8 } } }
local players = { [1] = { cid = 'CID1', pos = { 0, 0, 0 }, keys = {} }, [2] = { cid = 'CID2', pos = { 0, 0, 0 }, keys = {} } }
local vpos = { [5001] = { 3, 0, 0 }, [5002] = { 500, 0, 0 } }
local function vec(t) return setmetatable({ x = t[1], y = t[2], z = t[3] }, { __sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, { __len = function(v) return math.sqrt(v.x ^ 2 + v.y ^ 2 + v.z ^ 2) end }) end }) end
function GetAllVehicles() return { 5001, 5002 } end
function Entity(e) return { state = vehicles[e].state } end
function GetVehicleNumberPlateText(e) return vehicles[e].plate end
function GetEntityModel(e) return vehicles[e].model end
function GetEntityCoords(e) return vec(vpos[e] or players[e - 100].pos) end
function GetPlayerPed(src) return 100 + src end
function GetVehicleDoorLockStatus() return 1 end
function DoesEntityExist(e) return vehicles[e] ~= nil end
function NetworkGetNetworkIdFromEntity(e) return e end
function TriggerClientEvent(name, src, a, b) client[#client + 1] = { name = name, src = src, a = a, b = b } end
function AddStateBagChangeHandler(key, _, fn) H[key] = fn end
function CreateThread(fn) fn() end
function Wait() end
function exports(name, fn) EX[name] = fn end
exports = setmetatable({}, { __call = function(_, name, fn) EX[name] = fn end, __index = function(_, res)
    if res == 'ox_inventory' then return {
        Search = function(_, src, _, item) local r = {} for i, s in pairs(inv[src] or {}) do if s.name == item then r[#r + 1] = s end end return r end,
        AddItem = function(_, src, item, n, meta) inv[src] = inv[src] or {} table.insert(inv[src], { name = item, count = n, metadata = meta, slot = #inv[src] + 1 }) return true end,
        GetSlot = function(_, src, slot) return inv[src] and inv[src][slot] end,
    } end
    if res == 'qbx_core' then return {
        GetPlayer = function(_, src) return players[src] and { PlayerData = { citizenid = players[src].cid } } end,
        GetVehiclesByHash = function(_, h) return ({ [111] = { brand = 'Karin', name = 'Sultan' } })[h] or {} end,
    } end
    if res == 'qbx_vehiclekeys' then return {
        HasKeys = function(_, src, veh) return players[src].keys[veh] == true end,
        GiveKeys = function(_, src, veh) players[src].keys[veh] = true return true end,
        SetLockState = function(_, veh, st) vehicles[veh].state.doorslockstate = st == 'lock' and 2 or 1 end,
    } end
end })
dofile('server/resources/[gtasoon]/gs_bridge/server/carkeys.lua')

-- 1. qbx_vehiclekeys donne des clés → une clé-objet, avec le modèle et la plaque (espaces retirés)
H.keysList('player:1', 'keysList', { [7] = true })
check('clé-objet reçue', inv[1] and #inv[1] == 1 and inv[1][1].name == 'gs_carkey' and inv[1][1].metadata.plate == 'ABC 123')
check('libellé avec le modèle', inv[1][1].metadata.label == 'Clé — Karin Sultan')
-- 2. une seule clé par plaque, et jamais redonnée si on l'a donnée / jetée
H.keysList('player:1', 'keysList', { [7] = true })
check('pas de doublon', #inv[1] == 1)
table.remove(inv[1], 1)
H.keysList('player:1', 'keysList', { [7] = true, [8] = true })
check('clé donnée à un ami : pas recréée, la nouvelle voiture oui', #inv[1] == 1 and inv[1][1].metadata.plate == 'ZZZ')
-- 3. l'ami utilise la clé près de la voiture → accès + verrouillage
inv[2] = { { name = 'gs_carkey', count = 1, metadata = { plate = 'ABC 123' }, slot = 1 } }
local r = EX.useCarKey('usingItem', {}, { id = 2 }, 1)
check('jamais consommée', r == false)
check('accès donné à qui tient la clé', players[2].keys[5001] == true)
check('verrouillée', vehicles[5001].state.doorslockstate == 2)
EX.useCarKey('usingItem', {}, { id = 2 }, 1)
check('re-clic : déverrouillée', vehicles[5001].state.doorslockstate == 1)
-- 4. trop loin : rien
inv[2][2] = { name = 'gs_carkey', count = 1, metadata = { plate = 'ZZZ' }, slot = 2 }
EX.useCarKey('usingItem', {}, { id = 2 }, 2)
check('véhicule trop loin : pas d\'accès', players[2].keys[5002] == nil and client[#client].a.type == 'error')
-- 5. autre joueur, état sans table, sac inconnu : sans effet
H.keysList('player:9', 'keysList', { [7] = true })
H.keysList('player:1', 'keysList', nil)
check('joueur inconnu / état vide : rien', inv[9] == nil)
print(('clés de véhicule : %d réussis, %d échoués'):format(passed, failed))
if failed > 0 then os.exit(1) end
