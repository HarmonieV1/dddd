-- gs_interiors (client) : un marqueur [E] devant chaque porte AUTORISÉE (dehors et dedans), fondu au noir pendant le passage.
-- Les labos / club-house restent invisibles pour ceux qui n'y ont pas accès (le serveur revérifie à chaque passage).
local blips = {}

AddEventHandler('gs_interiors:client:use', function(id, side)
    DoScreenFadeOut(300)
    while not IsScreenFadedOut() do Wait(0) end
    local ok, msg = lib.callback.await('gs_interiors:use', false, id, side)
    Wait(600)
    DoScreenFadeIn(400)
    if msg then lib.notify({ description = msg, type = ok and 'inform' or 'error' }) end
end)

local function refresh()
    exports.gs_markers:RemovePrefix('gs_interiors:')
    for _, b in ipairs(blips) do RemoveBlip(b) end
    blips = {}
    local allowed = {}
    for _, id in ipairs(lib.callback.await('gs_interiors:allowed', false) or {}) do allowed[id] = true end
    for _, d in ipairs(Config.Doors) do
        if allowed[d.id] then
            exports.gs_markers:Add('gs_interiors:out:' .. d.id, { coords = vec3(d.outside.x, d.outside.y, d.outside.z), style = 'entry',
                label = d.label, event = 'gs_interiors:client:use', args = { d.id, 'outside' }, prompt = 'Entrer · ' .. d.label, distance = 15.0 })
            exports.gs_markers:Add('gs_interiors:in:' .. d.id, { coords = vec3(d.inside.x, d.inside.y, d.inside.z), style = 'entry',
                label = 'Sortie', event = 'gs_interiors:client:use', args = { d.id, 'inside' }, prompt = 'Sortir', distance = 15.0 })
            if d.blip then
                local b = AddBlipForCoord(d.outside.x, d.outside.y, d.outside.z)
                SetBlipSprite(b, d.blip.sprite) SetBlipColour(b, d.blip.color) SetBlipScale(b, 0.8) SetBlipAsShortRange(b, true)
                BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName(d.label) EndTextCommandSetBlipName(b)
                blips[#blips + 1] = b
            end
        end
    end
end

-- Rafraîchi à la connexion, au changement de job ou de gang (petit délai : le serveur a fini d'appliquer)
local pending = false
local function later()
    if pending then return end
    pending = true
    SetTimeout(1500, function() pending = false refresh() end)
end
AddEventHandler('gs_bridge:client:playerLoaded', later)
AddEventHandler('gs_bridge:client:jobUpdated', later)
RegisterNetEvent('gs_gangs:client:membership', later)
CreateThread(later)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        exports.gs_markers:RemovePrefix('gs_interiors:')
        for _, b in ipairs(blips) do RemoveBlip(b) end
    end
end)
