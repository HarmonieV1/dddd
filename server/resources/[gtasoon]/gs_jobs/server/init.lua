-- Démarrage : schéma BDD, déclaration des jobs au framework, coffres, joueurs déjà connectés (restart à chaud).
CreateThread(function()
    DB.init()
    Bridge:RegisterJobs(Jobs)
    GSJ.registerStashes()
    for _, src in ipairs(Bridge:GetPlayers()) do GSJ.load(src) end
    local n = 0
    for _ in pairs(Jobs) do n = n + 1 end
    print(('[gs_jobs] prêt : %d jobs chargés'):format(n))
end)
