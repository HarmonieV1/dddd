-- gs_events (client) · V9 : /rdv → le programme de la semaine (rendez-vous fixes) et l'événement en cours.
RegisterCommand('rdv', function()
    local d = lib.callback.await('gs_events:weekly', false) or {}
    local o = {}
    if d.active then o[1] = { title = 'En ce moment : ' .. d.active, icon = 'champagne-glasses', iconColor = '#f2c230', readOnly = true } end
    local list = {}
    for _, w in ipairs(Config.Weekly) do list[#list + 1] = w end
    table.sort(list, function(a, b) return ((a.day + 5) % 7) < ((b.day + 5) % 7) end) -- lundi en premier
    for _, w in ipairs(list) do
        o[#o + 1] = { title = ('%s %s–%s · %s'):format(Config.Days[w.day], w.from, w.to, w.label), description = w.desc, icon = 'calendar-check', readOnly = true }
    end
    lib.registerContext({ id = 'gs_rdv', title = 'Rendez-vous de la semaine', options = o })
    lib.showContext('gs_rdv')
end, false)
