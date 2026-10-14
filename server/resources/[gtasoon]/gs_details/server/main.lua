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

--- Crée l'objet Tenue (gs_outfit) à partir d'une tenue déjà vérifiée. Retourne ok, message.
local function giveOutfit(src, name, outfit)
    local label = Security:Sanitize(name, 30)
    if not label then return false, 'Nom invalide.' end
    local meta = { label = 'Tenue : ' .. label, description = outfit.m == 'f' and 'Tenue femme' or 'Tenue homme',
        outfit = { c = outfit.c, p = outfit.p, m = outfit.m } }
    if not Bridge:AddItem(src, 'gs_outfit', 1, meta) then return false, 'Ton sac est plein.' end
    return true, ('« %s » pliée et rangée dans ton sac.'):format(label)
end

-- V12.26 · Tenue enregistrée dans le magasin de vêtements (illenium-appearance « Enregistrer la tenue ») : elle devient
-- AUSSI un objet Tenue, à enfiler d'un double-clic n'importe où. Même format que « Plier ma tenue ».
local ILL_COMPONENTS = { [1] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true, [9] = true, [10] = true, [11] = true }
local ILL_PROPS = { [0] = true, [1] = true, [2] = true, [6] = true, [7] = true }
local function fromIllenium(model, components, props)
    if type(components) ~= 'table' or type(props) ~= 'table' then return nil end
    local o = { c = {}, p = {}, m = model == 'mp_f_freemode_01' and 'f' or (model == 'mp_m_freemode_01' and 'm' or nil) }
    if not o.m then return nil end
    for _, c in pairs(components) do
        local id = type(c) == 'table' and tonumber(c.component_id)
        if id and ILL_COMPONENTS[id] then o.c[tostring(id)] = { tonumber(c.drawable) or 0, tonumber(c.texture) or 0 } end
    end
    for _, p in pairs(props) do
        local id = type(p) == 'table' and tonumber(p.prop_id)
        if id and ILL_PROPS[id] then o.p[tostring(id)] = { tonumber(p.drawable) or -1, tonumber(p.texture) or 0 } end
    end
    return o
end
RegisterNetEvent('illenium-appearance:server:saveOutfit', function(name, model, components, props) -- [API] illenium-appearance
    local src = source
    if not Security:RateLimit(src, 'gs_details:shopOutfit', 3, 10000) then return end
    local outfit = fromIllenium(model, components, props)
    if not outfit or not validPart(outfit.c, 12) or not validPart(outfit.p, 8) or type(name) ~= 'string' or #name < 1 or #name > 60 then return end
    local ok, msg = giveOutfit(src, name:sub(1, 30), outfit)
    Bridge:Notify(src, ok and ('Tenue enregistrée : un objet « %s » est aussi dans ton sac.'):format(name:sub(1, 30)) or msg, ok and 'success' or 'error')
end)

lib.callback.register('gs_details:foldOutfit', function(src, name, outfit)
    if not Security:RateLimit(src, 'gs_details:foldOutfit', 3, 10000) then return false, 'Doucement.' end
    if type(name) ~= 'string' or #name < 1 or #name > 30 then return false, 'Nom invalide.' end
    if type(outfit) ~= 'table' or not validPart(outfit.c, 12) or not validPart(outfit.p, 8) or (outfit.m ~= 'm' and outfit.m ~= 'f') then
        return false, 'Tenue invalide.'
    end
    return giveOutfit(src, name, outfit)
end)

-- V12.26 · Garde-robe : pièces de vêtements en objets (gs_cloth). Le client décrit la pièce portée ; le serveur vérifie
-- sa forme (emplacement connu, numéros plausibles) avant de créer l'objet. Purement cosmétique.
local SLOT = {}
for _, s in ipairs(Config.Wardrobe.slots) do SLOT[s.key] = s end

local function num(v, lo, hi)
    v = tonumber(v)
    return v and v == math.floor(v) and v >= lo and v <= hi and v or nil
end

--- Pièce envoyée par le client → pièce propre (ou nil). { key, d, t, a = { d, t } (bras du haut), m }
local function cleanPiece(p)
    if type(p) ~= 'table' then return nil end
    local s = SLOT[p.key]
    if not s or (p.m ~= 'm' and p.m ~= 'f') then return nil end
    local d, t = num(p.d, 0, 2000), num(p.t, 0, 100) -- accessoire retiré = -1 : pas un vêtement
    if not d or not t then return nil end
    if s.none and d == s.none[p.m] then return nil end -- « rien porté » : pas un vêtement
    local piece = { key = s.key, d = d, t = t, m = p.m }
    if s.arms then
        local a = type(p.a) == 'table' and { num(p.a[1], 0, 2000), num(p.a[2], 0, 100) } or nil
        if not a or not a[1] or not a[2] then return nil end
        piece.a = a
    end
    return piece
end

local function pieceMeta(piece)
    local s = SLOT[piece.key]
    return { label = s.label, image = s.image, piece = piece,
        description = ('%s %s · modèle %d, coloris %d'):format(s.label, piece.m == 'f' and 'femme' or 'homme', piece.d, piece.t) }
end

--- Retirer une pièce portée → objet dans le sac. Le client ne l'enlève que si l'objet a bien été créé.
lib.callback.register('gs_details:takeOffPiece', function(src, p)
    if not Security:RateLimit(src, 'gs_details:piece', 10, 10000) then return false, 'Doucement.' end
    local piece = cleanPiece(p)
    if not piece then return false, 'Rien à retirer ici.' end
    if not Bridge:AddItem(src, 'gs_cloth', 1, pieceMeta(piece)) then return false, 'Ton sac est plein.' end
    return true, ('%s rangé dans ton sac.'):format(SLOT[piece.key].label)
end)

--- Enfiler la pièce de la case `slot` du sac ; `previous` = pièce portée au même endroit (revient dans le sac).
--- Renvoie la pièce à appliquer. Le sac doit pouvoir reprendre l'ancienne pièce AVANT de retirer la nouvelle.
lib.callback.register('gs_details:wearPiece', function(src, slot, previous, model)
    if not Security:RateLimit(src, 'gs_details:piece', 10, 10000) then return false, 'Doucement.' end
    local list = Bridge:ListSlots(src, 'gs_cloth')
    local entry
    for _, e in ipairs(list) do if e.slot == slot then entry = e break end end
    local piece = entry and cleanPiece(entry.metadata.piece)
    if not piece then return false, 'Vêtement introuvable.' end
    if piece.m ~= model then return false, 'Ce vêtement n\'est pas à ta taille (modèle homme / femme).' end
    local prev = cleanPiece(previous)
    if prev and prev.key ~= piece.key then prev = nil end
    if prev and not Bridge:CanCarry(src, 'gs_cloth', 1) then return false, 'Ton sac est plein.' end
    if not Bridge:TakeSlot(src, 'gs_cloth', slot) then return false, 'Vêtement introuvable.' end
    if prev then Bridge:AddItem(src, 'gs_cloth', 1, pieceMeta(prev)) end
    return true, piece
end)

--- Tenue complète (gs_outfit) depuis la garde-robe : retire l'objet et renvoie la tenue à enfiler.
lib.callback.register('gs_details:takeOutfit', function(src, slot, model)
    if not Security:RateLimit(src, 'gs_details:piece', 10, 10000) then return false, 'Doucement.' end
    local entry
    for _, e in ipairs(Bridge:ListSlots(src, 'gs_outfit')) do if e.slot == slot then entry = e break end end
    local o = entry and entry.metadata.outfit
    if type(o) ~= 'table' then return false, 'Tenue introuvable.' end
    if (o.m or 'm') ~= model then return false, 'Cette tenue n\'est pas à ta taille (modèle homme / femme).' end -- vérifié AVANT de la retirer
    local meta = Bridge:TakeSlot(src, 'gs_outfit', slot)
    if not meta then return false, 'Tenue introuvable.' end
    return true, meta.outfit, meta.label
end)

--- Contenu du sac pour la garde-robe (vêtements et tenues).
lib.callback.register('gs_details:wardrobeBag', function(src)
    if not Security:RateLimit(src, 'gs_details:bag', 10, 10000) then return { pieces = {}, outfits = {} } end
    local pieces, outfits = {}, {}
    for _, e in ipairs(Bridge:ListSlots(src, 'gs_cloth')) do
        local p = cleanPiece(e.metadata.piece)
        if p then pieces[#pieces + 1] = { slot = e.slot, key = p.key, label = SLOT[p.key].label, image = SLOT[p.key].image, d = p.d, t = p.t, m = p.m, a = p.a } end
    end
    for _, e in ipairs(Bridge:ListSlots(src, 'gs_outfit')) do
        outfits[#outfits + 1] = { slot = e.slot, label = e.metadata.label or 'Tenue', m = e.metadata.outfit and e.metadata.outfit.m }
    end
    return { pieces = pieces, outfits = outfits }
end)
