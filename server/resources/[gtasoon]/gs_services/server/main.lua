-- gs_services (serveur) : secouriste IA. Le client ne fait que l'animation ; l'appel, la durée, le paiement
-- et la réanimation sont décidés ici.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local JobsApi  = exports.gs_jobs

Services = { pending = {}, last = {} } -- pending[src] = heure de fin ; last[src] = dernier appel (os.time)

local function emsOnDuty() return #JobsApi:GetOnDutyPlayers(Config.EmsJob) end

lib.callback.register('gs_services:medicStatus', function(src)
    if not Security:RateLimit(src, 'gs_services:status', 5, 10000) then return nil end
    return { available = emsOnDuty() < Config.Medic.minEms, fee = Config.Medic.fee }
end)

lib.callback.register('gs_services:callMedic', function(src)
    if not Security:RateLimit(src, 'gs_services:call', 2, 10000) then return false, 'Doucement.' end
    if not Bridge:IsDowned(src) then return false, 'Tu n\'as pas besoin de secours.' end
    if emsOnDuty() >= Config.Medic.minEms then return false, 'Des ambulanciers sont en service : appelle-les (téléphone).' end
    if Services.pending[src] then return false, 'Les secours arrivent.' end
    if Services.last[src] and os.time() - Services.last[src] < Config.Medic.cooldown then
        return false, 'Les secours sont déjà passés il y a peu.'
    end
    Services.last[src] = os.time()
    Services.pending[src] = GetGameTimer() + (Config.Medic.seconds - 2) * 1000
    return true, Config.Medic.seconds
end)

lib.callback.register('gs_services:medicDone', function(src)
    if not Security:RateLimit(src, 'gs_services:done', 3, 10000) then return false, 'Doucement.' end
    local doneAt = Services.pending[src]
    if not doneAt then return false, 'Aucun secours en cours.' end
    if GetGameTimer() < doneAt then return false, 'Le secouriste n\'a pas fini.' end
    Services.pending[src] = nil
    if not Bridge:IsDowned(src) then return false, 'Déjà sur pied.' end
    local fee, paid = Config.Medic.fee, 'gratuitement (tu n\'avais rien sur toi)'
    if Bridge:RemoveMoney(src, 'bank', fee, 'secours IA') or Bridge:RemoveMoney(src, 'cash', fee, 'secours IA') then
        paid = ('pour %d $'):format(fee)
    end
    Bridge:Revive(src)
    return true, 'Le secouriste t\'a remis sur pied ' .. paid .. '.'
end)

AddEventHandler('gs_bridge:server:playerUnloaded', function(src) Services.pending[src], Services.last[src] = nil, nil end)
