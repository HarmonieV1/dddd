-- État client : pour l'AFFICHAGE uniquement (le serveur revalide chaque action).
Bridge = exports.gs_bridge

GSJ = { job = nil, memberships = {} }

AddEventHandler('gs_bridge:client:jobUpdated', function(job) GSJ.job = job end)
AddEventHandler('gs_bridge:client:playerLoaded', function()
    GSJ.memberships = lib.callback.await('gs_jobs:getMemberships', false) or {}
end)
AddEventHandler('gs_bridge:client:playerUnloaded', function()
    GSJ.job, GSJ.memberships = nil, {}
end)
RegisterNetEvent('gs_jobs:client:memberships', function(jobs) GSJ.memberships = jobs or {} end)

CreateThread(function()
    GSJ.job = Bridge:GetJob()
    if GSJ.job then GSJ.memberships = lib.callback.await('gs_jobs:getMemberships', false) or {} end
end)

--- V12.37 · Relit le métier à la source (gs_bridge : copie client des données Qbox, mise à jour par les événements du
--- framework) au moment de décider : jamais une valeur périmée entre deux `gs_bridge:client:jobUpdated`.
function GSJ.refreshJob()
    GSJ.job = Bridge:GetJob()
    return GSJ.job
end

--- V12.37 · Demande de prise / fin de service. On envoie l'état VOULU (et pas « bascule ») : le serveur ne rebascule pas si
--- c'est déjà le cas. Avant, un double déclenchement (PNJ + zone, [E] + clic) faisait « Prise de service » puis « Fin de
--- service » à la suite, et le garage refusait ensuite (hors service). `remote` = par téléphone (de n'importe où).
function GSJ.toggleDuty(remote)
    local j = GSJ.refreshJob()
    if not j then return end
    TriggerServerEvent('gs_jobs:server:toggleDuty', remote == true, not j.onduty)
end

function GSJ.isJob(name, minGrade)
    local j = GSJ.job
    return j ~= nil and j.name == name and j.grade >= (minGrade or 0)
end

function GSJ.isOnDuty(name)
    return GSJ.isJob(name) and GSJ.job.onduty
end

function GSJ.isBoss(name)
    if not GSJ.isJob(name) then return false end
    local g = Jobs[name].grades[GSJ.job.grade]
    return g ~= nil and g.boss == true
end

function GSJ.jobLabel(name)
    if name == Config.UnemployedJob then return L('unemployed') end
    return Jobs[name] and Jobs[name].label or name
end

function GSJ.gradeLabel(job, grade)
    local g = Jobs[job] and Jobs[job].grades[grade]
    return g and g.label or ''
end

function GSJ.notify(msg, ntype)
    lib.notify({ description = msg, type = ntype or 'inform' })
end

--- Affiche le résultat (ok, message) d'un callback serveur.
function GSJ.result(ok, msg)
    if msg then GSJ.notify(msg, ok and 'success' or 'error') end
    return ok
end

--- Grades triés, optionnellement strictement inférieurs à `below`.
function GSJ.gradeOptions(job, below)
    local list = {}
    for level, g in pairs(Jobs[job].grades) do
        if not below or level < below then list[#list + 1] = { value = tostring(level), label = g.label, level = level } end
    end
    table.sort(list, function(a, b) return a.level < b.level end)
    return list
end
