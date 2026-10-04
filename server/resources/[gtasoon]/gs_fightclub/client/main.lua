-- gs_fightclub (client) : l'organisateur n'apparaît que quand le serveur nous révèle le ring (on est sur place, la nuit).
-- Menu : s'inscrire (mise), parier, annuler. Pendant le combat : santé remise à 100 %, cercle du ring au sol.
local npc, ring, fighting = nil, nil, nil

local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end

local function clear()
    if npc and DoesEntityExist(npc) then DeleteEntity(npc) end
    npc = nil
    exports.gs_markers:Remove('gs_fightclub:npc')
end

RegisterNetEvent('gs_fightclub:client:ring', function(data)
    clear()
    ring = data
    if not data then return end
    local hash = GetHashKey(Config.Model)
    if lib.requestModel(hash, 5000) then
        npc = CreatePed(4, hash, data.npc.x, data.npc.y, data.npc.z - 1.0, data.npc.w, false, false)
        SetEntityInvincible(npc, true) FreezeEntityPosition(npc, true) SetBlockingOfNonTemporaryEvents(npc, true)
        TaskStartScenarioInPlace(npc, 'WORLD_HUMAN_SMOKING', 0, true)
        SetModelAsNoLongerNeeded(hash)
    end
    exports.gs_markers:Add('gs_fightclub:npc', { coords = vec3(data.npc.x, data.npc.y, data.npc.z), style = 'hidden', event = 'gs_fightclub:client:menu',
        prompt = 'Parler à l\'organisateur', distance = 6.0 })
    lib.notify({ title = 'Ring clandestin', description = 'Des cris, des billets qui circulent… c\'est ici.', type = 'inform', icon = 'hand-fist' })
end)

local function amountInput(min, max)
    local r = lib.inputDialog('Pari', { { type = 'number', label = ('Montant (%d à %d $, liquide)'):format(min, max), min = min, max = max, required = true } })
    return r and tonumber(r[1])
end

AddEventHandler('gs_fightclub:client:menu', function()
    local s = lib.callback.await('gs_fightclub:status', false)
    if not s then return end
    local options = {}
    if not s.open then
        options[1] = { title = '« Reviens à la nuit tombée. »', icon = 'moon', readOnly = true }
    elseif s.phase == 'none' then
        for _, stake in ipairs(s.stakes) do
            options[#options + 1] = { title = ('Combattre pour %d $'):format(stake), icon = 'hand-fist', description = 'Mains nues. Le gagnant rafle les deux mises (moins la part de la maison).',
                onSelect = function() notify(lib.callback.await('gs_fightclub:join', false, stake)) end }
        end
    elseif s.phase == 'waiting' then
        if s.mine then
            options[1] = { title = 'Annuler mon inscription', icon = 'xmark', onSelect = function() notify(lib.callback.await('gs_fightclub:leave', false)) end }
        else
            options[1] = { title = ('Affronter %s (%d $)'):format(s.a, s.stake), icon = 'hand-fist',
                onSelect = function() notify(lib.callback.await('gs_fightclub:join', false, s.stake)) end }
        end
    elseif s.phase == 'betting' and not s.me then
        if s.bet then
            options[1] = { title = ('Ton pari : %d $'):format(s.bet.amount), icon = 'sack-dollar', readOnly = true }
        else
            for _, side in ipairs({ 'a', 'b' }) do
                options[#options + 1] = { title = ('Parier sur %s'):format(side == 'a' and s.a or s.b), icon = 'sack-dollar',
                    onSelect = function()
                        local n = amountInput(s.min, s.max)
                        if n then notify(lib.callback.await('gs_fightclub:bet', false, side, n)) end
                    end }
            end
        end
    else
        options[1] = { title = ('%s contre %s'):format(s.a, s.b or '?'), description = s.me and 'C\'est ton combat !' or 'Combat en cours.', icon = 'hand-fist', readOnly = true }
    end
    lib.registerContext({ id = 'gs_fightclub_menu', title = 'Ring clandestin', options = options })
    lib.showContext('gs_fightclub_menu')
end)

RegisterNetEvent('gs_fightclub:client:start', function(center)
    fighting = center
    local ped = cache.ped
    SetEntityHealth(ped, GetEntityMaxHealth(ped)) SetPedArmour(ped, 0)
    SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
    lib.notify({ title = 'Combat', description = 'Mains nues. Rester dans le cercle. Le premier au tapis a perdu.', type = 'warning', icon = 'hand-fist', duration = 8000 })
    CreateThread(function()
        while fighting do
            DrawMarker(1, fighting.x, fighting.y, fighting.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, Config.Radius * 2, Config.Radius * 2, 0.4, 176, 72, 255, 90, false, false, 2, false, nil, nil, false)
            Wait(0)
        end
    end)
end)

RegisterNetEvent('gs_fightclub:client:stop', function() fighting = nil end)

RegisterNetEvent('gs_fightclub:client:ko', function()
    local ped = cache.ped
    SetPedToRagdoll(ped, 6000, 6000, 0, false, false, false)
    lib.notify({ description = 'Au tapis…', type = 'error', icon = 'face-dizzy' })
    SetTimeout(6000, function() if not IsEntityDead(ped) then SetEntityHealth(ped, math.max(GetEntityHealth(ped), 150)) end end)
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then clear() end end)
