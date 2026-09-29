-- Caisses de société. Exportées pour les futures ressources gs_* (serveur uniquement).
Society = {}

function Society.balance(job)
    return DB.getSociety(job)
end

function Society.add(job, amount)
    if not Jobs[job] or not Jobs[job].society or not GSJ.isInt(amount, 1) then return false end
    return DB.addSociety(job, amount)
end

function Society.remove(job, amount)
    if not Jobs[job] or not Jobs[job].society or not GSJ.isInt(amount, 1) then return false end
    return DB.removeSociety(job, amount)
end

-- Chiffre d'affaires légal du jour (factures payées, ventes) : il plafonne le blanchiment (une entreprise qui ne
-- travaille pas ne peut pas blanchir). Remis à zéro chaque jour.
Society.revenue = {} -- [job] = { day, amount }
function Society.revenueToday(job)
    local r = Society.revenue[job]
    if not r or r.day ~= os.date('%Y-%m-%d') then r = { day = os.date('%Y-%m-%d'), amount = 0, laundered = 0 } Society.revenue[job] = r end
    return r
end
function Society.recordRevenue(job, amount)
    if Jobs[job] and GSJ.isInt(amount, 1) then local r = Society.revenueToday(job) r.amount = r.amount + amount end
end

exports('GetSocietyMoney', Society.balance)
--- isRevenue = true : vraie vente (compte dans le chiffre d'affaires du jour).
exports('AddSocietyMoney', function(job, amount, isRevenue)
    local ok = Society.add(job, amount)
    if ok and isRevenue then Society.recordRevenue(job, amount) end
    return ok
end)
exports('RemoveSocietyMoney', Society.remove)
