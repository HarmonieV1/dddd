-- gs_drugs (serveur). Récolte / transformation en 2 temps (durée réelle vérifiée), vente à un PNJ réel
-- (entité réseau, 1 vente par PNJ via state bag), prix calculé ici selon quartier / météo / heure / saturation.
local Security  = exports.gs_security
local Bridge    = exports.gs_bridge
local JobsApi   = exports.gs_jobs
local WantedApi = exports.gs_wanted

Drugs = { pending = {}, sales = {}, enabled = {} } -- sales[zone] = { os.time()... }

local function started(res) return GetResourceState(res) == 'started' end
local function near(src, coords, radius) return Security:InRange(src, coords, radius + Config.Tolerance) end

local function pay(src, amount)
    if Config.DirtyItem and Bridge:ItemExists(Config.DirtyItem) and Bridge:AddItem(src, Config.DirtyItem, amount) then return end
    Bridge:AddMoney(src, 'cash', amount, 'vente')
end

--- Dans un labo de son gang pour cette drogue ? (point de travail + accès vérifié par gs_interiors)
function Drugs.atLab(src, drugId)
    local spots = Config.Labs and Config.Labs[drugId]
    if not spots or not started('gs_interiors') then return false end
    for _, c in ipairs(spots) do
        if near(src, c, 2.0) then return exports.gs_interiors:InLab(src, drugId) end
    end
    return false
end

-- Récolte / transformation ---------------------------------------------------------------------------------

lib.callback.register('gs_drugs:begin', function(src, drugId, stage)
    if not Security:RateLimit(src, 'gs_drugs:begin', 6, 10000) then return false, 'Doucement.' end
    local drug = Drugs.enabled[drugId] and Config.Drugs[drugId]
    local step = drug and (stage == 'harvest' or stage == 'process') and drug[stage]
    if not step then return false, 'Indisponible.' end
    local lab = stage == 'process' and Drugs.atLab(src, drugId)
    if not lab and not near(src, step.center, step.radius) then return false, 'Trop loin.' end
    if Drugs.pending[src] then return false, 'Déjà occupé.' end
    if stage == 'process' and Bridge:GetItemCount(src, step.input) < step.inputCount then
        return false, ('Il te faut %d × %s.'):format(step.inputCount, step.input)
    end
    Drugs.pending[src] = { drug = drugId, stage = stage, lab = lab, doneAt = GetGameTimer() + step.duration - 750 }
    return true, step.duration
end)

lib.callback.register('gs_drugs:finish', function(src)
    if not Security:RateLimit(src, 'gs_drugs:finish', 6, 10000) then return false, 'Doucement.' end
    local p = Drugs.pending[src]
    Drugs.pending[src] = nil
    if not p or GetGameTimer() < p.doneAt then return false, 'Interrompu.' end
    local step = Config.Drugs[p.drug][p.stage]
    if not (p.lab and Drugs.atLab(src, p.drug)) and not near(src, step.center, step.radius) then return false, 'Tu t\'es éloigné.' end
    if p.stage == 'harvest' then
        local n = math.random(step.amount[1], step.amount[2])
        if not Bridge:AddItem(src, step.item, n) then return false, 'Tu ne peux plus rien porter.' end
        if p.drug == 'weed' and Config.Plants and math.random() < Config.Plants.wildSeedChance and Bridge:AddItem(src, Config.Plants.seed, 1) then
            return true, ('+%d %s, et une graine !'):format(n, step.item)
        end
        return true, ('+%d %s'):format(n, step.item)
    end
    local out = step.outputCount * (p.lab and Config.LabBonus or 1)
    if not Bridge:CanCarry(src, step.output, out) then return false, 'Tu ne peux plus rien porter.' end
    if not Bridge:RemoveItem(src, step.input, step.inputCount) then return false, 'Il te manque la matière première.' end
    if not Bridge:AddItem(src, step.output, out) then
        Bridge:AddItem(src, step.input, step.inputCount) -- remboursement
        return false, 'Erreur, matière rendue.'
    end
    return true, ('+%d %s%s'):format(out, step.output, p.lab and ' (labo ×' .. Config.LabBonus .. ')' or '')
end)

RegisterNetEvent('gs_drugs:server:cancel', function()
    if Security:RateLimit(source, 'gs_drugs:cancel', 5, 10000) then Drugs.pending[source] = nil end
end)

-- Vente ----------------------------------------------------------------------------------------------------

local function zoneOf(coords)
    return started('gs_gangs') and exports.gs_gangs:GetTerritoryAt(coords) or 'ville'
end

--- Multiplicateur de saturation : plus on vend dans un quartier, plus le prix baisse.
function Drugs.saturation(zone)
    local list, now = Drugs.sales[zone] or {}, os.time()
    for i = #list, 1, -1 do if now - list[i] > Config.Sell.saturationWindow then table.remove(list, i) end end
    Drugs.sales[zone] = list
    return math.max(Config.Sell.saturationFloor, 1 - #list * Config.Sell.saturationStep)
end

local function policeNear(coords)
    for _, cop in ipairs(JobsApi:GetOnDutyPlayers(Config.PoliceJob)) do
        local ped = GetPlayerPed(cop)
        if ped ~= 0 and #(GetEntityCoords(ped) - coords) <= Config.Sell.policeNearby then return true end
    end
    return false
end

--- Prix unitaire final et raison du refus éventuel.
function Drugs.quote(src, drug, coords)
    local cfg = Config.Sell
    local m = Drugs.saturation(zoneOf(coords))
    local refuse = cfg.refuseChance
    if started('gs_weather') then
        local hour = exports.gs_weather:GetGameTime()
        if hour >= 22 or hour < 5 then m = m * cfg.nightBonus end
        local w = exports.gs_weather:GetWeather()
        if w == 'RAIN' or w == 'THUNDER' then refuse = refuse + cfg.rainRefuse end
    end
    if started('gs_gangs') then
        local gang = exports.gs_gangs:GetGang(src)
        local zone = exports.gs_gangs:GetTerritoryAt(coords)
        local owner = zone and exports.gs_gangs:GetTerritoryOwner(zone)
        if owner and gang and owner == gang then m = m * cfg.ownTerritory
        elseif owner then m = m * cfg.rivalTerritory end
    end
    if started('gs_reputation') then m = m * (1 + (exports.gs_reputation:GetStreetBonus(src) or 0)) end -- réputation de rue
    local unit = math.floor(math.random(drug.sell.price[1], drug.sell.price[2]) * m)
    return math.max(1, unit), refuse
end

lib.callback.register('gs_drugs:sell', function(src, netId, drugId)
    if not Security:RateLimit(src, 'gs_drugs:sell', 1, 6000) then return false, 'Doucement, les clients se méfient.' end
    local ped = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not ped or ped == 0 or not DoesEntityExist(ped) or GetEntityType(ped) ~= 1 or IsPedAPlayer(ped) or GetEntityHealth(ped) <= 0 then
        return false, 'Personne à qui vendre.'
    end
    if not Security:EntityInRange(src, ped, Config.Sell.radius + Config.Tolerance) then return false, 'Trop loin.' end
    if JobsApi:IsOnDutyAs(src, Config.PoliceJob) then return false, 'Pas en service de police.' end
    local state = Entity(ped).state
    if state.gsSold then return false, 'Il t\'a déjà dit non.' end

    -- Produit choisi par le joueur, sinon le premier vendable de l'inventaire
    local drug, have
    for id, d in pairs(Config.Drugs) do
        if Drugs.enabled[id] and (drugId == nil or drugId == id) then
            local n = Bridge:GetItemCount(src, d.sell.item)
            if n > 0 then drug, have = d, n break end
        end
    end
    if not drug then return false, 'Tu n\'as rien à vendre.' end

    state:set('gsSold', true, true)
    local coords = GetEntityCoords(ped)
    local unit, refuse = Drugs.quote(src, drug, coords)
    if policeNear(coords) then refuse = 1.0 end
    if math.random() < refuse then
        WantedApi:ReportCrime(src, 'drug_sale', coords) -- un refus peut finir en appel à la police
        return false, 'Pas intéressé… et il sort son téléphone.'
    end
    local qty = math.min(have, math.random(1, Config.Sell.maxPerSale))
    if not Bridge:RemoveItem(src, drug.sell.item, qty) then return false, 'Tu n\'as plus rien.' end
    local total = unit * qty
    pay(src, total)
    local zone = zoneOf(coords)
    Drugs.sales[zone] = Drugs.sales[zone] or {}
    table.insert(Drugs.sales[zone], os.time())
    WantedApi:ReportCrime(src, 'drug_sale', coords)
    if started('gs_quests') then exports.gs_quests:Reward(src, 'drug_sale') end
    if started('gs_gangs') then
        local gang = exports.gs_gangs:GetGang(src)
        local tz = exports.gs_gangs:GetTerritoryAt(coords)
        if gang and tz then exports.gs_gangs:AddInfluence(gang, tz, Config.Sell.influence) end
    end
    return true, ('%d × %s vendus %d $'):format(qty, drug.label, total)
end)

AddEventHandler('gs_bridge:server:playerUnloaded', function(src) Drugs.pending[src] = nil end)

--- Active les drogues dont tous les items existent (sinon message clair en console).
function Drugs.init()
    for id, d in pairs(Config.Drugs) do
        local missing = {}
        for _, item in ipairs({ d.harvest.item, d.process.output, d.sell.item }) do
            if not Bridge:ItemExists(item) then missing[#missing + 1] = item end
        end
        if #missing == 0 then Drugs.enabled[id] = true
        else print(('^3[gs_drugs] %s désactivé : items absents d\'ox_inventory : %s^7'):format(id, table.concat(missing, ', '))) end
    end
end

CreateThread(Drugs.init)

--- Produits vendables actifs (receleur de gs_gangs) : { { id, label, item, price = { min, max } } }
exports('GetSellables', function()
    local l = {}
    for id, d in pairs(Config.Drugs) do
        if Drugs.enabled[id] then l[#l + 1] = { id = id, label = d.label, item = d.sell.item, price = d.sell.price } end
    end
    return l
end)
