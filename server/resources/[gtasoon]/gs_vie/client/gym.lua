-- gs_vie (client) · V12.64 · Salle de sport : [E] au point de la salle → choix de l'exercice (✓ = déjà fait dans la séance),
-- animation de `duration` ms. Bonus d'endurance : statistiques de souffle du jeu au maximum et récupération plus rapide au
-- sprint, le temps du bonus ; tout revient comme avant à la fin.
local G = Config.Gym
local busy, bonusUntil, saved = false, 0, nil

local function notify(ok, msg) if msg then lib.notify({ title = 'Salle de sport', description = msg, type = ok and 'success' or 'error', duration = 6000 }) end end

local function stat(name) return GetHashKey('MP0_' .. name) end

local function applyBonus(seconds)
    bonusUntil = GetGameTimer() + seconds * 1000
    if not saved then
        local _, s = StatGetInt(stat('STAMINA'), -1)
        local _, l = StatGetInt(stat('LUNG_CAPACITY'), -1)
        saved = { stamina = s or 0, lung = l or 0 }
    end
    StatSetInt(stat('STAMINA'), G.bonus.stamina, true)
    StatSetInt(stat('LUNG_CAPACITY'), G.bonus.lung, true)
    CreateThread(function()
        local mine = bonusUntil
        while bonusUntil == mine and GetGameTimer() < bonusUntil do
            local pid = PlayerId()
            if IsPedSprinting(cache.ped) and GetPlayerSprintStaminaRemaining(pid) < 60.0 then RestorePlayerStamina(pid, G.bonus.regen) end
            Wait(1000)
        end
        if bonusUntil ~= mine then return end -- un nouveau bonus a pris le relais
        if saved then
            StatSetInt(stat('STAMINA'), saved.stamina, true)
            StatSetInt(stat('LUNG_CAPACITY'), saved.lung, true)
            saved = nil
        end
        notify(false, 'Ton bonus d\'endurance est fini : retourne à la salle !')
    end)
end
RegisterNetEvent('gs_vie:client:gymBonus', function(seconds) applyBonus(tonumber(seconds) or 0) end)
-- V12.64 · la musculation de la prison fait progresser la forme pour de bon : pendant le bonus, ce progrès est gardé pour la fin
AddEventHandler('gs_vie:client:statProgress', function(n)
    if not saved then return end
    n = tonumber(n) or 0
    saved.stamina = math.min(100, saved.stamina + n)
end)

local function exercise(e)
    if busy then return end
    local ok, duration = lib.callback.await('gs_vie:gymBegin', false, e.id)
    if not ok then return notify(false, duration) end
    busy = true
    local prop
    if e.prop then
        prop = { model = GetHashKey(e.prop.model), bone = e.prop.bone, pos = vec3(e.prop.pos[1], e.prop.pos[2], e.prop.pos[3]),
            rot = vec3(e.prop.rot[1], e.prop.rot[2], e.prop.rot[3]) }
    end
    local done = lib.progressBar({ -- [API] ox_lib
        duration = duration, label = e.label .. '…', canCancel = true, disable = { move = true, car = true, combat = true },
        anim = { dict = e.anim.dict, clip = e.anim.clip, flag = 1 }, prop = prop,
    })
    busy = false
    ClearPedTasks(cache.ped)
    if not done then return TriggerServerEvent('gs_vie:server:gymCancel') end
    notify(lib.callback.await('gs_vie:gymFinish', false))
end

local function menu()
    local st = lib.callback.await('gs_vie:gymStatus', false)
    if not st then return end
    local options = {
        { title = ('Séance : %d / %d exercices différents'):format(st.count, st.need), icon = 'stopwatch', readOnly = true,
          description = st.bonus > 0 and ('Bonus d\'endurance actif : encore %d min'):format(math.ceil(st.bonus / 60))
              or ('Finis-la en %d min pour gagner %d h de bonus d\'endurance'):format(math.ceil(st.left / 60), G.hours) },
    }
    for _, e in ipairs(G.exercises) do
        if e.prison then goto continue end -- tractions : barre de la cour de la prison seulement
        local did = st.done[e.id]
        options[#options + 1] = { title = (did and '✓ ' or '') .. e.label, icon = e.icon, disabled = did == true,
            description = did and 'Déjà fait dans cette séance' or ('%d s'):format(math.floor(G.duration / 1000)),
            onSelect = function() exercise(e) end }
        ::continue::
    end
    lib.registerContext({ id = 'gs_vie_gym', title = 'Salle de sport', options = options })
    lib.showContext('gs_vie_gym')
end
AddEventHandler('gs_vie:client:gym', menu)

CreateThread(function()
    for i, p in ipairs(G.places) do
        exports.gs_markers:Add('gs_vie:gym:' .. i, { coords = p.coords, style = 'job', label = p.label, event = 'gs_vie:client:gym', -- [API] gs_markers
            prompt = 'Salle de sport · s\'entraîner', distance = 15.0, reach = 2.5 })
        if p.blip then
            local b = AddBlipForCoord(p.coords.x, p.coords.y, p.coords.z)
            SetBlipSprite(b, 311) SetBlipColour(b, 7) SetBlipScale(b, 0.7) SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName('Salle de sport') EndTextCommandSetBlipName(b)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    pcall(function() exports.gs_markers:RemovePrefix('gs_vie:gym:') end)
    if saved then StatSetInt(stat('STAMINA'), saved.stamina, true) StatSetInt(stat('LUNG_CAPACITY'), saved.lung, true) end
end)
