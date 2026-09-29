-- Zones ox_target (0 ms au repos : pas de boucle) + blips + marqueurs au sol pour SON métier.
-- Les points déplacés par le staff (GlobalState.gsJobPoints) remplacent ceux de jobs.lua, zones reconstruites à chaud.
local zones, blips = {}, {}

local function addZone(coords, option)
    option.distance = option.distance or 2.5
    zones[#zones + 1] = exports.ox_target:addSphereZone({
        coords = coords, radius = Config.ZoneRadius, debug = Config.Debug, options = { option },
    })
end

local function addBlip(coords, b)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, b.sprite)
    SetBlipColour(blip, b.color)
    SetBlipScale(blip, b.scale or 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(b.label)
    EndTextCommandSetBlipName(blip)
    blips[#blips + 1] = blip
end

--- Même règle que le serveur (server/points.lua).
local function applyPoint(o)
    local p = Jobs[o.job] and Jobs[o.job].points
    local list = p and p[o.kind == 'garage_spawn' and 'garage' or o.kind]
    if type(list) ~= 'table' or not list[o.idx] then return end
    if o.kind == 'stash' or o.kind == 'garage' then list[o.idx].coords = vec3(o.x, o.y, o.z)
    elseif o.kind == 'garage_spawn' then list[o.idx].spawn = vec4(o.x, o.y, o.z, o.w or 0.0)
    else list[o.idx] = vec3(o.x, o.y, o.z) end
end

-- Armurerie ------------------------------------------------------------------------------------------------
local function openArmory(name)
    local def = Jobs[name]
    local options = {}
    for _, a in ipairs(def.armory or {}) do
        local item = exports.ox_inventory:Items(a.item) -- [API] ox_inventory (client)
        local have = exports.ox_inventory:Search('count', a.item) or 0
        local locked = GSJ.job.grade < (a.minGrade or 0)
        options[#options + 1] = {
            title = item and item.label or a.item, icon = 'box-open', disabled = locked or have >= a.max,
            description = locked and ('Grade requis : %s'):format(GSJ.gradeLabel(name, a.minGrade)) or ('%d / %d'):format(have, a.max),
            onSelect = function() GSJ.result(lib.callback.await('gs_jobs:armory', false, a.item)) openArmory(name) end,
        }
    end
    lib.registerContext({ id = 'gs_jobs_armory', title = 'Armurerie · ' .. def.label, options = options })
    lib.showContext('gs_jobs_armory')
end

-- Marqueurs au sol : seulement les points de ton métier actif --------------------------------------------------
local function refreshMarkers()
    exports.gs_markers:RemovePrefix('gs_jobs:pt:')
    local job = GSJ.job and Jobs[GSJ.job.name]
    if not job then return end
    local p, name = job.points, GSJ.job.name
    local function mark(kind, i, coords, label)
        exports.gs_markers:Add(('gs_jobs:pt:%s%d'):format(kind, i), { coords = coords, style = 'job', label = label,
            event = 'gs_jobs:client:point', args = { name, kind, i } })
    end
    for i, c in ipairs(p.duty or {}) do mark('duty', i, c, 'Prise de service') end
    for i, c in ipairs(p.boss or {}) do mark('boss', i, c, 'Direction') end
    for i, c in ipairs(p.armory or {}) do mark('armory', i, c, 'Armurerie') end
    for i, st in ipairs(p.stash or {}) do mark('stash', i, st.coords, st.label or 'Coffre') end
    for i, g in ipairs(p.garage or {}) do mark('garage', i, g.coords, 'Garage') end
end

--- [E] sur un point de son métier : mêmes actions (et mêmes conditions) que les zones ox_target.
AddEventHandler('gs_jobs:client:point', function(name, kind, i)
    if not GSJ.isJob(name) then return end
    if kind == 'duty' then return TriggerServerEvent('gs_jobs:server:toggleDuty') end
    if kind == 'boss' then
        if GSJ.isBoss(name) then return GSJ.openBossMenu() end
        return GSJ.notify('Réservé à la direction.', 'error')
    end
    if not GSJ.isOnDuty(name) then return GSJ.notify('Prends d\'abord ton service.', 'error') end
    if kind == 'armory' then return openArmory(name) end
    if kind == 'garage' then return GSJ.openGarageMenu(name, i) end
    if kind == 'stash' then
        local st = Jobs[name].points.stash[i]
        if GSJ.job.grade < (st.minGrade or 0) then return GSJ.notify('Grade insuffisant.', 'error') end
        Bridge:OpenStash(('gs_%s_%d'):format(name, i))
    end
end)

local function clear()
    for _, id in ipairs(zones) do exports.ox_target:removeZone(id) end
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
    zones, blips = {}, {}
end

local function build()
    clear()
    for name, def in pairs(Jobs) do
        local p = def.points

        for _, coords in ipairs(p.duty or {}) do
            addZone(coords, {
                name = 'gs_duty_' .. name, icon = 'fa-solid fa-id-badge', label = L('zone_duty'),
                canInteract = function() return GSJ.isJob(name) end,
                onSelect = function() TriggerServerEvent('gs_jobs:server:toggleDuty') end,
            })
        end

        for i, s in ipairs(p.stash or {}) do
            addZone(s.coords, {
                name = ('gs_stash_%s_%d'):format(name, i), icon = 'fa-solid fa-box-archive', label = s.label,
                canInteract = function() return GSJ.isOnDuty(name) and GSJ.job.grade >= (s.minGrade or 0) end,
                onSelect = function() Bridge:OpenStash(('gs_%s_%d'):format(name, i)) end,
            })
        end

        for i, coords in ipairs(p.armory or {}) do
            addZone(coords, {
                name = ('gs_armory_%s_%d'):format(name, i), icon = 'fa-solid fa-shield-halved', label = 'Armurerie',
                canInteract = function() return GSJ.isOnDuty(name) end,
                onSelect = function() openArmory(name) end,
            })
        end

        for _, coords in ipairs(p.boss or {}) do
            addZone(coords, {
                name = 'gs_boss_' .. name, icon = 'fa-solid fa-briefcase', label = L('zone_boss'),
                canInteract = function() return GSJ.isBoss(name) end,
                onSelect = function() GSJ.openBossMenu() end,
            })
        end

        for i, g in ipairs(p.garage or {}) do
            addZone(g.coords, {
                name = ('gs_garage_%s_%d'):format(name, i), icon = 'fa-solid fa-car', label = L('zone_garage'),
                canInteract = function() return GSJ.isOnDuty(name) end,
                onSelect = function() GSJ.openGarageMenu(name, i) end,
            })
        end

        local anchor = (p.duty and p.duty[1]) or (p.garage and p.garage[1] and p.garage[1].coords)
        if def.blip and anchor then addBlip(anchor, def.blip) end
    end

    addZone(Config.JobCenter.coords, {
        name = 'gs_job_center', icon = 'fa-solid fa-building', label = L('zone_job_center'),
        onSelect = function() GSJ.openJobCenter() end,
    })
    addBlip(Config.JobCenter.coords, Config.JobCenter.blip)
    exports.gs_markers:Add('gs_jobs:center', { coords = Config.JobCenter.coords, style = 'entry', label = 'Pôle Emploi' })
    refreshMarkers()
end

local function applyAll(list)
    for _, o in ipairs(list or {}) do applyPoint(o) end
end

CreateThread(function()
    applyAll(GlobalState.gsJobPoints)
    build()
end)

AddStateBagChangeHandler('gsJobPoints', 'global', function(_, _, value)
    applyAll(value)
    build()
end)

AddEventHandler('gs_bridge:client:jobUpdated', function() Wait(0) refreshMarkers() end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clear()
    exports.gs_markers:RemovePrefix('gs_jobs:')
end)
