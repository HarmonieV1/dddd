-- gs_auction (serveur) · V10.1 « Enchères de la fourrière ». Lots : saisies déposées par la police + véhicules sans
-- propriétaire envoyés à la fourrière. Chaque samedi soir (ou ouverture par le staff), on enchérit : la mise est bloquée
-- en banque, remboursée dès qu'on est dépassé. À la clôture : le lot au gagnant (même hors ligne : livré à la connexion),
-- la recette à la caisse de la police. Tout est décidé ici ; le client n'envoie qu'un numéro de lot et un montant.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Auction = { lots = {}, nextId = 1, forcedUntil = 0, wasOpen = false }

local function now() return os.time() end
local function started(r) return GetResourceState(r) == 'started' end
local function onDuty(src) return started('gs_jobs') and exports.gs_jobs:IsOnDutyAs(src, Config.PoliceJob) == true end

local function save()
    SetResourceKvp('auction:lots', json.encode(Auction.lots))
    SetResourceKvpInt('auction:next', Auction.nextId)
end
local function loadLots()
    local ok, l = pcall(json.decode, GetResourceKvpString('auction:lots') or '[]')
    Auction.lots = ok and type(l) == 'table' and l or {}
    Auction.nextId = math.max(1, GetResourceKvpInt('auction:next'))
end

-- Dû à un joueur hors ligne (remboursements, lots gagnés) : livré à sa prochaine connexion
local function owedKey(cid) return 'auction:owed:' .. cid end
local function owed(cid)
    local ok, o = pcall(json.decode, GetResourceKvpString(owedKey(cid)) or '[]')
    return ok and type(o) == 'table' and o or {}
end
local function addOwed(cid, entry)
    local o = owed(cid)
    o[#o + 1] = entry
    SetResourceKvp(owedKey(cid), json.encode(o))
end

local function give(src, e)
    if e.money then return Bridge:AddMoney(src, Config.Account, e.money, 'remboursement enchère') end
    if e.item then return Bridge:AddItem(src, e.item, e.count or 1) end
    if e.model then return Bridge:GiveVehicle(src, e.model) end
    return true
end

--- Rend / livre à un personnage (en ligne : tout de suite ; sinon à la connexion)
local function deliver(cid, e, note)
    local src = Bridge:GetSourceByIdentifier(cid)
    if src and give(src, e) then
        if note then Bridge:Notify(src, note, 'inform') end
        return true
    end
    addOwed(cid, e)
    return false
end

function Auction.window(t)
    local d = os.date('*t', t or now())
    if d.wday ~= Config.Day then return false end
    local m = d.hour * 60 + d.min - Config.Hour * 60
    return m >= 0 and m < Config.Minutes
end
function Auction.isOpen() return Auction.window() or now() < Auction.forcedUntil end

local function minBid(lot)
    if not lot.bid then return lot.start end
    return lot.bid.amount + math.max(Config.MinStep, math.ceil(lot.bid.amount * Config.StepPct))
end

local function find(id) for i, l in ipairs(Auction.lots) do if l.id == id then return l, i end end end

local function addLot(lot)
    if #Auction.lots >= Config.MaxLots then return false, 'Plus de place dans la salle des ventes.' end
    lot.id, lot.added, lot.weeks = Auction.nextId, now(), 0
    Auction.nextId = Auction.nextId + 1
    Auction.lots[#Auction.lots + 1] = lot
    save()
    return lot
end

--- Saisie déposée par un policier en service (pas d'armes ni de munitions)
function Auction.deposit(src, item, count, start)
    if not onDuty(src) then return false, 'Réservé à la police en service.' end
    if not Security:InRange(src, Config.Point, Config.DepositRange) then return false, 'Les saisies se déposent à la fourrière.' end
    item, count, start = tostring(item or ''), math.floor(tonumber(count) or 0), math.floor(tonumber(start) or 0)
    if item == '' or item:upper():find('^WEAPON_') or item:lower():find('ammo') then return false, 'Les armes et munitions sont détruites, pas vendues.' end
    if count < 1 or count > 100 then return false, 'Quantité invalide.' end
    if start < Config.MinStart then return false, ('Mise de départ : au moins %d $.'):format(Config.MinStart) end
    if #Auction.lots >= Config.MaxLots then return false, 'Plus de place dans la salle des ventes.' end
    if not Bridge:RemoveItem(src, item, count) then return false, 'Tu n\'as pas ça sur toi.' end
    local label = item
    pcall(function() local d = exports.ox_inventory:Items(item) label = d and d.label or item end) -- [API] ox_inventory
    addLot({ kind = 'item', item = item, count = count, label = ('%s ×%d'):format(label, count), start = start, by = Bridge:GetName(src) })
    Security:LogStaff(('[Enchères] %s dépose %s ×%d (départ %d $)'):format(Bridge:GetName(src) or src, item, count, start), 'jobs')
    return true, 'Saisie mise aux enchères.'
end

--- Véhicule sans propriétaire envoyé à la fourrière (événement de gs_police)
function Auction.vehicle(hash, plate)
    local vehicles = 0
    for _, l in ipairs(Auction.lots) do if l.kind == 'vehicle' then vehicles = vehicles + 1 end end
    if vehicles >= Config.MaxVehicles then return false end
    local ok, list = pcall(function() return exports.qbx_core:GetVehiclesByHash() end) -- [API] qbx_core
    local v = ok and type(list) == 'table' and list[hash] or nil
    if not v or not v.model or v.category == 'emergency' then return false end
    local price = Bridge:GetVehiclePrice(v.model)
    if not price or price <= 0 then return false end
    return addLot({ kind = 'vehicle', model = v.model, label = ('%s (plaque %s)'):format(v.name or v.model, tostring(plate or '?'):gsub('%s+$', '')),
        start = math.max(Config.MinStart, math.floor(price * Config.VehicleStart)) }) ~= false
end

--- Enchérir : mise bloquée en banque, l'ancien meilleur enchérisseur est remboursé
function Auction.bid(src, id, amount)
    if not Auction.isOpen() then return false, 'Les enchères ont lieu le samedi à 21 h.' end
    local lot = find(tonumber(id) or -1)
    if not lot then return false, 'Lot introuvable.' end
    amount = math.floor(tonumber(amount) or 0)
    local min = minBid(lot)
    if amount < min then return false, ('Mise minimum : %d $.'):format(min) end
    local cid = Bridge:GetIdentifier(src)
    if not cid then return false end
    if lot.bid and lot.bid.cid == cid then return false, 'Tu es déjà le meilleur enchérisseur.' end
    if not Bridge:RemoveMoney(src, Config.Account, amount, 'enchère fourrière') then return false, 'Pas assez d\'argent en banque.' end
    local prev = lot.bid
    lot.bid = { cid = cid, name = Bridge:GetName(src) or '?', amount = amount }
    save()
    if prev then deliver(prev.cid, { money = prev.amount }, ('Enchère dépassée sur « %s » : %d $ remboursés.'):format(lot.label, prev.amount)) end
    return true, ('Tu mènes : %d $ sur « %s ».'):format(amount, lot.label)
end

--- Clôture : lots aux gagnants, recette à la police ; invendus remis la semaine suivante (moins cher)
function Auction.settle()
    local keep, total = {}, 0
    for _, lot in ipairs(Auction.lots) do
        if lot.bid then
            local e = lot.kind == 'vehicle' and { model = lot.model } or { item = lot.item, count = lot.count }
            deliver(lot.bid.cid, e, ('Adjugé ! « %s » est à toi.'):format(lot.label))
            total = total + lot.bid.amount
        else
            lot.weeks = (lot.weeks or 0) + 1
            if lot.weeks < Config.MaxWeeks then
                lot.start = math.max(Config.MinStart, math.floor(lot.start * Config.UnsoldFactor))
                keep[#keep + 1] = lot
            end
        end
    end
    Auction.lots = keep
    save()
    if total > 0 and started('gs_jobs') then pcall(function() exports.gs_jobs:AddSocietyMoney(Config.PoliceJob, total, false) end) end
    return total
end

local function announce(text)
    for _, s in ipairs(Bridge:GetPlayers() or {}) do Bridge:Notify(s, text, 'inform') end
    if started('gs_social') then pcall(function() exports.gs_social:Newsroom('encheres', text) end) end
end

function Auction.tick()
    local open = Auction.isOpen()
    if open and not Auction.wasOpen and #Auction.lots > 0 then
        announce(('Enchères de la fourrière ouvertes (%d lots) : /encheres ou à la fourrière de Davis.'):format(#Auction.lots))
    end
    if not open then
        local pending = false
        for _, l in ipairs(Auction.lots) do if l.bid then pending = true break end end
        if pending then
            local total = Auction.settle()
            announce(('Enchères terminées : %d $ reversés à la police de Los Santos.'):format(total))
        end
    end
    Auction.wasOpen = open
end

function Auction.list(src)
    local cid = Bridge:GetIdentifier(src)
    local out = {}
    for _, l in ipairs(Auction.lots) do
        out[#out + 1] = { id = l.id, kind = l.kind, label = l.label, start = l.start, bid = l.bid and l.bid.amount or nil,
            mine = l.bid ~= nil and l.bid.cid == cid, min = minBid(l) }
    end
    return { open = Auction.isOpen(), lots = out, police = onDuty(src), staff = IsPlayerAceAllowed(tostring(src), 'command') }
end

lib.callback.register('gs_auction:list', function(src)
    if not Security:RateLimit(src, 'gs_auction:list', 6, 10000) then return nil end
    return Auction.list(src)
end)
lib.callback.register('gs_auction:bid', function(src, id, amount)
    if not Security:RateLimit(src, 'gs_auction:bid', 4, 5000) then return false, 'Doucement.' end
    return Auction.bid(src, id, amount)
end)
lib.callback.register('gs_auction:deposit', function(src, item, count, start)
    if not Security:RateLimit(src, 'gs_auction:deposit', 3, 5000) then return false, 'Doucement.' end
    return Auction.deposit(src, item, count, start)
end)
lib.callback.register('gs_auction:staff', function(src, open)
    if not Security:RateLimit(src, 'gs_auction:staff', 3, 5000) then return false, 'Doucement.' end
    if not IsPlayerAceAllowed(tostring(src), 'command') then return false, 'Réservé au staff.' end
    Auction.forcedUntil = open and (now() + Config.Minutes * 60) or 0
    Auction.tick()
    return true, open and 'Enchères ouvertes pour 30 min.' or 'Enchères closes.'
end)

AddEventHandler('gs_police:server:impounded', function(hash, plate) Auction.vehicle(hash, plate) end)

AddEventHandler('gs_bridge:server:playerLoaded', function(src)
    local cid = Bridge:GetIdentifier(src)
    if not cid then return end
    local o = owed(cid)
    if #o == 0 then return end
    DeleteResourceKvp(owedKey(cid))
    local left = {}
    for _, e in ipairs(o) do if not give(src, e) then left[#left + 1] = e end end
    if #left > 0 then SetResourceKvp(owedKey(cid), json.encode(left)) end
    Bridge:Notify(src, 'Fourrière : tes enchères t\'attendaient (lots gagnés ou remboursements).', 'inform')
end)

CreateThread(function()
    loadLots()
    while true do Auction.tick() Wait(30000) end
end)
