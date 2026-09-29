-- gs_casino (serveur) : loto hebdomadaire. Achat au comptoir (limite / semaine), tirage automatique le dimanche à 20 h,
-- gagnants tirés parmi les tickets vendus (une personne ne gagne qu'un lot), gains en banque ou à la prochaine connexion.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local L = Config.Lotto

Lotto = {}

function Lotto.clock() return { week = os.date('%G-%V'), wday = tonumber(os.date('%w')), hour = tonumber(os.date('%H')) } end

--- La semaine `week` peut-elle être tirée ? (semaine passée, ou semaine courante après l'heure du tirage)
function Lotto.due(week, clock)
    if week < clock.week then return true end
    return week == clock.week and clock.wday == L.drawWday and clock.hour >= L.drawHour
end

function Lotto.pot(tickets) return Store.lottoCarry() + math.floor(tickets * L.price * L.potShare) end

local function shortName(name) return name end

--- Tire les gagnants d'une semaine : liste { { cid, name, amount } }, report éventuel.
function Lotto.pick(tickets, pot)
    local pool, winners, used = {}, {}, {}
    for i, t in ipairs(tickets) do pool[i] = t end
    for i = #pool, 2, -1 do local j = math.random(i) pool[i], pool[j] = pool[j], pool[i] end
    for _, t in ipairs(pool) do
        if #winners >= #L.shares then break end
        if not used[t.citizenid] then
            used[t.citizenid] = true
            winners[#winners + 1] = { cid = t.citizenid, name = t.name, amount = math.floor(pot * L.shares[#winners + 1]) }
        end
    end
    return winners
end

function Lotto.draw(week)
    local tickets = Store.lottoTickets(week)
    local pot = Lotto.pot(#tickets)
    local result
    if #tickets < L.minTickets then
        Store.lottoSetCarry(pot)
        result = { week = week, tickets = #tickets, pot = pot, winners = {}, carried = pot }
    else
        local winners = Lotto.pick(tickets, pot)
        local paid = 0
        for _, w in ipairs(winners) do
            local src = Bridge:GetSourceByIdentifier(w.cid)
            if src and Bridge:AddMoney(src, 'bank', w.amount, 'loto') then
                Bridge:Notify(src, ('LOTO : tu as gagné %d $ ! (versés en banque)'):format(w.amount), 'success')
            else
                Store.pendingAdd(w.cid, w.amount)
            end
            paid = paid + w.amount
        end
        Store.lottoSetCarry(math.max(0, pot - paid))
        result = { week = week, tickets = #tickets, pot = pot, winners = winners, carried = math.max(0, pot - paid) }
    end
    Store.lottoDone(week, json.encode(result))
    local names = {}
    for _, w in ipairs(result.winners) do names[#names + 1] = ('%s (%d $)'):format(shortName(w.name), w.amount) end
    local msg = #result.winners > 0 and ('TIRAGE DU LOTO : %s'):format(table.concat(names, ', '))
        or ('TIRAGE DU LOTO : pas assez de participants, la cagnotte de %d $ est reportée.'):format(result.carried)
    for _, s in ipairs(Bridge:GetPlayers()) do Bridge:Notify(s, msg, 'inform') end
    Security:LogStaff('[Loto] ' .. msg)
    return result
end

function Lotto.tick()
    local clock = Lotto.clock()
    for _, week in ipairs(Store.lottoOpenWeeks()) do
        if Lotto.due(week, clock) then Lotto.draw(week) end
    end
end

lib.callback.register('gs_casino:lottoInfo', function(src)
    if not Security:RateLimit(src, 'gs_casino:lottoInfo', 6, 10000) then return nil end
    if not Security:InRange(src, L.cashier, L.range + 2.0) then return nil end
    local cid = Bridge:GetIdentifier(src)
    if not cid then return nil end
    local week = Lotto.clock().week
    local sold = #Store.lottoTickets(week)
    local last = Store.lottoLast()
    return { price = L.price, mine = Store.lottoMine(week, cid), max = L.maxPerWeek, sold = sold, pot = Lotto.pot(sold),
             shares = L.shares, last = last and json.decode(last) or nil }
end)

lib.callback.register('gs_casino:lottoBuy', function(src, n)
    if not Security:RateLimit(src, 'gs_casino:lottoBuy', 3, 10000) then return false, 'Doucement.' end
    if not Security:InRange(src, L.cashier, L.range + 2.0) then return false, 'Présente-toi à la caisse.' end
    n = math.floor(tonumber(n) or 0)
    local cid = Bridge:GetIdentifier(src)
    if not cid or n < 1 or n > L.maxPerWeek then return false, ('1 à %d tickets.'):format(L.maxPerWeek) end
    local week = Lotto.clock().week
    local mine = Store.lottoMine(week, cid)
    if mine + n > L.maxPerWeek then return false, ('Maximum %d tickets par semaine (tu en as %d).'):format(L.maxPerWeek, mine) end
    local price = n * L.price
    if not Bridge:RemoveMoney(src, 'cash', price, 'loto') and not Bridge:RemoveMoney(src, 'bank', price, 'loto') then
        return false, ('%d $ nécessaires (liquide ou banque).'):format(price)
    end
    local ci = Bridge:GetCharInfo(src) or {}
    Store.lottoBuy(week, cid, ('%s %s.'):format(ci.firstname or '?', (ci.lastname or '?'):sub(1, 1)), n)
    return true, ('%d ticket(s) de loto pour %d $. Tirage dimanche %dh.'):format(n, price, L.drawHour)
end)

--- Gains reçus hors ligne : versés à la connexion.
AddEventHandler('gs_bridge:server:playerLoaded', function(src)
    local cid = Bridge:GetIdentifier(src)
    local n = cid and Store.pendingTake(cid) or 0
    if n > 0 and Bridge:AddMoney(src, 'bank', n, 'loto') then Bridge:Notify(src, ('LOTO : %d $ gagnés pendant ton absence, versés en banque !'):format(n), 'success') end
end)

CreateThread(function()
    Store.initLotto()
    while true do
        Wait(60000)
        Lotto.tick()
    end
end)
