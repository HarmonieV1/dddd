-- gs_social (client) : /journal, le journal Weazel News écrit par les joueurs journalistes.
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error', duration = 7000 }) end end

local function write()
    local r = lib.inputDialog('Weazel News · nouvel article', {
        { type = 'input', label = 'Titre', required = true, min = Config.Journal.titleMin, max = Config.Journal.titleMax },
        { type = 'textarea', label = 'Article', required = true, autosize = true, min = Config.Journal.bodyMin, max = Config.Journal.bodyMax },
    })
    if not r then return end
    notify(lib.callback.await('gs_social:journal:publish', false, r[1], r[2]))
end

local function read(id)
    local a = lib.callback.await('gs_social:journal:read', false, id)
    if not a then return notify(false, 'Article introuvable.') end
    lib.alertDialog({ header = '📰 ' .. a.title, size = 'lg', centered = true, cancel = false,
        content = ('%s\n\n— %s · %s'):format(a.body, a.author, a.date) })
end

RegisterCommand('journal', function()
    local d = lib.callback.await('gs_social:journal:list', false)
    if not d then return end
    local options = {}
    if d.press then options[1] = { title = 'Écrire un article', icon = 'pen-nib', iconColor = '#ff5a5a', description = 'Publié pour toute la ville, payé à la rédaction', onSelect = write } end
    for _, a in ipairs(d.articles) do
        options[#options + 1] = { title = a.title, icon = 'newspaper', description = ('%s · %s'):format(a.author, a.date),
            onSelect = function() read(a.id) end }
    end
    if #d.articles == 0 then options[#options + 1] = { title = 'Aucun article pour le moment', readOnly = true, icon = 'newspaper' } end
    lib.registerContext({ id = 'gs_social_journal', title = 'Weazel News · le journal de Los Santos', options = options })
    lib.showContext('gs_social_journal')
end, false)
