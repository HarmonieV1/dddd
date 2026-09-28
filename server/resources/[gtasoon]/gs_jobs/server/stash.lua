-- Coffres de job : ox_inventory contrôle le job actif, le grade minimum et la distance à l'ouverture.
function GSJ.stashId(job, index)
    return ('gs_%s_%d'):format(job, index)
end

function GSJ.registerStashes()
    for name, def in pairs(Jobs) do
        for i, s in ipairs(def.points.stash or {}) do
            Bridge:RegisterStash(GSJ.stashId(name, i), s.label or def.label, s.slots or 50, s.weight or 100000,
                { [name] = s.minGrade or 0 }, s.coords)
        end
    end
end

-- Si ox_inventory redémarre, on réenregistre les coffres.
AddEventHandler('onServerResourceStart', function(res)
    if res == 'ox_inventory' then GSJ.registerStashes() end
end)
