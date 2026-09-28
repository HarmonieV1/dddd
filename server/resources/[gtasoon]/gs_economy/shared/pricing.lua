-- Calcul des prix, partagé serveur/client (le client ne fait qu'AFFICHER ; le serveur recalcule tout).
Pricing = {}

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end

--- Multiplicateur d'offre/demande seul (sans événement), borné par min/max de l'item.
function Pricing.marketFactor(item, pressure)
    local def = Config.Items[item]
    return clamp(1 + (pressure or 0) * Config.Elasticity, def.min, def.max)
end

--- Prix unitaire d'achat.
function Pricing.buyPrice(item, pressure, eventMult)
    local def = Config.Items[item]
    return math.max(1, math.floor(def.base * Pricing.marketFactor(item, pressure) * (eventMult or 1) + 0.5))
end

--- Prix unitaire de revente : toujours strictement sous le prix d'achat courant (pas d'arbitrage).
function Pricing.sellPrice(item, pressure, eventMult)
    local def = Config.Items[item]
    if def.buy == false then
        return math.max(1, math.floor(def.base * Pricing.marketFactor(item, pressure) * (eventMult or 1) + 0.5))
    end
    local buy = Pricing.buyPrice(item, pressure, eventMult)
    return math.max(0, math.min(buy - 1, math.floor(buy * (def.sell or 0.4))))
end

--- Tendance affichée : 1 hausse, -1 baisse, 0 stable.
function Pricing.trend(item, pressure, eventMult)
    local f = Pricing.marketFactor(item, pressure) * (eventMult or 1)
    if f > 1.1 then return 1 elseif f < 0.9 then return -1 end
    return 0
end
