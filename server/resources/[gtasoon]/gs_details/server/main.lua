-- gs_details (serveur) : /me et /do, relayés seulement aux joueurs proches (le serveur calcule la portée).
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

local function relay(src, kind, text)
    text = Security:Sanitize(text, Config.Me.maxLength)
    if not text or not Bridge:IsLoaded(src) then return end
    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local c = GetEntityCoords(ped)
    for _, id in ipairs(GetPlayers()) do
        local t = tonumber(id)
        local tp = GetPlayerPed(t)
        if tp ~= 0 and #(GetEntityCoords(tp) - c) <= Config.Me.range then
            TriggerClientEvent('gs_details:client:me', t, src, kind, text)
        end
    end
end

RegisterNetEvent('gs_details:server:me', function(kind, text)
    if not Security:RateLimit(source, 'gs_details:me', 3, 10000) then return end
    relay(source, kind == 'do' and 'do' or 'me', text)
end)

-- Tenues en objets (client/outfits.lua) : le client décrit ses vêtements ; on vérifie la forme (nombres, tailles)
-- avant de créer l'objet. Purement cosmétique, mais jamais de données arbitraires dans l'inventaire.
local function validPart(t, maxKeys)
    if type(t) ~= 'table' then return false end
    local n = 0
    for k, v in pairs(t) do
        n = n + 1
        if n > maxKeys or not tostring(k):match('^%d%d?$') or type(v) ~= 'table' then return false end
        local d, x = tonumber(v[1]), tonumber(v[2])
        if not d or not x or d < -1 or d > 1000 or x < -1 or x > 100 or d ~= math.floor(d) or x ~= math.floor(x) then return false end
    end
    return true
end

lib.callback.register('gs_details:foldOutfit', function(src, name, outfit)
    if not Security:RateLimit(src, 'gs_details:foldOutfit', 3, 10000) then return false, 'Doucement.' end
    if type(name) ~= 'string' or #name < 1 or #name > 30 then return false, 'Nom invalide.' end
    if type(outfit) ~= 'table' or not validPart(outfit.c, 12) or not validPart(outfit.p, 8) or (outfit.m ~= 'm' and outfit.m ~= 'f') then
        return false, 'Tenue invalide.'
    end
    local label = Security:Sanitize(name, 30)
    if not label then return false, 'Nom invalide.' end
    local meta = { label = 'Tenue : ' .. label, description = outfit.m == 'f' and 'Tenue femme' or 'Tenue homme',
        outfit = { c = outfit.c, p = outfit.p, m = outfit.m } }
    if not Bridge:AddItem(src, 'gs_outfit', 1, meta) then return false, 'Ton sac est plein.' end
    return true, ('« %s » pliée et rangée dans ton sac.'):format(label)
end)
