-- gs_bank (serveur) : distributeurs et guichets. Le joueur doit être près de l'endroit annoncé (guichet : position connue du
-- serveur ; distributeur : position du prop côté client, bornée par un plafond de retrait quotidien), pas en véhicule.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Bank = {}

function Bank.today() return os.date('%Y-%m-%d') end

--- 'atm' ou 'counter' + coords annoncées → limites, ou nil si le lieu n'est pas valide pour ce joueur.
function Bank.place(src, kind, coords)
    if kind == 'counter' then
        for i, c in ipairs(Config.Counters) do
            if Security:InRange(src, c.coords, Config.Range + 1.5) then return Config.Counter, 'counter' end
        end
        return nil
    end
    if kind == 'atm' and type(coords) == 'table' and type(coords.x) == 'number' and type(coords.y) == 'number' and type(coords.z) == 'number'
        and Security:InRange(src, vec3(coords.x, coords.y, coords.z), Config.Range + 1.5) then
        return Config.Atm, 'atm'
    end
end

local function guard(src, key, max, window)
    return Security:RateLimit(src, 'gs_bank:' .. key, max, window) and Bridge:IsLoaded(src)
end

local function validAmount(a, limits)
    a = tonumber(a)
    return a and a == math.floor(a) and a >= Config.MinAmount and a <= limits.perOperation and a or nil
end

lib.callback.register('gs_bank:info', function(src, kind, coords)
    if not guard(src, 'info', 8, 10000) then return nil end
    local limits, place = Bank.place(src, kind, coords)
    if not limits then return nil end
    local cid = Bridge:GetIdentifier(src)
    return { cash = Bridge:GetMoney(src, 'cash'), bank = Bridge:GetMoney(src, 'bank'), place = place, perOperation = limits.perOperation,
             leftToday = math.max(0, limits.dailyWithdraw - Store.withdrawn(cid, Bank.today())), history = Store.history(cid, Config.HistorySize) }
end)

lib.callback.register('gs_bank:withdraw', function(src, kind, coords, amount)
    if not guard(src, 'withdraw', 3, 10000) then return false, 'Doucement.' end
    local limits, place = Bank.place(src, kind, coords)
    if not limits then return false, 'Trop loin du distributeur.' end
    amount = validAmount(amount, limits)
    if not amount then return false, ('Montant : 1 à %d $ par opération.'):format(limits.perOperation) end
    local cid, day = Bridge:GetIdentifier(src), Bank.today()
    if Store.withdrawn(cid, day) + amount > limits.dailyWithdraw then return false, 'Plafond de retrait du jour atteint.' end
    if Bridge:GetMoney(src, 'bank') < amount then return false, 'Solde insuffisant.' end
    if not Bridge:RemoveMoney(src, 'bank', amount, 'retrait ' .. place) then return false, 'Opération refusée.' end
    if not Bridge:AddMoney(src, 'cash', amount, 'retrait ' .. place) then
        Bridge:AddMoney(src, 'bank', amount, 'remboursement retrait')
        return false, 'Erreur, rien n\'a été débité.'
    end
    Store.addWithdrawn(cid, day, amount)
    Store.addTx(cid, 'withdraw', -amount, Bridge:GetMoney(src, 'bank'), place)
    return true, ('%d $ retirés.'):format(amount)
end)

lib.callback.register('gs_bank:deposit', function(src, kind, coords, amount)
    if not guard(src, 'deposit', 3, 10000) then return false, 'Doucement.' end
    local limits, place = Bank.place(src, kind, coords)
    if not limits then return false, 'Trop loin du distributeur.' end
    amount = validAmount(amount, limits)
    if not amount then return false, ('Montant : 1 à %d $ par opération.'):format(limits.perOperation) end
    if Bridge:GetMoney(src, 'cash') < amount then return false, 'Pas assez de liquide.' end
    if not Bridge:RemoveMoney(src, 'cash', amount, 'dépôt ' .. place) then return false, 'Opération refusée.' end
    if not Bridge:AddMoney(src, 'bank', amount, 'dépôt ' .. place) then
        Bridge:AddMoney(src, 'cash', amount, 'remboursement dépôt')
        return false, 'Erreur, rien n\'a été débité.'
    end
    Store.addTx(Bridge:GetIdentifier(src), 'deposit', amount, Bridge:GetMoney(src, 'bank'), place)
    return true, ('%d $ déposés.'):format(amount)
end)

CreateThread(function() Store.init() end)
