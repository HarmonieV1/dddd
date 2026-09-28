-- Menus ox_lib : /job (F6), Pôle Emploi, garage, direction, factures, offre d'embauche.

local function sortedMemberships()
    local list = {}
    for name, grade in pairs(GSJ.memberships) do list[#list + 1] = { name = name, grade = grade } end
    table.sort(list, function(a, b) return GSJ.jobLabel(a.name) < GSJ.jobLabel(b.name) end)
    return list
end

local function show(id, title, options, menu)
    lib.registerContext({ id = id, title = title, options = options, menu = menu })
    lib.showContext(id)
end

-- Menu principal /job -------------------------------------------------------------------

function GSJ.openJobMenu()
    local job = GSJ.job
    if not job then return end
    local def = Jobs[job.name]
    local options = {
        {
            title = L('menu_active', GSJ.jobLabel(job.name)),
            description = def and ('%s · %s'):format(GSJ.gradeLabel(job.name, job.grade), job.onduty and L('on_duty') or L('off_duty')),
            icon = 'briefcase', readOnly = true,
        },
    }

    if def then
        if def.dutyAnywhere then
            options[#options + 1] = { title = L('menu_duty'), icon = 'id-badge',
                onSelect = function() TriggerServerEvent('gs_jobs:server:toggleDuty') end }
        end
        if def.mission and job.onduty then
            if GSJ.missionActive() then
                options[#options + 1] = { title = L('menu_mission_cancel'), icon = 'xmark',
                    onSelect = function() TriggerServerEvent('gs_jobs:server:missionCancel') end }
            else
                options[#options + 1] = { title = L('menu_mission_start'), icon = 'route',
                    onSelect = function() GSJ.result(lib.callback.await('gs_jobs:mission:start', false)) end }
            end
        end
        if def.billing and def.society and job.onduty then
            options[#options + 1] = { title = L('menu_bill'), description = def.billing.label, icon = 'file-invoice-dollar',
                onSelect = function() GSJ.createBill() end }
        end
    end

    for _, m in ipairs(sortedMemberships()) do
        if m.name ~= job.name then
            options[#options + 1] = {
                title = L('menu_switch', GSJ.jobLabel(m.name)), description = GSJ.gradeLabel(m.name, m.grade), icon = 'right-left',
                onSelect = function() TriggerServerEvent('gs_jobs:server:switch', m.name) end,
            }
        end
    end

    if job.name ~= Config.UnemployedJob then
        options[#options + 1] = { title = L('menu_unemployed'), icon = 'couch',
            onSelect = function() TriggerServerEvent('gs_jobs:server:switch', Config.UnemployedJob) end }
        if GSJ.memberships[job.name] then
            options[#options + 1] = {
                title = L('menu_resign'), icon = 'door-open', iconColor = '#ff2e88',
                onSelect = function()
                    local answer = lib.alertDialog({ header = L('menu_resign'), content = L('menu_resign_confirm', GSJ.jobLabel(job.name)),
                        centered = true, cancel = true })
                    if answer == 'confirm' then TriggerServerEvent('gs_jobs:server:resign', job.name) end
                end,
            }
        end
    end

    options[#options + 1] = { title = L('menu_bills'), icon = 'receipt', onSelect = function() GSJ.openBills() end }
    show('gs_jobs_menu', L('menu_title'), options)
end

RegisterCommand('job', function() GSJ.openJobMenu() end, false)
RegisterKeyMapping('job', 'Menu emplois', 'keyboard', 'F6')
RegisterCommand('factures', function() GSJ.openBills() end, false)

-- Pôle Emploi -------------------------------------------------------------------------

function GSJ.openJobCenter()
    local options = {}
    for name, def in pairs(Jobs) do
        if not def.whitelisted then
            local member = GSJ.memberships[name] ~= nil
            options[#options + 1] = {
                title = def.label, description = member and L('already') or def.description, icon = def.icon or 'briefcase',
                disabled = member,
                onSelect = function() TriggerServerEvent('gs_jobs:server:joinPublic', name) end,
            }
        end
    end
    table.sort(options, function(a, b) return a.title < b.title end)
    show('gs_jobs_center', L('job_center'), options)
end

-- Garage ------------------------------------------------------------------------------

function GSJ.openGarageMenu(name, index)
    local def = Jobs[name]
    local options = {
        { title = L('garage_store'), icon = 'square-parking',
          onSelect = function() GSJ.result(lib.callback.await('gs_jobs:garage:store', false, index)) end },
    }
    for i, v in ipairs(def.vehicles or {}) do
        if GSJ.job.grade >= (v.minGrade or 0) then
            options[#options + 1] = { title = v.label, icon = 'car',
                onSelect = function() GSJ.result(lib.callback.await('gs_jobs:garage:spawn', false, index, i)) end }
        end
    end
    show('gs_jobs_garage', L('zone_garage'), options)
end

-- Direction ---------------------------------------------------------------------------

local function bossAction(action, payload)
    GSJ.result(lib.callback.await('gs_jobs:boss:action', false, action, payload))
    GSJ.openBossMenu()
end

local function askAmount(title)
    local input = lib.inputDialog(title, { { type = 'number', label = L('amount'), min = 1, required = true } })
    return input and tonumber(input[1])
end

local function recruit(data)
    local nearby = lib.getNearbyPlayers(GetEntityCoords(cache.ped), Config.PlayerActionRange, false)
    if #nearby == 0 then return GSJ.notify(L('no_one_nearby'), 'error') end
    local players = {}
    for _, p in ipairs(nearby) do
        local sid = GetPlayerServerId(p.id)
        players[#players + 1] = { value = tostring(sid), label = L('citizen_id', sid) }
    end
    local input = lib.inputDialog(L('boss_recruit'), {
        { type = 'select', label = L('player'), options = players, required = true },
        { type = 'select', label = L('grade'), options = GSJ.gradeOptions(data.job, data.myGrade), required = true },
    })
    if input then bossAction('hire', { target = tonumber(input[1]), grade = tonumber(input[2]) }) end
end

local function employeeMenu(data, e)
    local options = {
        { title = L('boss_set_grade'), icon = 'arrow-up-wide-short',
          onSelect = function()
              local input = lib.inputDialog(e.name, {
                  { type = 'select', label = L('grade'), options = GSJ.gradeOptions(data.job, data.myGrade), required = true, default = tostring(e.grade) },
              })
              if input then bossAction('setGrade', { cid = e.citizenid, grade = tonumber(input[1]) }) end
          end },
        { title = L('boss_fire'), icon = 'user-xmark', iconColor = '#ff2e88',
          onSelect = function()
              local answer = lib.alertDialog({ header = L('boss_fire'), content = L('boss_fire_confirm', e.name), centered = true, cancel = true })
              if answer == 'confirm' then bossAction('fire', { cid = e.citizenid }) end
          end },
    }
    show('gs_jobs_employee', e.name, options, 'gs_jobs_employees')
end

function GSJ.openBossMenu()
    local data = lib.callback.await('gs_jobs:boss:getData', false)
    if not data then return GSJ.notify(L('not_boss'), 'error') end

    local options = {}
    if data.society then
        options[#options + 1] = { title = L('boss_society', data.society), icon = 'sack-dollar', readOnly = true }
        options[#options + 1] = { title = L('boss_deposit'), icon = 'arrow-down',
            onSelect = function() local a = askAmount(L('boss_deposit')); if a then bossAction('deposit', { amount = a }) end end }
        options[#options + 1] = { title = L('boss_withdraw'), icon = 'arrow-up',
            onSelect = function() local a = askAmount(L('boss_withdraw')); if a then bossAction('withdraw', { amount = a }) end end }
    end
    options[#options + 1] = { title = L('boss_recruit'), icon = 'user-plus', onSelect = function() recruit(data) end }
    options[#options + 1] = { title = L('boss_employees', #data.employees), icon = 'users', menu = 'gs_jobs_employees' }

    local employees = {}
    for _, e in ipairs(data.employees) do
        local manageable = e.citizenid ~= data.myCid and e.grade < data.myGrade
        employees[#employees + 1] = {
            title = e.name ~= '' and e.name or e.citizenid,
            description = ('%s · %s'):format(e.gradeLabel, e.online and L('online') or L('offline')),
            icon = e.online and 'circle' or 'circle-dot', iconColor = e.online and '#39ff14' or '#888888',
            disabled = not manageable,
            onSelect = function() employeeMenu(data, e) end,
        }
    end
    lib.registerContext({ id = 'gs_jobs_employees', title = L('boss_employees', #data.employees), menu = 'gs_jobs_boss', options = employees })
    show('gs_jobs_boss', GSJ.jobLabel(data.job), options)
end

-- Factures ----------------------------------------------------------------------------

function GSJ.createBill()
    local def = GSJ.job and Jobs[GSJ.job.name]
    if not def or not def.billing then return end
    local target = lib.getClosestPlayer(GetEntityCoords(cache.ped), Config.PlayerActionRange, false)
    if not target then return GSJ.notify(L('no_one_nearby'), 'error') end
    local input = lib.inputDialog(def.billing.label, {
        { type = 'number', label = L('amount'), min = 1, max = def.billing.max, required = true },
        { type = 'input', label = L('reason'), max = Config.Billing.reasonMaxLength },
    })
    if not input then return end
    GSJ.result(lib.callback.await('gs_jobs:billing:create', false, GetPlayerServerId(target), input[1], input[2]))
end

function GSJ.openBills()
    local bills = lib.callback.await('gs_jobs:billing:list', false) or {}
    local options = {}
    for _, b in ipairs(bills) do
        options[#options + 1] = {
            title = ('%s · %s $'):format(GSJ.jobLabel(b.job), b.amount),
            description = ('%s · %s · %s'):format(b.reason, b.issuer_name, b.date),
            icon = 'file-invoice',
            onSelect = function()
                local answer = lib.alertDialog({ header = L('menu_bills'), content = L('bill_pay_confirm', b.amount, GSJ.jobLabel(b.job)),
                    centered = true, cancel = true })
                if answer ~= 'confirm' then return end
                GSJ.result(lib.callback.await('gs_jobs:billing:pay', false, b.id))
                GSJ.openBills()
            end,
        }
    end
    if #options == 0 then options[1] = { title = L('no_bills'), icon = 'check', readOnly = true } end
    show('gs_jobs_bills', L('menu_bills'), options)
end

-- Offre d'embauche reçue --------------------------------------------------------------

RegisterNetEvent('gs_jobs:client:offer', function(offer)
    local answer = lib.alertDialog({
        header = L('offer_title'),
        content = L('offer_content', offer.from, offer.job, offer.grade),
        centered = true, cancel = true,
        labels = { confirm = L('accept'), cancel = L('decline') },
    })
    TriggerServerEvent('gs_jobs:server:answerOffer', answer == 'confirm')
end)
