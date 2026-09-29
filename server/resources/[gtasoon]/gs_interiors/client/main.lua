-- gs_interiors (client) : un marqueur [E] devant chaque porte (dehors et dedans), fondu au noir pendant le passage.
AddEventHandler('gs_interiors:client:use', function(id, side)
    DoScreenFadeOut(300)
    while not IsScreenFadedOut() do Wait(0) end
    local ok, msg = lib.callback.await('gs_interiors:use', false, id, side)
    Wait(600)
    DoScreenFadeIn(400)
    if msg then lib.notify({ description = msg, type = ok and 'inform' or 'error' }) end
end)

CreateThread(function()
    for _, d in ipairs(Config.Doors) do
        exports.gs_markers:Add('gs_interiors:out:' .. d.id, { coords = vec3(d.outside.x, d.outside.y, d.outside.z), style = 'entry',
            label = d.label, event = 'gs_interiors:client:use', args = { d.id, 'outside' }, prompt = 'Entrer · ' .. d.label, distance = 15.0 })
        exports.gs_markers:Add('gs_interiors:in:' .. d.id, { coords = vec3(d.inside.x, d.inside.y, d.inside.z), style = 'entry',
            label = 'Sortie', event = 'gs_interiors:client:use', args = { d.id, 'inside' }, prompt = 'Sortir', distance = 15.0 })
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then exports.gs_markers:RemovePrefix('gs_interiors:') end
end)
