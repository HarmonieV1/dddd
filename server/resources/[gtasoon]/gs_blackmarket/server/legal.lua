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

--- Permis de port d'arme au comptoir. Retourne ok, message. Isolé pour les tests.
function Legal.permit(src)
    local P = Config.Permit
    local near = false
    for _, d in ipairs(P.desks) do if exports.gs_security:InRange(src, d, 4.0) then near = true break end end
    if not near then return false, 'Va au comptoir d\'un Ammu-Nation.' end
    local lic = Bridge:GetLicences(src) or {}
    if lic.weapon then return false, 'Tu as déjà ton permis de port d\'arme.' end
    if P.needDriver and not lic.driver then return false, 'Il faut d\'abord ton permis de conduire (pièce d\'identité exigée).' end
    if GetResourceState('gs_wanted') == 'started' and (exports.gs_wanted:GetHeat(src) or 0) > P.maxHeat then
        return false, 'Refusé : tu es signalé par la police. Reviens avec un casier propre.'
    end
    if not Bridge:RemoveMoney(src, 'bank', P.price, 'permis-arme') and not Bridge:RemoveMoney(src, 'cash', P.price, 'permis-arme') then
        return false, ('Il faut %d $ (banque ou liquide).'):format(P.price)
    end
    Bridge:SetLicence(src, 'weapon', true)
    return true, 'Permis de port d\'arme délivré. Les armes du comptoir te sont accessibles (1 arme et 120 munitions par jour).'
end

lib.callback.register('gs_blackmarket:permit', function(src)
    if not exports.gs_security:RateLimit(src, 'gs_blackmarket:permit', 3, 10000) then return false, 'Doucement.' end
    return Legal.permit(src)
end)
