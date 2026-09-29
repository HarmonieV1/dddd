-- Carnet de commandes : un joueur demande un dépannage (/depanneur), les mécanos en service reçoivent le ticket,
-- l'un d'eux le prend (GPS), puis le clôt. Une demande ouverte par joueur ; expirées après Config.Orders.expire s.
Orders = { list = {}, nextId = 0 }

local function onDuty(job) return exports.gs_jobs:GetOnDutyPlayers(job) end -- même ressource : export local

local function openOrders(job)
    local l, now = {}, os.time()
    for id, o in pairs(Orders.list) do
        if o.job == job and now - o.at > Config.Orders.expire then Orders.list[id] = nil
        elseif o.job == job then l[#l + 1] = { id = o.id, name = o.name, message = o.message, x = o.coords.x, y = o.coords.y, z = o.coords.z, at = o.at, taken = o.takenBy ~= nil } end
    end
    table.sort(l, function(a, b) return a.id < b.id end)
    return l
end

lib.callback.register('gs_jobs:orders:create', function(src, job, message)
    if not GSJ.guard(src, 'order_create', 2, 60000) then return false, L('slow_down') end
    if not Config.Orders.jobs[job] then return false, L('invalid') end
    for _, o in pairs(Orders.list) do if o.src == src and o.job == job then return false, 'Tu as déjà une demande en cours.' end end
    message = Security:Sanitize(message, 120) or 'Besoin d\'aide'
    local staff = GSJ.dutyList and GSJ.dutyList(job) or {}
    Orders.nextId = Orders.nextId + 1
    local o = { id = Orders.nextId, src = src, job = job, name = Bridge:GetName(src) or '?', message = message,
        coords = GetEntityCoords(GetPlayerPed(src)), at = os.time() }
    Orders.list[o.id] = o
    local n = 0
    for _, m in ipairs(staff) do
        TriggerClientEvent('gs_jobs:client:orderNew', m, { id = o.id, name = o.name, message = message, label = Config.Orders.jobs[job] })
        n = n + 1
    end
    return true, n > 0 and ('Demande envoyée à %d %s en service.'):format(n, Config.Orders.jobs[job])
        or ('Demande enregistrée : aucun %s en service pour l\'instant.'):format(Config.Orders.jobs[job])
end)

lib.callback.register('gs_jobs:orders:list', function(src)
    if not GSJ.guard(src, 'order_list', 5, 10000) then return nil end
    local job = Bridge:GetJob(src)
    if not job or not job.onduty or not Config.Orders.jobs[job.name] then return nil end
    return openOrders(job.name)
end)

lib.callback.register('gs_jobs:orders:take', function(src, id)
    if not GSJ.guard(src, 'order_take', 5, 10000) then return false, L('slow_down') end
    local job = Bridge:GetJob(src)
    local o = Orders.list[tonumber(id)]
    if not job or not job.onduty or not o or o.job ~= job.name then return false, L('invalid') end
    if o.takenBy and o.takenBy ~= src then return false, 'Déjà pris par un collègue.' end
    o.takenBy = src
    if GetPlayerName(o.src) then Bridge:Notify(o.src, ('%s arrive pour ta demande.'):format(Bridge:GetName(src) or 'Un mécano'), 'success') end
    return true, o.coords
end)

lib.callback.register('gs_jobs:orders:close', function(src, id)
    if not GSJ.guard(src, 'order_close', 5, 10000) then return false, L('slow_down') end
    local o = Orders.list[tonumber(id)]
    if not o or o.takenBy ~= src then return false, L('invalid') end
    Orders.list[o.id] = nil
    DB.audit('order_done', o.job, GSJ.cid(src), nil, nil, o.message)
    return true, 'Demande clôturée. Pense à la facture (F6).'
end)

AddEventHandler('gs_bridge:server:playerUnloaded', function(src)
    for id, o in pairs(Orders.list) do if o.src == src then Orders.list[id] = nil end end
end)

function GSJ.dutyList(job)
    local list = {}
    for src in pairs(Members) do
        local j = Bridge:GetJob(src)
        if j and j.name == job and j.onduty then list[#list + 1] = src end
    end
    return list
end
