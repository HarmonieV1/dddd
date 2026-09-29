-- Démarrage : schéma BDD, déclaration des jobs au framework, coffres, joueurs déjà connectés (restart à chaud).
CreateThread(function()
    DB.init()
    Bridge:RegisterJobs(Jobs)
    GSJ.loadPoints()
    GSJ.loadSalaries()
    GSJ.registerStashes()
    GSJ.checkArmories()
    for name, def in pairs(Jobs) do
        for action, a in pairs(def.vehicleActions or {}) do
            if a.item and not Bridge:ItemExists(a.item) then
                print(('^3[gs_jobs] %s/%s : item "%s" absent d\'ox_inventory (à déclarer, voir docs/JOBS.md)^7'):format(name, action, a.item))
            end
        end
    end
    for _, src in ipairs(Bridge:GetPlayers()) do GSJ.load(src) end
    local n = 0
    for _ in pairs(Jobs) do n = n + 1 end
    print(('[gs_jobs] prêt : %d jobs chargés'):format(n))
end)
