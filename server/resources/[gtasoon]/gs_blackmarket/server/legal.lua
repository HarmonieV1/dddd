-- Armureries légales : plafond de munitions et d'armes par personnage et par jour (hook ox_inventory).
-- Sans ça, un gang achète 5 000 balles au comptoir et le marché noir ne sert à rien.
local Bridge = exports.gs_bridge
Legal = { bought = {} } -- [cid] = { day, ammo, weapons }

--- Contrôle d'un achat en armurerie légale. Retourne true (autorisé) ou false, message.
function Legal.check(src, itemName, count)
    local cid = Bridge:GetIdentifier(src)
    if not cid then return false, 'Invalide.' end
    local b = Legal.bought[cid]
    if not b or b.day ~= Market.today() then b = { day = Market.today(), ammo = 0, weapons = 0 } Legal.bought[cid] = b end
    if itemName:find('^ammo%-') then
        if b.ammo + count > Config.Legal.ammoPerDay then
            return false, ('Limite légale : %d munitions par jour (encore %d).'):format(Config.Legal.ammoPerDay, math.max(0, Config.Legal.ammoPerDay - b.ammo))
        end
        b.ammo = b.ammo + count
    elseif itemName:find('^WEAPON_') and not Config.Legal.free[itemName] then
        if b.weapons + 1 > Config.Legal.weaponsPerDay then return false, 'Limite légale : une arme par jour.' end
        b.weapons = b.weapons + 1
    end
    return true
end

CreateThread(function()
    if GetResourceState('ox_inventory') ~= 'started' then return end
    exports.ox_inventory:registerHook('buyItem', function(payload) -- [API] ox_inventory hooks
        if payload.shopType ~= Config.Legal.shopType then return end
        local ok, msg = Legal.check(payload.source, payload.itemName or '', tonumber(payload.count) or 1)
        if not ok then Bridge:Notify(payload.source, msg, 'error') return false end
    end, {})
end)
