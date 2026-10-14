-- gs_vie (serveur) · V12.57 Mesure de charge (/perfserveur, staff) : pendant un test à plusieurs (bêta, test de charge),
-- mesure le retard de la boucle du serveur (« hitch ») toutes les 50 ms, puis écrit un résumé par minute dans
-- resources/[gtasoon]/gs_vie/perf-serveur.log. /perfserveur stop arrête et affiche le bilan. Aucun coût hors mesure.
Perf = { running = false }

--- Résumé d'une liste de retards (ms) : moyenne, 95e centile, pire, nombre de retards > 100 ms
function Perf.summary(samples)
    local n = #samples
    if n == 0 then return { n = 0, avg = 0, p95 = 0, max = 0, spikes = 0 } end
    local sorted, sum, spikes = {}, 0, 0
    for i, v in ipairs(samples) do
        sorted[i] = v
        sum = sum + v
        if v > 100 then spikes = spikes + 1 end
    end
    table.sort(sorted)
    return { n = n, avg = sum / n, p95 = sorted[math.max(1, math.ceil(n * 0.95))], max = sorted[n], spikes = spikes }
end

function Perf.line(minute, players, s)
    return ('%s · minute %d · %d joueur(s) · retard moyen %.1f ms · 95%% sous %.0f ms · pire %.0f ms · %d accroc(s) > 100 ms')
        :format(os.date('%H:%M'), minute, players, s.avg, s.p95, s.max, s.spikes)
end

local log = {}
local function write()
    SaveResourceFile(GetCurrentResourceName(), Config.Perf.file, table.concat(log, '\n') .. '\n', -1)
end

local function report(src, msg)
    if src > 0 then TriggerClientEvent('chat:addMessage', src, { args = { 'Perf', msg } }) end
    print('[gs_vie] ' .. msg)
end

function Perf.start(src)
    if Perf.running then return false end
    Perf.running = true
    log = { ('Mesure de charge RoadLine · début %s'):format(os.date('%d/%m/%Y %H:%M')) }
    CreateThread(function()
        local minute, all = 0, {}
        while Perf.running and minute < Config.Perf.maxMinutes do
            local samples, t0 = {}, GetGameTimer()
            while Perf.running and GetGameTimer() - t0 < 60000 do
                local a = GetGameTimer()
                Wait(Config.Perf.tick)
                local late = GetGameTimer() - a - Config.Perf.tick
                samples[#samples + 1] = late > 0 and late or 0
            end
            minute = minute + 1
            for _, v in ipairs(samples) do all[#all + 1] = v end
            log[#log + 1] = Perf.line(minute, #GetPlayers(), Perf.summary(samples))
            write()
        end
        local s = Perf.summary(all)
        log[#log + 1] = ('BILAN · %d min · retard moyen %.1f ms · pire %.0f ms · %d accroc(s) > 100 ms'):format(minute, s.avg, s.max, s.spikes)
        write()
        report(src, log[#log] .. ' (journal : gs_vie/' .. Config.Perf.file .. ')')
        Perf.running = false
    end)
    return true
end

RegisterCommand('perfserveur', function(src, args)
    if src > 0 and not IsPlayerAceAllowed(src, 'gs.admin.admin') then return end
    if args[1] == 'stop' then
        if not Perf.running then return report(src, 'Aucune mesure en cours.') end
        Perf.running = false
        return report(src, 'Arrêt demandé : le bilan arrive dans quelques secondes.')
    end
    if not Perf.start(src) then return report(src, 'Une mesure tourne déjà (/perfserveur stop pour l\'arrêter).') end
    report(src, ('Mesure lancée (1 ligne par minute, %d min maximum). /perfserveur stop pour finir.'):format(Config.Perf.maxMinutes))
end, false)
