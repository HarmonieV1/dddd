-- Tests gs_details : tenues en objets (V12.26 : tenue enregistrée au magasin illenium-appearance → objet Tenue ;
-- pièces de vêtements en objets de la garde-robe).
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local base = {}
for _, k in ipairs({ 'IsLoaded', 'AddItem', 'Notify', 'RemoveItem', 'GetItemCount', 'CanCarry' }) do base[k] = getExport('gs_bridge', k) end
local items = {}
local api = setmetatable({}, { __index = base })
local bag = {} -- [slot] = { name, metadata } : sac simulé pour la garde-robe
local nextSlot = 1
api.AddItem = function(src, item, n, meta)
    if W.players[src].full then return false end
    items[#items + 1] = { src = src, item = item, meta = meta }
    bag[nextSlot] = { name = item, metadata = meta } nextSlot = nextSlot + 1
    return base.AddItem(src, item, n)
end
api.ListSlots = function(_, item)
    local out = {}
    for slot, s in pairs(bag) do if s.name == item then out[#out + 1] = { slot = slot, label = s.metadata.label, metadata = s.metadata } end end
    table.sort(out, function(a, b) return a.slot < b.slot end)
    return out
end
api.TakeSlot = function(_, item, slot) local s = bag[slot] if not s or s.name ~= item then return nil end bag[slot] = nil return s.metadata end
provide('gs_bridge', api)
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_details', { R .. 'gs_details/shared/config.lua', R .. 'gs_details/server/main.lua' })

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
join(1, 'CID1', 'Alex Torres', vec3(0.0, 0.0, 0.0))

-- 1. Tenue enregistrée au magasin → objet Tenue (format illenium-appearance converti)
net('illenium-appearance:server:saveOutfit', 1, 'Soirée', 'mp_m_freemode_01',
    { { component_id = 11, drawable = 4, texture = 1 }, { component_id = 4, drawable = 10, texture = 0 }, { component_id = 2, drawable = 7, texture = 0 } },
    { { prop_id = 0, drawable = -1, texture = 0 }, { prop_id = 6, drawable = 3, texture = 0 } })
local it = items[#items]
check('objet Tenue créé', it and it.item == 'gs_outfit' and it.meta.label == 'Tenue : Soirée' and it.meta.outfit.m == 'm')
check('haut et pantalon gardés, coiffure (2) jamais', it and it.meta.outfit.c['11'][1] == 4 and it.meta.outfit.c['4'][1] == 10 and it.meta.outfit.c['2'] == nil)
check('accessoires : chapeau retiré, montre', it and it.meta.outfit.p['0'][1] == -1 and it.meta.outfit.p['6'][1] == 3)
-- 2. données douteuses refusées
local n = #items
advance(11000)
net('illenium-appearance:server:saveOutfit', 1, 'X', 'a_m_y_hipster_01', {}, {})
check('modèle non joueur : rien', #items == n)
advance(11000)
net('illenium-appearance:server:saveOutfit', 1, 'X', 'mp_f_freemode_01', { { component_id = 11, drawable = 99999, texture = 0 } }, {})
check('numéro de vêtement absurde : rien', #items == n)
advance(11000)
net('illenium-appearance:server:saveOutfit', 1, 'Robe', 'mp_f_freemode_01', { { component_id = 11, drawable = 5, texture = 2 } }, {})
check('tenue femme', items[#items].meta.outfit.m == 'f' and items[#items].meta.description == 'Tenue femme')

-- 3. Garde-robe : retirer une pièce → objet Vêtement
advance(11000)
local ok, msg = cb('gs_details:takeOffPiece', 1, { key = 'top', d = 12, t = 2, a = { 4, 0 }, m = 'm' })
local cloth = items[#items]
check('haut retiré → objet', ok and cloth.item == 'gs_cloth' and cloth.meta.piece.key == 'top' and cloth.meta.piece.a[1] == 4 and cloth.meta.image == 'cloth_top')
check('rien porté (valeur « nu ») : refusé', cb('gs_details:takeOffPiece', 1, { key = 'legs', d = 61, t = 0, m = 'm' }) == false)
check('emplacement inconnu : refusé', cb('gs_details:takeOffPiece', 1, { key = 'coiffure', d = 3, t = 0, m = 'm' }) == false)
check('haut sans bras : refusé', cb('gs_details:takeOffPiece', 1, { key = 'top', d = 12, t = 2, m = 'm' }) == false)
-- 4. Enfiler depuis le sac : l'ancienne pièce revient dans le sac
local slotTop
for slot, s in pairs(bag) do if s.name == 'gs_cloth' and s.metadata.piece.key == 'top' then slotTop = slot end end
advance(11000)
local ok2, piece = cb('gs_details:wearPiece', 1, slotTop, { key = 'top', d = 30, t = 0, a = { 5, 0 }, m = 'm' }, 'm')
check('pièce rendue au client', ok2 and piece.d == 12 and piece.a[1] == 4)
check('objet retiré du sac', bag[slotTop] == nil)
local back = items[#items]
check('ancienne pièce dans le sac', back.item == 'gs_cloth' and back.meta.piece.d == 30)
-- 5. Mauvaise taille, sac plein
cb('gs_details:takeOffPiece', 1, { key = 'shoes', d = 3, t = 1, m = 'f' })
local slotF = nextSlot - 1
check('vêtement femme sur un homme : refusé', cb('gs_details:wearPiece', 1, slotF, nil, 'm') == false and bag[slotF] ~= nil)
W.players[1].full = true
cb('gs_details:takeOffPiece', 1, { key = 'hat', d = 3, t = 0, m = 'm' })
check('sac plein : rien retiré', items[#items].meta.piece.key ~= 'hat')
W.players[1].full = false
-- 6. Tenue complète depuis la garde-robe : taille vérifiée AVANT de retirer l'objet
local slotO
for slot, s in pairs(bag) do if s.name == 'gs_outfit' and s.metadata.outfit.m == 'f' then slotO = slot end end
advance(11000)
check('tenue femme pour un homme : refusée et gardée', cb('gs_details:takeOutfit', 1, slotO, 'm') == false and bag[slotO] ~= nil)
local okO, o = cb('gs_details:takeOutfit', 1, slotO, 'f')
check('bonne taille : tenue rendue et retirée du sac', okO and o.m == 'f' and bag[slotO] == nil)
check('contenu du sac pour l\'écran', #cb('gs_details:wardrobeBag', 1).pieces >= 2)

io.write(('tenues en objets : %d réussis, %d échoués\n'):format(passed, failed))
if failed > 0 then os.exit(1) end
