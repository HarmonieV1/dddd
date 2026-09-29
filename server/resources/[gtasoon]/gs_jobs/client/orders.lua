-- Carnet de commandes (mécano, taxi) : les joueurs demandent, les employés en service prennent la demande.
local function ask(job, title)
    local r = lib.inputDialog(title, { { type = 'input', label = 'Ta demande (ex : pneu crevé, panne moteur)', max = 120 } })
    if r then GSJ.result(lib.callback.await('gs_jobs:orders:create', false, job, r[1])) end
end
RegisterCommand('depanneur', function() ask('mechanic', 'Appeler un mécano') end, false)
RegisterCommand('taxi', function() ask('taxi', 'Appeler un taxi') end, false)

local taken
RegisterCommand('commandes', function()
    local list = lib.callback.await('gs_jobs:orders:list', false)
    if not list then return GSJ.notify('Réservé aux employés en service (mécano, taxi).', 'error') end
    local options = {}
    for _, o in ipairs(list) do
        local mine = taken == o.id
        options[#options + 1] = { title = ('#%d · %s'):format(o.id, o.name), description = o.message .. (o.taken and (mine and ' · pris par toi' or ' · déjà pris') or ''),
            icon = mine and 'check' or 'wrench', disabled = o.taken and not mine, onSelect = function()
                if mine then
                    GSJ.result(lib.callback.await('gs_jobs:orders:close', false, o.id))
                    taken = nil
                    return
                end
                local ok, coords = lib.callback.await('gs_jobs:orders:take', false, o.id)
                if not ok then return GSJ.result(false, coords) end
                taken = o.id
                SetNewWaypoint(coords.x, coords.y)
                GSJ.notify('Demande prise : GPS posé. Reviens ici (/commandes) pour la clôturer.', 'success')
            end }
    end
    if #options == 0 then options[1] = { title = 'Aucune demande', readOnly = true } end
    lib.registerContext({ id = 'gs_jobs_orders', title = 'Carnet de commandes', options = options })
    lib.showContext('gs_jobs_orders')
end, false)

RegisterNetEvent('gs_jobs:client:orderNew', function(o)
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', false)
    lib.notify({ title = 'Nouvelle demande · ' .. o.name, description = o.message .. ' — /commandes', type = 'inform', icon = 'wrench', duration = 10000 })
end)
