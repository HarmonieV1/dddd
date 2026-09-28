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

exports('GetSocietyMoney', Society.balance)
exports('AddSocietyMoney', Society.add)
exports('RemoveSocietyMoney', Society.remove)
