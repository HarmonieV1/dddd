-- gs_insurance (serveur) : contrats en mémoire (chargés au démarrage), achat vérifié (propriétaire, guichet, paiement).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Insurance = { expires = {} } -- expires[vehicleId] = timestamp

function Insurance.premium(model)
    local price = Bridge:GetVehiclePrice(model) or Config.DefaultPrice
    return math.max(Config.PremiumMin, math.min(Config.PremiumMax, math.floor(price * Config.PremiumRate)))
end

function Insurance.isInsured(id) return (Insurance.expires[tonumber(id) or -1] or 0) > os.time() end

--- Facteur appliqué au tarif de fourrière par qbx_garages (patch server/overrides/qbx_garages) : 1.0 = plein tarif.
exports('GetImpoundFactor', function(id) return Insurance.isInsured(id) and Config.ImpoundFactor or 1.0 end)
exports('IsInsured', Insurance.isInsured)

local function nearCounter(src) return Security:InRange(src, Config.Counter.coords, Config.Range + 1.5) end

lib.callback.register('gs_insurance:list', function(src)
    if not Security:RateLimit(src, 'gs_insurance:list', 6, 10000) then return nil end
    if not nearCounter(src) then return nil end
    local cid = Bridge:GetIdentifier(src)
    if not cid then return nil end
    local out = {}
    for i, v in ipairs(Store.vehicles(cid)) do
        local left = (Insurance.expires[v.id] or 0) - os.time()
        out[i] = { id = v.id, model = v.model, plate = v.plate, premium = Insurance.premium(v.model), daysLeft = left > 0 and math.ceil(left / 86400) or 0 }
    end
    return { vehicles = out, days = Config.Days, factor = Config.ImpoundFactor }
end)

lib.callback.register('gs_insurance:buy', function(src, id)
    if not Security:RateLimit(src, 'gs_insurance:buy', 3, 10000) then return false, 'Doucement.' end
    if not nearCounter(src) then return false, 'Présente-toi au guichet.' end
    id = math.floor(tonumber(id) or 0)
    local cid = Bridge:GetIdentifier(src)
    if not cid or id <= 0 or not Store.owns(cid, id) then return false, 'Ce véhicule n\'est pas à toi.' end
    local model
    for _, v in ipairs(Store.vehicles(cid)) do if v.id == id then model = v.model end end
    local base = math.max(Insurance.expires[id] or 0, os.time())
    if base - os.time() >= Config.MaxDaysAhead * 86400 then return false, ('Déjà couvert pour plus de %d jours.'):format(Config.MaxDaysAhead) end
    local price = Insurance.premium(model or '')
    if not Bridge:RemoveMoney(src, 'bank', price, 'assurance auto') and not Bridge:RemoveMoney(src, 'cash', price, 'assurance auto') then
        return false, ('Prime : %d $ (banque ou liquide).'):format(price)
    end
    Insurance.expires[id] = base + Config.Days * 86400
    Store.set(id, Insurance.expires[id])
    return true, ('Véhicule assuré %d jours de plus (%d $).'):format(Config.Days, price)
end)

CreateThread(function()
    Store.init()
    for _, r in ipairs(Store.all()) do Insurance.expires[r.vehicle_id] = r.expires_at end
end)
