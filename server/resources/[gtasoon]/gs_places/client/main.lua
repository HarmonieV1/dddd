-- gs_places (client) : blips et zones des boutiques de vêtements posées par le staff (les parkings sont gérés par
-- qbx_garages lui-même : blip et point d'accès).
local zones, blips = {}, {}

local function clear()
    for _, z in ipairs(zones) do exports.ox_target:removeZone(z) end
    for _, b in ipairs(blips) do RemoveBlip(b) end
    zones, blips = {}, {}
end

local function build(list)
    clear()
    for _, p in ipairs(list or {}) do
        if p.kind == 'clothing' then
            local k = Config.Kinds.clothing
            local b = AddBlipForCoord(p.x, p.y, p.z)
            SetBlipSprite(b, k.blip.sprite) SetBlipColour(b, k.blip.color) SetBlipScale(b, 0.7) SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(p.label) EndTextCommandSetBlipName(b)
            blips[#blips + 1] = b
            zones[#zones + 1] = exports.ox_target:addSphereZone({ coords = vec3(p.x, p.y, p.z), radius = 3.0, options = { {
                name = 'gs_places_' .. p.key, icon = 'fa-solid fa-shirt', label = 'Essayer des vêtements', distance = 3.0,
                onSelect = function() TriggerEvent('illenium-appearance:client:openClothingShopMenu') end } } })
        end
    end
end

AddStateBagChangeHandler('gsPlaces', 'global', function(_, _, value) build(value) end)
CreateThread(function() Wait(2000) build(GlobalState.gsPlaces) end)
AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then clear() end end)
