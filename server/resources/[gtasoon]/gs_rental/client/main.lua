-- gs_rental (client) : comptoirs (blip + marqueur + ox_target) et menu de location. 0 boucle.
local zones, blips = {}, {}

local function openMenu(pointId)
    local status = lib.callback.await('gs_rental:status', false)
    local options = {}
    if status then
        options[#options + 1] = {
            title = 'Rendre mon véhicule', icon = 'rotate-left', iconColor = '#ff2e88',
            description = ('Location en cours : %d min restantes'):format(math.ceil(status.left / 60)),
            onSelect = function()
                local ok, msg = lib.callback.await('gs_rental:return', false, pointId)
                lib.notify({ description = msg, type = ok and 'success' or 'error' })
            end,
        }
    end
    for i, v in ipairs(Config.Vehicles) do
        options[#options + 1] = {
            title = v.label, icon = v.type == 'bike' and 'bicycle' or 'car', disabled = status ~= nil,
            description = ('%d $ · %d min'):format(v.price, v.minutes),
            onSelect = function()
                local ok, msg = lib.callback.await('gs_rental:rent', false, pointId, i)
                lib.notify({ description = msg, type = ok and 'success' or 'error' })
            end,
        }
    end
    lib.registerContext({ id = 'gs_rental', title = Config.Points[pointId].label, options = options })
    lib.showContext('gs_rental')
end

CreateThread(function()
    for i, p in ipairs(Config.Points) do
        zones[#zones + 1] = exports.ox_target:addSphereZone({ coords = p.coords, radius = 1.5, options = { {
            name = 'gs_rental_' .. i, icon = 'fa-solid fa-bicycle', label = 'Louer un véhicule',
            onSelect = function() openMenu(i) end,
        } } })
        exports.gs_markers:Add('gs_rental:' .. i, { coords = p.coords, style = 'rental', label = 'Location', icon = 38 })
        local b = AddBlipForCoord(p.coords.x, p.coords.y, p.coords.z)
        SetBlipSprite(b, Config.Blip.sprite)
        SetBlipColour(b, Config.Blip.color)
        SetBlipScale(b, Config.Blip.scale)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Location de véhicules')
        EndTextCommandSetBlipName(b)
        blips[#blips + 1] = b
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, z in ipairs(zones) do exports.ox_target:removeZone(z) end
    for _, b in ipairs(blips) do RemoveBlip(b) end
    exports.gs_markers:RemovePrefix('gs_rental:')
end)
