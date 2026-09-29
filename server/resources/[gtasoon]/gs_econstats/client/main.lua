-- gs_econstats (client) : /economie (staff) → tableau de bord ox_lib.
local function fmt(n) n = math.floor(tonumber(n) or 0) local s = tostring(math.abs(n)):reverse():gsub('(%d%d%d)', '%1 '):reverse():gsub('^ ', '') return (n < 0 and '-' or '') .. s end

RegisterCommand('economie', function()
    local d = lib.callback.await('gs_econstats:dashboard', false)
    if not d then return lib.notify({ description = 'Réservé au staff (admin).', type = 'error' }) end
    local options = {
        { title = ('Aujourd\'hui : %s%s $ net'):format(d.net >= 0 and '+' or '', fmt(d.net)), icon = 'scale-balanced', iconColor = d.net > 0 and '#ff8a3d' or '#5aff8c', readOnly = true,
          description = ('Créé %s $ · détruit %s $'):format(fmt(d.created), fmt(d.destroyed)) },
        { title = ('Masse monétaire : %s $'):format(fmt(d.supply)), icon = 'sack-dollar', readOnly = true,
          description = ('Inflation sur 7 jours : %+.1f %%'):format(d.inflation7) },
        { title = ('Indice des prix : %.2f'):format(d.priceIndex), icon = 'chart-line', readOnly = true, description = '1,00 = prix d\'équilibre des commerces' },
    }
    for _, s in ipairs(d.sources) do options[#options + 1] = { title = ('+ %s $ · %s'):format(fmt(s.amount), s.reason), icon = 'arrow-trend-up', iconColor = '#ff8a3d', readOnly = true } end
    for _, s in ipairs(d.sinks) do options[#options + 1] = { title = ('− %s $ · %s'):format(fmt(s.amount), s.reason), icon = 'arrow-trend-down', iconColor = '#5aff8c', readOnly = true } end
    for i, r in ipairs(d.richest) do options[#options + 1] = { title = ('%d. %s'):format(i, r.name), description = fmt(r.total) .. ' $', icon = 'crown', readOnly = true } end
    lib.registerContext({ id = 'gs_econstats', title = 'Économie du serveur', options = options })
    lib.showContext('gs_econstats')
end, false)
