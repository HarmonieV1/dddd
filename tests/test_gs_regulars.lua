-- Tests gs_economy · les commerçants se souviennent (V10) : habitué après 5 jours de visite (remise + salutation),
-- braquage à visage découvert = refusé au comptoir 48 h, masqué = pas reconnu.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local store = {}
json.encode = function(t) store.last = t return 'k' end
local kv = {}
function SetResourceKvp(k, v) kv[k] = store.last end
function GetResourceKvpString(k) return kv[k] and 'k' or nil end
json.decode = function() return nil end
-- KVP en mémoire : on court-circuite le JSON
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_economy', { R .. 'gs_economy/shared/config.lua', R .. 'gs_economy/shared/pricing.lua', R .. 'gs_economy/server/regulars.lua' })
local mem = {}
local function load(cid) return mem[cid] or {} end
-- remplace la persistance par une table (le format KVP est testé ailleurs)
local up = debug.getupvalue
for i = 1, 20 do
    local n = up(Regulars.visit, i)
    if n == 'loadReg' then debug.setupvalue(Regulars.visit, i, load) end
    if n == 'saveReg' then debug.setupvalue(Regulars.visit, i, function(cid, t) mem[cid] = t end) end
end
for _, f in ipairs({ Regulars.isRegular, Regulars.banned, Regulars.robbed }) do
    for i = 1, 20 do
        local n = up(f, i)
        if n == 'loadReg' then debug.setupvalue(f, i, load) end
        if n == 'saveReg' then debug.setupvalue(f, i, function(cid, t) mem[cid] = t end) end
    end
end

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local shop = Config.Shops[1]
local c = shop.clerk or shop.coords
join(1, 'CID1', 'Client', vec3(c.x, c.y, c.z))
local realDate = os.date
local day = 1
os.date = function(f, t) if f == '%Y-%m-%d' then return '2026-10-' .. day end return realDate(f, t) end

Regulars.visit(1, 1) Regulars.visit(1, 1)
check('deux achats le même jour = une visite', mem.CID1['1'].n == 1)
for d = 2, 5 do day = d Regulars.visit(1, 1) end
check('5 jours de visite : habitué', Regulars.isRegular(1, 1))
check('remise d\'habitué ajoutée à la réputation, plafonnée', math.abs(Regulars.discount(1, 1, 0.10) - 0.15) < 1e-9 and Regulars.discount(1, 1, 0.5) == Config.Regulars.maxDiscount)
check('habitué d\'un magasin, pas des autres', not Regulars.isRegular(1, 2))
W.players[1].clothes = { [1] = { 5, 0 } }
check('braquage masqué : pas reconnu', Regulars.robbed(1, vec3(c.x, c.y, c.z)) == false and not Regulars.banned(1, 1))
W.players[1].clothes = { [1] = { 0, 0 } }
check('braquage à visage découvert : reconnu', Regulars.robbed(1, vec3(c.x, c.y, c.z)) == 1)
check('refusé au comptoir, plus habitué', Regulars.banned(1, 1) ~= nil and not Regulars.isRegular(1, 1))
mem.CID1['1'].ban = os.time() - 1
check('après 48 h : de nouveau servi', Regulars.banned(1, 1) == nil)
check('braquage loin de tout magasin : rien', Regulars.robbed(1, vec3(9000.0, 9000.0, 0.0)) == false)
os.date = realDate

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
