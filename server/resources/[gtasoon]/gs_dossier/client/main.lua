-- gs_dossier (client) · /dossier : rechercher un citoyen par son nom, ouvrir sa fiche (selon ton métier en service).
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end

local function open(cid)
    local ok, d = lib.callback.await('gs_dossier:open', false, cid)
    if not ok then return notify(false, d) end
    local options = {}
    for _, s in ipairs(d.sections) do
        options[#options + 1] = { title = s.title, icon = s.icon, description = table.concat(s.lines, '\n'), readOnly = true }
    end
    lib.registerContext({ id = 'gs_dossier_sheet', title = ('%s · %s'):format(d.label, d.name), menu = 'gs_dossier_results', options = options })
    lib.showContext('gs_dossier_sheet')
end

RegisterCommand(Config.Command, function()
    local r = lib.inputDialog('Dossier d\'un citoyen', { { type = 'input', label = 'Nom ou prénom', required = true, min = 2, max = 40 } })
    if not r then return end
    local ok, list = lib.callback.await('gs_dossier:search', false, r[1])
    if not ok then return notify(false, list) end
    local options = {}
    for _, p in ipairs(list) do
        options[#options + 1] = { title = ('%s %s'):format(p.firstname or '?', p.lastname or ''), icon = 'folder-open', arrow = true,
            onSelect = function() open(p.citizenid) end }
    end
    if #options == 0 then options[1] = { title = 'Personne à ce nom', readOnly = true } end
    lib.registerContext({ id = 'gs_dossier_results', title = 'Résultats', options = options })
    lib.showContext('gs_dossier_results')
end, false)
