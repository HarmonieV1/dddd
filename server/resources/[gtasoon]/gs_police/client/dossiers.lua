-- gs_police (client) : menu « Dossiers » (F4 → Dossiers) : recherche par nom, mandats, rapports. Interface ox_lib.
local function act(name, data) return lib.callback.await('gs_police:action', false, name, nil, data) end
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end

local menu, warrants, reports

local function citizen(index)
    local ok, d = act('dossier_open', { index = index })
    if not ok then return notify(false, d) end
    local options = {
        { title = d.name, icon = 'id-card', readOnly = true, description = ('Né(e) le %s · %s'):format(d.birthdate or '?', d.online and 'en ville' or 'hors ligne') },
        { title = 'Délivrer un mandat', icon = 'gavel', iconColor = '#ff4d6d', onSelect = function()
            local r = lib.inputDialog('Mandat · ' .. d.name, { { type = 'textarea', label = 'Motif', required = true, max = 200, autosize = true } })
            if r then notify(act('warrant_add', { index = index, reason = r[1] })) end
        end },
    }
    for _, w in ipairs(d.warrants) do
        options[#options + 1] = { title = 'MANDAT #' .. w.id, icon = 'triangle-exclamation', iconColor = '#ff4d6d', readOnly = true,
            description = ('%s · %s · %s'):format(w.reason, w.officer, w.date) }
    end
    for _, r in ipairs(d.records) do
        options[#options + 1] = { title = r.charge, icon = 'scale-balanced', readOnly = true,
            description = ('%s · %s%s · %s'):format(r.date, r.fine > 0 and (r.fine .. ' $ ') or '', r.jail > 0 and (r.jail .. ' min') or '', r.officer) }
    end
    lib.registerContext({ id = 'gs_police_citizen', title = 'Dossier', menu = 'gs_police_dossiers', options = options })
    lib.showContext('gs_police_citizen')
end

local function search()
    local r = lib.inputDialog('Rechercher un citoyen', { { type = 'input', label = 'Nom ou prénom', required = true, max = 40 } })
    if not r then return end
    local ok, list = act('dossier_search', { term = r[1] })
    if not ok then return notify(false, list) end
    if #list == 0 then return notify(false, 'Aucun citoyen trouvé.') end
    local options = {}
    for _, c in ipairs(list) do
        options[#options + 1] = { title = c.name, description = 'Né(e) le ' .. (c.birthdate or '?'), icon = 'user', onSelect = function() citizen(c.index) end }
    end
    lib.registerContext({ id = 'gs_police_results', title = 'Résultats', menu = 'gs_police_dossiers', options = options })
    lib.showContext('gs_police_results')
end

warrants = function()
    local ok, list = act('warrants_list')
    if not ok then return notify(false, list) end
    local options = {}
    for _, w in ipairs(list) do
        options[#options + 1] = { title = ('%s · #%d'):format(w.name, w.id), icon = 'gavel', iconColor = '#ff4d6d',
            description = ('%s · %s · %s'):format(w.reason, w.officer, w.date), onSelect = function()
                if lib.alertDialog({ header = 'Clore le mandat #' .. w.id .. ' ?', content = w.name .. ' : ' .. w.reason, centered = true, cancel = true }) == 'confirm' then
                    notify(act('warrant_close', { id = w.id }))
                end
            end }
    end
    if #options == 0 then options[1] = { title = 'Aucun mandat actif', icon = 'circle-check', readOnly = true } end
    lib.registerContext({ id = 'gs_police_warrants', title = 'Mandats actifs (clic = clore)', menu = 'gs_police_dossiers', options = options })
    lib.showContext('gs_police_warrants')
end

local function readReport(id)
    local ok, r = act('report_read', { id = id })
    if not ok then return notify(false, r) end
    lib.registerContext({ id = 'gs_police_report', title = r.title, menu = 'gs_police_reports', options = {
        { title = ('%s · %s'):format(r.officer, r.date), icon = 'user-shield', readOnly = true },
        { title = r.body, icon = 'file-lines', readOnly = true },
        r.image and { title = 'Voir la capture bodycam', icon = 'camera', onSelect = function()
            lib.alertDialog({ header = r.title, content = ('![bodycam](%s)'):format(r.image), centered = true, size = 'xl' })
        end } or { title = 'Pas de capture', icon = 'camera', readOnly = true },
        { title = 'Supprimer ce rapport', icon = 'trash', iconColor = '#ff4d6d', onSelect = function()
            notify(act('report_delete', { id = id }))
        end },
    } })
    lib.showContext('gs_police_report')
end

reports = function()
    local ok, list = act('reports_list')
    if not ok then return notify(false, list) end
    local options = {
        { title = 'Nouveau rapport', icon = 'file-pen', onSelect = function()
            local r = lib.inputDialog('Nouveau rapport', {
                { type = 'input', label = 'Titre', required = true, max = 100 },
                { type = 'textarea', label = 'Contenu', required = true, max = 1500, autosize = true, min = 3 },
            })
            if not r then return end
            local image
            if GetResourceState('gs_phone') == 'started' and lib.alertDialog({ header = 'Bodycam', content = 'Joindre une capture de ta bodycam (ce que tu vois maintenant) ?',
                centered = true, cancel = true, labels = { confirm = 'Capturer', cancel = 'Sans capture' } }) == 'confirm' then
                local err
                image, err = exports.gs_phone:TakePhoto()
                if not image then notify(false, err) end
            end
            notify(act('report_add', { title = r[1], body = r[2], image = image }))
        end },
    }
    for _, x in ipairs(list) do
        options[#options + 1] = { title = x.title, icon = 'file-lines', description = ('%s · %s'):format(x.officer, x.date), onSelect = function() readReport(x.id) end }
    end
    lib.registerContext({ id = 'gs_police_reports', title = 'Rapports', menu = 'gs_police_dossiers', options = options })
    lib.showContext('gs_police_reports')
end

function GSPolice.dossiers()
    lib.registerContext({ id = 'gs_police_dossiers', title = 'Dossiers LSPD', menu = 'gs_police_menu', options = {
        { title = 'Rechercher un citoyen', icon = 'magnifying-glass', onSelect = search },
        { title = 'Mandats actifs', icon = 'gavel', iconColor = '#ff4d6d', onSelect = warrants },
        { title = 'Rapports', icon = 'file-lines', onSelect = reports },
        { title = 'Preuves vidéo (caméras)', icon = 'video', onSelect = function()
            local ok, list = act('evidence_list')
            if not ok then return notify(false, list) end
            local options = {}
            for _, e in ipairs(list) do
                options[#options + 1] = { title = ('%s · %s'):format(e.label, e.camera), icon = 'video', readOnly = true,
                    description = ('%s%s%s'):format(e.date, e.plate and (' · plaque ' .. e.plate) or '', (e.desc and e.desc ~= '') and (' · suspect : ' .. e.desc) or (e.gender and (' · suspect : ' .. e.gender) or '')) }
            end
            if #options == 0 then options[1] = { title = 'Aucune image récente', icon = 'circle-check', readOnly = true } end
            lib.registerContext({ id = 'gs_police_evidence', title = 'Preuves vidéo', menu = 'gs_police_dossiers', options = options })
            lib.showContext('gs_police_evidence')
        end },
    } })
    lib.showContext('gs_police_dossiers')
end
