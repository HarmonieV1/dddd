-- gs_auction (client) · V10.1 « Enchères de la fourrière » : /encheres (ou [E] à la fourrière de Davis) — voir les lots,
-- enchérir ; la police dépose ses saisies ; le staff peut ouvrir / fermer une vente.
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error', duration = 7000 }) end end

local function deposit()
    local items = {}
    local ok, inv = pcall(function() return exports.ox_inventory:GetPlayerItems() end) -- [API] ox_inventory
    for _, it in ipairs(ok and inv or {}) do
        if not it.name:upper():find('^WEAPON_') and not it.name:lower():find('ammo') then
            items[#items + 1] = { value = it.name, label = ('%s (%d)'):format(it.label or it.name, it.count or 1) }
        end
    end
    if #items == 0 then return notify(false, 'Rien à déposer.') end
    local r = lib.inputDialog('Mettre une saisie aux enchères', {
        { type = 'select', label = 'Objet saisi', options = items, required = true },
        { type = 'number', label = 'Quantité', default = 1, min = 1, max = 100, required = true },
        { type = 'number', label = 'Mise de départ ($)', default = 100, min = Config.MinStart, required = true },
    })
    if r then notify(lib.callback.await('gs_auction:deposit', false, r[1], r[2], r[3])) end
end

local function open()
    local d = lib.callback.await('gs_auction:list', false)
    if not d then return end
    local o = {}
    o[#o + 1] = { title = d.open and 'Vente en cours !' or 'Prochaine vente : samedi à 21 h', icon = 'gavel', iconColor = d.open and '#5aff8c' or '#ffd23f',
        description = 'Mise bloquée en banque, remboursée si quelqu\'un surenchérit. Recette versée à la police.', readOnly = true }
    if d.police then o[#o + 1] = { title = 'Déposer une saisie', icon = 'box-archive', description = 'À la fourrière, policier en service', onSelect = deposit } end
    if d.staff then
        o[#o + 1] = { title = d.open and 'Staff : clore la vente' or 'Staff : ouvrir une vente (30 min)', icon = 'user-shield', onSelect = function()
            notify(lib.callback.await('gs_auction:staff', false, not d.open))
        end }
    end
    if #d.lots == 0 then o[#o + 1] = { title = 'Aucun lot pour le moment', icon = 'box-open', readOnly = true } end
    for _, l in ipairs(d.lots) do
        o[#o + 1] = { title = l.label, icon = l.kind == 'vehicle' and 'car' or 'box', iconColor = l.mine and '#5aff8c' or nil,
            description = l.bid and ('Meilleure offre : %d $%s'):format(l.bid, l.mine and ' (toi)' or '') or ('Départ : %d $'):format(l.start),
            readOnly = not d.open, onSelect = d.open and function()
                local r = lib.inputDialog(l.label, { { type = 'number', label = ('Ton offre (min. %d $)'):format(l.min), default = l.min, min = l.min, required = true } })
                if r then notify(lib.callback.await('gs_auction:bid', false, l.id, r[1])) end
            end or nil }
    end
    lib.registerContext({ id = 'gs_auction', title = 'Enchères de la fourrière', options = o })
    lib.showContext('gs_auction')
end

RegisterCommand('encheres', open, false)
AddEventHandler('gs_auction:client:open', open)

CreateThread(function()
    exports.gs_markers:Add('gs_auction:desk', { coords = Config.Point, style = 'hidden', event = 'gs_auction:client:open', prompt = 'Enchères de la fourrière' })
    local blip = AddBlipForCoord(Config.Point.x, Config.Point.y, Config.Point.z)
    SetBlipSprite(blip, 431) SetBlipColour(blip, 5) SetBlipScale(blip, 0.7) SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName('Enchères de la fourrière') EndTextCommandSetBlipName(blip)
end)
