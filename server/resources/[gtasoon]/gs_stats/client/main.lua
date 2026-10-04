-- gs_stats (client) : /recap → ton mois à Los Santos (ce mois-ci, le mois dernier, ta biographie depuis ton arrivée).
local NAMES = { minutes = 'du temps passé en ville', meters = 'des kilomètres au volant' }

local function show(which)
    local v = lib.callback.await('gs_stats:recap', false, which)
    if not v then return lib.notify({ description = 'Rien pour le moment.', type = 'error' }) end
    local md = { ('## %s'):format(v.label:gsub('^%l', string.upper)), ('### « %s »'):format(v.title), '' }
    if v.since then md[#md + 1] = ('*À Los Santos depuis le %s*'):format(v.since) md[#md + 1] = '' end
    if #v.lines == 0 then md[#md + 1] = 'Pas encore d\'histoire à raconter : la ville t\'attend.' end
    for _, l in ipairs(v.lines) do md[#md + 1] = ('**%s** · %s  '):format(l.value, l.label) end
    for _, r in ipairs(v.ranks) do md[#md + 1] = '' md[#md + 1] = ('🏆 Top **%d %%** %s'):format(r.top, NAMES[r.stat] or r.stat) end
    lib.alertDialog({ header = ('Récap RoadLine · %s'):format(v.name or ''), content = table.concat(md, '\n'), centered = true, size = 'md' })
end

RegisterCommand('recap', function()
    lib.registerContext({ id = 'gs_recap', title = 'Récap RoadLine', options = {
        { title = 'Ce mois-ci', icon = 'calendar-day', onSelect = function() show('month') end },
        { title = 'Le mois dernier', icon = 'calendar-check', onSelect = function() show('last') end },
        { title = 'Ma biographie (depuis mon arrivée)', icon = 'book-open', onSelect = function() show('all') end },
    } })
    lib.showContext('gs_recap')
end, false)
