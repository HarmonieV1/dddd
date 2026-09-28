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
                if not input then return end
                local ok, msg
                if kind == 'sell' then
                    ok, msg = lib.callback.await('gs_economy:sell', false, index, q.item, input[1])
                else
                    ok, msg = lib.callback.await('gs_economy:buy', false, index, q.item, input[1])
                end
                lib.notify({ description = msg, type = ok and 'success' or 'error' })
            end,
        }
    end
    lib.registerContext({ id = 'gs_economy', title = place.label, options = options })
    lib.showContext('gs_economy')
end

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
            if place.blip then addBlip(place.coords, kind == 'sell' and Config.Blips.reseller or Config.Blips.shop, place.label) end
        end
    end
end)
