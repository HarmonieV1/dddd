-- gs_heists (client) : zones ox_target sur chaque point, barre de progression, rien d'autre (0 boucle).
local zones = {}
local UNARMED = GetHashKey('WEAPON_UNARMED')

local function loot(id, point, site)
    local ok, res = lib.callback.await('gs_heists:begin', false, id, point)
    if not ok then return lib.notify({ description = res, type = 'error' }) end
    local done = lib.progressBar({
        duration = res, label = site.verb, canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'anim@heists@prison_heiststation@cop_reactions', clip = 'cop_b_idle' },
    })
    if not done then return TriggerServerEvent('gs_heists:server:cancel') end
    local success, msg = lib.callback.await('gs_heists:finish', false)
    lib.notify({ description = msg, type = success and 'success' or 'error', duration = 7000 })
end

CreateThread(function()
    for id, site in pairs(Config.Sites) do
        for i, coords in ipairs(site.points) do
            zones[#zones + 1] = exports.ox_target:addSphereZone({
                coords = coords, radius = 0.8,
                options = { {
                    name = ('gs_heist_%s_%d'):format(id, i), icon = 'fa-solid fa-sack-dollar', label = site.verb,
                    canInteract = function() return GetSelectedPedWeapon(cache.ped) ~= UNARMED end,
                    onSelect = function() loot(id, i, site) end,
                } },
            })
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, z in ipairs(zones) do exports.ox_target:removeZone(z) end
end)
