-- gs_econstats (serveur) : écoute chaque mouvement d'argent de Qbox, classe par source (motif), cumule en mémoire et écrit
-- en base une fois par minute. /economie (staff) : rapport du jour, masse monétaire, inflation, fortunes.
local Security = exports.gs_security

Econ = { pending = {}, lastReportDay = nil } -- pending[day .. '|' .. reason] = { day, reason, created, destroyed }

local function today() return os.date('%Y-%m-%d') end

--- Motif → catégorie courte (sans chiffres ni plaques) ou nil si mouvement neutre (entre joueurs).
function Econ.category(reason)
    reason = type(reason) == 'string' and reason:lower() or 'inconnu'
    for _, w in ipairs(Config.NeutralReasons) do
        if reason:find(w, 1, true) then return nil end
    end
    reason = reason:gsub('%d', ''):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    return (reason ~= '' and reason or 'inconnu'):sub(1, 40)
end

function Econ.record(moneyType, amount, action, reason)
    amount = tonumber(amount)
    if moneyType ~= 'cash' and moneyType ~= 'bank' then return end
    if not amount or amount <= 0 or (action ~= 'add' and action ~= 'remove') then return end
    local cat = Econ.category(reason)
    if not cat then return end
    local key = today() .. '|' .. cat
    local e = Econ.pending[key] or { today(), cat, 0, 0 }
    if action == 'add' then e[3] = e[3] + math.floor(amount) else e[4] = e[4] + math.floor(amount) end
    Econ.pending[key] = e
end

AddEventHandler('QBCore:Server:OnMoneyChange', function(_, moneyType, amount, action, reason) -- [API] qbx_core
    Econ.record(moneyType, amount, action, reason)
end)

function Econ.flush()
    local rows = {}
    for _, e in pairs(Econ.pending) do rows[#rows + 1] = e end
    Econ.pending = {}
    if #rows > 0 then Store.add(rows) end
end

local function priceIndex()
    return GetResourceState('gs_economy') == 'started' and exports.gs_economy:GetPriceIndex() or 1.0
end

--- Rapport d'une journée : { created, destroyed, net, sources = { top créations }, sinks = { top destructions } }
function Econ.report(day)
    Econ.flush()
    local rows = Store.day(day)
    local created, destroyed = 0, 0
    local sources, sinks = {}, {}
    for _, r in ipairs(rows) do
        created, destroyed = created + r.created, destroyed + r.destroyed
        if r.created > 0 then sources[#sources + 1] = { reason = r.reason, amount = r.created } end
        if r.destroyed > 0 then sinks[#sinks + 1] = { reason = r.reason, amount = r.destroyed } end
    end
    table.sort(sources, function(a, b) return a.amount > b.amount end)
    table.sort(sinks, function(a, b) return a.amount > b.amount end)
    for i = #sources, 6, -1 do sources[i] = nil end
    for i = #sinks, 6, -1 do sinks[i] = nil end
    return { day = day, created = created, destroyed = destroyed, net = created - destroyed, sources = sources, sinks = sinks }
end

--- Tableau complet pour le staff.
function Econ.dashboard()
    local rep = Econ.report(today())
    local supply = Store.supply()
    local hist = Store.supplyHistory(8)
    local week = hist[#hist]
    rep.supply = supply
    rep.inflation7 = (week and week.supply > 0) and ((supply - week.supply) / week.supply * 100) or 0
    rep.priceIndex = priceIndex()
    rep.richest = {}
    for i, r in ipairs(Store.richest(10)) do rep.richest[i] = { name = ('%s %s'):format(r.firstname or '?', r.lastname or '?'), total = r.total } end
    return rep
end

lib.callback.register('gs_econstats:dashboard', function(src)
    if not Security:RateLimit(src, 'gs_econstats:dashboard', 3, 10000) then return nil end
    if not IsPlayerAceAllowed(src, Config.Ace) then return nil end
    return Econ.dashboard()
end)

--- Une fois par jour : masse monétaire du jour + rapport de la veille sur Discord (staff), alerte si création anormale.
function Econ.daily()
    local day = today()
    Store.saveSupply(day, Store.supply(), priceIndex())
    if tonumber(os.date('%H')) < Config.ReportHour or Econ.lastReportDay == day then return end
    Econ.lastReportDay = day
    local y = os.date('%Y-%m-%d', os.time() - 86400)
    local r = Econ.report(y)
    local msg = ('[Économie] %s : créé %d $, détruit %d $, net %+d $'):format(y, r.created, r.destroyed, r.net)
    if r.sources[1] then msg = msg .. (' · 1re source : %s (%d $)'):format(r.sources[1].reason, r.sources[1].amount) end
    Security:LogStaff(msg)
    if r.net > Config.AlertNetPerDay then Security:LogStaff('⚠️ [Économie] création nette anormale hier : vérifier les sources (exploit ?)') end
end

CreateThread(function()
    Store.init()
    local n = 0
    while true do
        Wait(Config.FlushSeconds * 1000)
        Econ.flush()
        n = n + 1
        if n % 15 == 1 then Econ.daily() end -- toutes les 15 min : instantané du jour, rapport si l'heure est passée
    end
end)
