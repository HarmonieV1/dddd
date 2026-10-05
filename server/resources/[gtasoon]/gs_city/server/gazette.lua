-- gs_city (serveur) · V11.2 « La Gazette du dimanche ». Compteurs de la semaine (KVP, survivent aux redémarrages),
-- édition composée toute seule et publiée le dimanche soir. Rien de privé : quartiers, nombres, textes déjà publics.
local G = Config.Gazette
Gazette = { week = nil, last = nil, number = 0 }

local function weekKey(t) return os.date('%Y-%W', t or os.time()) end
local function fresh() return { key = weekKey(), crimes = {}, faitsdivers = 0, fdKinds = {}, rumeurs = {}, guilty = 0, acquitted = 0,
    juries = 0, legends = {}, plaques = {}, blackouts = {} } end
local function save()
    SetResourceKvp('gazette:week', json.encode(Gazette.week))
    if Gazette.last then SetResourceKvp('gazette:last', json.encode(Gazette.last)) end
    SetResourceKvpInt('gazette:number', Gazette.number)
end
local function week()
    if not Gazette.week then Gazette.week = fresh() end
    return Gazette.week
end
local function push(list, v, max) list[#list + 1] = v while #list > (max or 6) do table.remove(list, 1) end end
local function label(id) for _, d in ipairs(Config.Districts) do if d.id == id then return d.label end end return id end

function Gazette.record(kind, a, b)
    local w = week()
    if kind == 'crime' then
        local d = a and City.district(a)
        if d then w.crimes[d.id] = (w.crimes[d.id] or 0) + 1 end
    elseif kind == 'faitdivers' then w.faitsdivers = w.faitsdivers + 1 if a then w.fdKinds[a] = (w.fdKinds[a] or 0) + 1 end
    elseif kind == 'rumeur' then push(w.rumeurs, tostring(a or ''), 4)
    elseif kind == 'verdict' then if a == 'guilty' then w.guilty = w.guilty + 1 else w.acquitted = w.acquitted + 1 end
    elseif kind == 'jury' then w.juries = w.juries + 1
    elseif kind == 'legende' then push(w.legends, tostring(a or '?'), 3)
    elseif kind == 'plaque' then push(w.plaques, tostring(a or ''), 4)
    elseif kind == 'blackout' then push(w.blackouts, a, 6) end
    save()
end

--- Compose une édition à partir des compteurs d'une semaine
function Gazette.compose(w, number, at)
    local hot, hotN, total = nil, 0, 0
    for id, n in pairs(w.crimes) do total = total + n if n > hotN then hot, hotN = id, n end end
    local calm
    for _, d in ipairs(Config.Districts) do if not w.crimes[d.id] and d.id ~= 'paleto' and d.id ~= 'sandy' then calm = d.label break end end
    local headline, lead
    if w.legends[1] then headline, lead = ('%s entre dans la légende'):format(w.legends[#w.legends]), 'La cavale a tenu jusqu\'au bout : la ville n\'en revient pas.'
    elseif #w.blackouts > 0 then headline, lead = ('Nuit noire à %s'):format(label(w.blackouts[#w.blackouts])), 'Un transformateur saboté a plongé le quartier dans le noir.'
    elseif hot and hotN >= 5 then headline, lead = ('%s sous tension'):format(label(hot)), ('%d incidents signalés en une semaine dans le quartier.'):format(hotN)
    elseif w.juries > 0 then headline, lead = 'Le peuple a jugé', ('%d jury(s) populaire(s) ont tranché cette semaine.'):format(w.juries)
    else headline, lead = 'Une semaine tranquille à Los Santos', 'Les commerçants respirent, la police aussi… pour combien de temps ?' end
    local sections = {}
    local function sec(title, items) if #items > 0 then sections[#sections + 1] = { title = title, items = items } end end
    local crime = {}
    if total > 0 then crime[#crime + 1] = ('%d incident(s) signalé(s) à la police%s.'):format(total, hot and (', surtout à ' .. label(hot)) or '') end
    if calm then crime[#crime + 1] = ('Quartier le plus calme : %s.'):format(calm) end
    if w.faitsdivers > 0 then crime[#crime + 1] = ('%d fait(s) divers ont occupé le LSPD.'):format(w.faitsdivers) end
    for _, id in ipairs(w.blackouts) do crime[#crime + 1] = ('Panne de courant à %s.'):format(label(id)) end
    sec('Faits divers', crime)
    local court = {}
    if w.guilty + w.acquitted > 0 then court[#court + 1] = ('%d verdict(s) : %d condamnation(s), %d relaxe(s).'):format(w.guilty + w.acquitted, w.guilty, w.acquitted) end
    if w.juries > 0 then court[#court + 1] = ('%d jury(s) de citoyens tirés au sort.'):format(w.juries) end
    sec('Au tribunal', court)
    local mem = {}
    for _, n in ipairs(w.legends) do mem[#mem + 1] = ('Nouvelle légende : %s.'):format(n) end
    for _, p in ipairs(w.plaques) do mem[#mem + 1] = ('Nouvelle plaque : « %s ».'):format(p) end
    sec('Mémoire de la ville', mem)
    local rum = {}
    for _, r in ipairs(w.rumeurs) do rum[#rum + 1] = ('Confirmée : %s.'):format(r) end
    sec('Les rumeurs avaient raison', rum)
    return { number = number, date = os.date('%d/%m/%Y', at or os.time()), name = G.name, headline = headline, lead = lead, sections = sections }
end

function Gazette.markdown(e)
    local out = { ('# %s\n**n°%d · %s**\n\n## %s\n_%s_'):format(e.name, e.number, e.date, e.headline, e.lead) }
    for _, s in ipairs(e.sections) do
        out[#out + 1] = ('\n**%s**'):format(s.title)
        for _, it in ipairs(s.items) do out[#out + 1] = '• ' .. it end
    end
    return table.concat(out, '\n')
end

function Gazette.publish()
    Gazette.number = Gazette.number + 1
    local e = Gazette.compose(week(), Gazette.number)
    e.week = weekKey() -- une seule édition par semaine (même publiée à la main par le staff)
    Gazette.last, Gazette.week = e, fresh()
    save()
    if GetResourceState('gs_discord') == 'started' then
        pcall(function() exports.gs_discord:Announce(('%s · n°%d'):format(e.name, e.number), Gazette.markdown(e):gsub('^# [^\n]+\n', '')) end)
    end
    TriggerClientEvent('chat:addMessage', -1, { args = { e.name, ('n°%d est sortie : « %s ». /%s pour la lire.'):format(e.number, e.headline, G.command) } })
    return e
end

function Gazette.due(t)
    t = t or os.time()
    local d = os.date('*t', t)
    return d.wday - 1 == G.day and d.hour >= G.hour and (not Gazette.last or Gazette.last.week ~= weekKey(t)) and Gazette.week and Gazette.week.key == weekKey(t)
end

lib.callback.register('gs_city:gazette', function(src)
    if not exports.gs_security:RateLimit(src, 'gs_city:gazette', 4, 10000) then return nil end
    return Gazette.last and Gazette.markdown(Gazette.last) or nil, Gazette.markdown(Gazette.compose(week(), Gazette.number + 1))
end)
RegisterCommand(G.command .. 'publier', function(src)
    if src ~= 0 then
        local ok, l = pcall(function() return exports.gs_admin:GetStaffLevel(src) end)
        if not ok or (tonumber(l) or 0) < G.staffLevel then return end
    end
    local e = Gazette.publish()
    if src ~= 0 then exports.gs_bridge:Notify(src, ('Gazette n°%d publiée.'):format(e.number), 'success') end
end, false)

AddEventHandler('gs_wanted:server:reported', function(_, _, _, coords) Gazette.record('crime', coords) end)
AddEventHandler('gs_faitsdivers:server:new', function(kind) Gazette.record('faitdivers', kind) end)
AddEventHandler('gs_rumors:server:realized', function(text) Gazette.record('rumeur', text) end)
AddEventHandler('gs_justice:server:verdict', function(kind) Gazette.record('verdict', kind) end)
AddEventHandler('gs_justice:server:jury', function() Gazette.record('jury') end)
AddEventHandler('gs_wanted:server:legend', function(_, name) Gazette.record('legende', name) end)
AddEventHandler('gs_scars:server:plaque', function(text) Gazette.record('plaque', text) end)
AddEventHandler('gs_city:server:blackout', function(id, on) if on then Gazette.record('blackout', id) end end)

CreateThread(function()
    local ok, w = pcall(json.decode, GetResourceKvpString('gazette:week') or '')
    Gazette.week = (ok and type(w) == 'table' and w.key == weekKey()) and w or fresh()
    local ok2, l = pcall(json.decode, GetResourceKvpString('gazette:last') or '')
    Gazette.last = ok2 and type(l) == 'table' and l or nil
    Gazette.number = GetResourceKvpInt('gazette:number') or 0
    while true do
        if Gazette.week.key ~= weekKey() and not Gazette.due() then Gazette.week = fresh() end -- semaine passée sans édition
        if Gazette.due() then Gazette.publish() end
        Wait(5 * 60000)
    end
end)
