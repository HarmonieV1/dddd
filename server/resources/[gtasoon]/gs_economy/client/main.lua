-- gs_economy (client) : zones ox_target + menus. Les prix affichés viennent du serveur.
local TREND = { [1] = '▲', [-1] = '▼', [0] = '' }

local function addBlip(coords, style, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, style.sprite)
    SetBlipColour(blip, style.color)
    SetBlipScale(blip, style.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)
end

local function openMarket(kind, index, place)
    local quote = lib.callback.await('gs_economy:quote', false, kind, index)
    if not quote then return lib.notify({ description = 'Tu es trop loin.', type = 'error' }) end
    if quote.refused then return lib.notify({ title = 'Le vendeur', description = quote.refused, type = 'error', icon = 'hand' }) end -- V10
    if quote.greet then
        lib.notify({ title = 'Le vendeur', description = ('Salut %s ! Comme d\'habitude ?%s'):format(quote.greet,
            (quote.discount or 0) > 0 and (' (remise fidélité %d %%)'):format(math.floor(quote.discount * 100)) or ''), icon = 'handshake', type = 'inform' })
    end
    local options = {}
    for _, q in ipairs(quote) do
        options[#options + 1] = {
            title = ('%s  %d $ %s'):format(q.label, q.price, TREND[q.trend]),
            description = q.trend == 1 and 'Forte demande' or (q.trend == -1 and 'Marché saturé' or nil),
            icon = kind == 'sell' and 'hand-holding-dollar' or 'basket-shopping',
            onSelect = function()
                local input = lib.inputDialog(q.label, {
                    { type = 'number', label = 'Quantité', min = 1, max = Config.MaxQuantity, default = 1, required = true },
                })
                if input then
                    local ok, msg
                    if kind == 'sell' then
                        ok, msg = lib.callback.await('gs_economy:sell', false, index, q.item, input[1])
                    else
                        ok, msg = lib.callback.await('gs_economy:buy', false, index, q.item, input[1])
                    end
                    lib.notify({ description = msg, type = ok and 'success' or 'error' })
                end
                -- le menu reste ouvert (prix à jour) : plusieurs achats d'affilée, Échap pour partir
                openMarket(kind, index, place)
            end,
        }
    end
    lib.registerContext({ id = 'gs_economy', title = place.label, options = options })
    lib.showContext('gs_economy')
end

AddEventHandler('gs_economy:client:open', function(kind, i)
    local list = kind == 'sell' and Config.Resellers or Config.Shops
    if list[i] then openMarket(kind, i, list[i]) end
end)

CreateThread(function()
    for kind, list in pairs({ buy = Config.Shops, sell = Config.Resellers }) do
        for i, place in ipairs(list) do
            exports.ox_target:addSphereZone({
                coords = place.coords, radius = Config.InteractRadius,
                options = { {
                    name = ('gs_economy_%s_%d'):format(kind, i),
                    icon = kind == 'sell' and 'fa-solid fa-recycle' or 'fa-solid fa-basket-shopping',
                    label = kind == 'sell' and 'Revendre' or 'Acheter',
                    onSelect = function() openMarket(kind, i, place) end,
                } },
            })
            if place.blip then
                local style = Config.Blips[place.blip] or (kind == 'sell' and Config.Blips.reseller or Config.Blips.shop)
                addBlip(place.coords, style, place.label)
            end
            exports.gs_markers:Add(('gs_economy:%s:%d'):format(kind, i), { coords = place.coords, style = 'shop',
                label = kind == 'sell' and 'Revendre' or 'Acheter', distance = 20.0,
                event = 'gs_economy:client:open', args = { kind, i }, prompt = place.label })
        end
    end
end)
