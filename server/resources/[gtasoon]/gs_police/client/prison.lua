-- gs_police (client) · V8 « Prison vivante » : points visibles seulement pour les détenus (boulots, cantine, trafiquant,
-- grille). Le serveur vérifie tout (détenu, position, délais, tickets, nuit, nombre de détenus).
local P = Config.Prison
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end
local jailed = false

local function shop(kind)
    local def = kind == 'dealer' and P.dealer or P.canteen
    local options = {}
    for i, art in ipairs(def.items) do
        local ok, item = pcall(function() return exports.ox_inventory:Items(art.item) end) -- [API] ox_inventory
        options[#options + 1] = { title = ok and item and item.label or art.item, icon = kind == 'dealer' and 'user-secret' or 'utensils',
            description = ('%d ticket(s)%s'):format(art.price, art.cigarettes and (' + %d paquet(s) de cigarettes'):format(art.cigarettes) or ''),
            onSelect = function() notify(lib.callback.await('gs_police:prisonBuy', false, kind, i)) end }
    end
    lib.registerContext({ id = 'gs_prison_shop', title = kind == 'dealer' and 'Le trafiquant' or 'Cantine', options = options })
    lib.showContext('gs_prison_shop')
end

AddEventHandler('gs_police:client:prisonWork', function(i)
    local job = P.jobs[i]
    if not lib.progressBar({ duration = job.seconds * 1000, label = job.label .. '…', canCancel = true, anim = { scenario = job.scenario },
        disable = { move = true, car = true, combat = true } }) then return ClearPedTasks(cache.ped) end
    ClearPedTasks(cache.ped)
    notify(lib.callback.await('gs_police:prisonWork', false, i))
end)
AddEventHandler('gs_police:client:prisonShop', shop)
AddEventHandler('gs_police:client:prisonEscape', function()
    if lib.alertDialog({ header = 'Découper la grille ?', content = 'À plusieurs, la nuit, avec des outils de fortune. Les autres détenus présents partent avec toi.',
        centered = true, cancel = true }) ~= 'confirm' then return end
    if not lib.progressBar({ duration = P.escape.seconds * 1000, label = 'Découpe de la grille…', canCancel = true,
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped' }, disable = { move = true, car = true, combat = true } }) then return ClearPedTasks(cache.ped) end
    ClearPedTasks(cache.ped)
    notify(lib.callback.await('gs_police:prisonEscape', false))
end)

local function show(on)
    if on == jailed then return end
    jailed = on
    if not on then return exports.gs_markers:RemovePrefix('gs_prison:') end
    for i, job in ipairs(P.jobs) do
        exports.gs_markers:Add('gs_prison:job' .. i, { coords = job.coords, style = 'job', label = job.label, event = 'gs_police:client:prisonWork', args = { i },
            prompt = ('%s (peine réduite)'):format(job.label), reach = 2.0 })
    end
    exports.gs_markers:Add('gs_prison:canteen', { coords = P.canteen.coords, style = 'shop', label = 'Cantine', event = 'gs_police:client:prisonShop', args = { 'canteen' }, prompt = 'Cantine (tickets)' })
    exports.gs_markers:Add('gs_prison:dealer', { coords = P.dealer.coords, style = 'hidden', event = 'gs_police:client:prisonShop', args = { 'dealer' }, prompt = 'Parler au détenu louche', reach = 1.8 })
    exports.gs_markers:Add('gs_prison:escape', { coords = P.escape.coords, style = 'hidden', event = 'gs_police:client:prisonEscape', prompt = 'Examiner la grille', reach = 2.0 })
end

RegisterNetEvent('gs_police:client:jail', function(seconds) show((seconds or 0) > 0) end)
AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then exports.gs_markers:RemovePrefix('gs_prison:') end end)
