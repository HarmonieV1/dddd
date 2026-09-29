-- gs_reputation (client) : /reputation → les trois jauges et leurs effets.
RegisterCommand('reputation', function()
    local r = lib.callback.await('gs_reputation:get', false)
    if not r then return end
    local function row(title, icon, k, color, extra)
        return { title = ('%s : %s'):format(title, r[k].tier), description = ('%d / 1000%s'):format(r[k].value, extra or ''), icon = icon,
            progress = math.floor(r[k].value / 10), colorScheme = color, readOnly = true }
    end
    lib.registerContext({ id = 'gs_reputation', title = 'Réputation', options = {
        row('Légale', 'scale-balanced', 'legal', 'green', r.discount > 0 and (' · remise commerces %d %%'):format(math.floor(r.discount * 100)) or ''),
        row('Rue', 'mask', 'street', 'red', r.streetBonus > 0 and (' · meilleurs prix de vente « discrète » +%d %%'):format(math.floor(r.streetBonus * 100)) or ''),
        row('Média', 'hashtag', 'media', 'pink', ' · likes reçus sur Vibe'),
    } })
    lib.showContext('gs_reputation')
end, false)
