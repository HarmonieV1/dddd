-- gs_casino (serveur) : roue 1×/jour, tickets à gratter (limite / jour). Tirage, paiement et limites ici uniquement.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Casino = {}

function Casino.today() return os.date('%Y-%m-%d') end

--- Tours de roue gratuits par jour : 1 + bonus d'événement (gs_events).
function Casino.wheelAllowed()
    return 1 + (GetResourceState('gs_events') == 'started' and exports.gs_events:GetBonus('wheel') or 0)
end

--- Tirage pondéré : index d'une case de la roue.
function Casino.pickSegment()
    local total = 0
    for _, s in ipairs(Config.Wheel.segments) do total = total + s.weight end
    local r = math.random() * total
    for i, s in ipairs(Config.Wheel.segments) do
        r = r - s.weight
        if r < 0 then return i end
    end
    return #Config.Wheel.segments
end

function Casino.pickScratch()
    local r = math.random(1, 1000)
    for _, p in ipairs(Config.Scratch.prizes) do
        r = r - p.chance
        if r <= 0 then return p.cash end
    end
    return 0
end

local function pay(src, seg)
    if seg.cash then return Bridge:AddMoney(src, 'bank', seg.cash, 'roue du casino') end
    if seg.xp then
        if GetResourceState('gs_quests') ~= 'started' then return Bridge:AddMoney(src, 'bank', seg.xp * 2, 'roue du casino') end
        return exports.gs_quests:AddXP(src, seg.xp, 'roue du casino') ~= nil
    end
    if seg.item then
        if Bridge:CanCarry(src, seg.item, seg.count) and Bridge:AddItem(src, seg.item, seg.count) then return true end
        return Bridge:AddMoney(src, 'bank', 1000, 'roue du casino (sac plein)') -- sac plein : compensation
    end
    return false
end

lib.callback.register('gs_casino:status', function(src)
    if not Security:RateLimit(src, 'gs_casino:status', 5, 10000) then return nil end
    local cid = Bridge:GetIdentifier(src)
    if not cid then return nil end
    local day = Casino.today()
    return { wheel = Store.used(cid, 'wheel', day) < Casino.wheelAllowed(), scratchLeft = Config.Scratch.perDay - Store.used(cid, 'scratch', day) }
end)

lib.callback.register('gs_casino:spin', function(src)
    if not Security:RateLimit(src, 'gs_casino:spin', 2, 10000) then return false, 'Doucement.' end
    local cid = Bridge:GetIdentifier(src)
    if not cid then return false end
    if not Security:InRange(src, Config.Wheel.stand, Config.Wheel.range + 2.0) then return false, 'Approche-toi de la roue.' end
    local day = Casino.today()
    if Store.used(cid, 'wheel', day) >= Casino.wheelAllowed() then return false, 'Tu as déjà tourné la roue aujourd\'hui. Reviens demain !' end
    Store.bump(cid, 'wheel', day) -- compté AVANT de payer : pas de double tour en spammant
    local i = Casino.pickSegment()
    local seg = Config.Wheel.segments[i]
    pay(src, seg)
    Security:LogStaff(('[Casino] %s : roue → %s'):format(Bridge:GetName(src) or src, seg.label))
    return true, i, seg.label
end)

lib.callback.register('gs_casino:scratch', function(src)
    if not Security:RateLimit(src, 'gs_casino:scratch', 2, 3000) then return false, 'Doucement.' end
    local cid = Bridge:GetIdentifier(src)
    if not cid then return false end
    local day = Casino.today()
    if Store.used(cid, 'scratch', day) >= Config.Scratch.perDay then
        return false, ('Limite de %d tickets par jour atteinte.'):format(Config.Scratch.perDay)
    end
    if not Bridge:RemoveItem(src, 'scratch_ticket', 1) then return false, 'Tu n\'as pas de ticket.' end
    Store.bump(cid, 'scratch', day)
    local cash = Casino.pickScratch()
    if cash > 0 then
        Bridge:AddMoney(src, 'cash', cash, 'ticket à gratter')
        if cash >= 2000 then Security:LogStaff(('[Casino] %s : ticket gagnant %d $'):format(Bridge:GetName(src) or src, cash)) end
    end
    return true, cash
end)

CreateThread(function() Store.init() end)
