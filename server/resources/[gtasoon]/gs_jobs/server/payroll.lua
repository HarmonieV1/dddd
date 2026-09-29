-- Paie périodique. Seuls les joueurs en service sont payés (sauf allocation chômage).
local lastPos = {}

local function pay(src)
    local job, def, grade = GSJ.activeJob(src)
    if not job then return end

    local amount, from, label
    if job.name == Config.UnemployedJob then
        amount, from, label = Config.UnemployedAllowance, 'state', L('allowance')
    elseif def and grade and job.onduty then
        amount, from, label = GSJ.salaryOf(job.name, job.grade), def.salaryFrom, def.label
    end
    if not amount or amount <= 0 then return end

    if Config.AntiAfk then
        local ped = GetPlayerPed(src)
        local pos = ped ~= 0 and GetEntityCoords(ped) or nil
        local prev = lastPos[src]
        lastPos[src] = pos
        if pos and prev and #(pos - prev) < 2.0 then return GSJ.notify(src, L('pay_afk'), 'warning') end
    end

    if from == 'society' and not Society.remove(job.name, amount) then
        return GSJ.notify(src, L('pay_society_empty'), 'error')
    end
    if Bridge:AddMoney(src, 'bank', amount, 'salaire ' .. job.name) then
        GSJ.notify(src, L('pay_received', amount, label), 'success')
    elseif from == 'society' then
        Society.add(job.name, amount) -- remboursement si le versement échoue
    end
end

CreateThread(function()
    local interval = Config.PayrollMinutes * 60000
    while true do
        Wait(interval)
        local players = Bridge:GetPlayers()
        for i = 1, #players do
            pay(players[i])
            if i % 10 == 0 then Wait(100) end -- étale la charge BDD
        end
    end
end)

AddEventHandler('gs_bridge:server:playerUnloaded', function(src) lastPos[src] = nil end)
