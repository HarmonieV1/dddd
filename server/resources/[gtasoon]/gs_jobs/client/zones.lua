-- Zones ox_target (0 ms au repos : pas de boucle) + blips. La visibilité dépend du job, le serveur revalide.
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

CreateThread(function()
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
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, id in ipairs(zones) do exports.ox_target:removeZone(id) end
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
end)
