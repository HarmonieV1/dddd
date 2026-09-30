-- gs_roadbook (client) : /carnet (liste), départ au premier point, GPS vers l'étape suivante, anecdote à l'arrivée d'étape,
-- [E] aux spots photo. Le serveur valide chaque étape.
local run   -- { route, step }
local blip

local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error', duration = 7000 }) end end

local function clear()
    run = nil
    if blip then RemoveBlip(blip) blip = nil end
    exports.gs_markers:RemovePrefix('gs_roadbook:photo:')
end

local function target()
    if blip then RemoveBlip(blip) blip = nil end
    local s = run and Config.Routes[run.route].steps[run.step + 1]
    if not s then return end
    blip = AddBlipForCoord(s.coords.x, s.coords.y, s.coords.z)
    SetBlipSprite(blip, 280) SetBlipColour(blip, 46) SetBlipRoute(blip, true) SetBlipRouteColour(blip, 46)
    BeginTextCommandSetBlipName('STRING') AddTextComponentSubstringPlayerName('Carnet : ' .. s.label) EndTextCommandSetBlipName(blip)
end

local function arrive(stepIndex)
    local s = Config.Routes[run.route].steps[stepIndex]
    lib.notify({ title = '📍 ' .. s.label, description = s.text .. (s.photo and '\n📸 Spot photo : [E] sur place.' or ''), type = 'inform', duration = 12000 })
    if s.photo then
        exports.gs_markers:Add('gs_roadbook:photo:' .. stepIndex, { coords = s.coords, style = 'objective', label = 'Spot photo', event = 'gs_roadbook:client:photo',
            args = { stepIndex }, prompt = 'Prendre une photo', reach = Config.PhotoRadius, distance = 60.0 })
    end
end

AddEventHandler('gs_roadbook:client:photo', function(stepIndex)
    if not lib.progressBar({ duration = 2500, label = 'Photo…', canCancel = true, anim = { scenario = 'WORLD_HUMAN_TOURIST_MOBILE' },
        disable = { move = true, car = true } }) then ClearPedTasks(cache.ped) return end
    ClearPedTasks(cache.ped)
    local ok, msg = lib.callback.await('gs_roadbook:photo', false, stepIndex)
    if ok then exports.gs_markers:Remove('gs_roadbook:photo:' .. stepIndex) PlaySoundFrontend(-1, 'Camera_Shoot', 'Phone_Soundset_Franklin', true) end
    notify(ok, msg)
end)

local function watch()
    CreateThread(function()
        while run do
            local s = Config.Routes[run.route].steps[run.step + 1]
            if s and #(GetEntityCoords(cache.ped) - s.coords) <= Config.Radius then
                local ok, step, done = lib.callback.await('gs_roadbook:step', false)
                if ok and run then
                    run.step = step
                    arrive(step)
                    if done then
                        local d = done
                        clear()
                        lib.notify({ title = '🏁 Carnet terminé : ' .. d.route, type = 'success', duration = 15000,
                            description = ('%d min · %d photo(s) · +%d XP%s%s%s'):format(d.seconds // 60, d.photos, d.xp, d.duo and ' (bonus duo)' or '',
                                d.title and ('\nNouveau titre : ' .. d.title) or '',
                                d.monthly and ('\n★ Road trip du mois : +%d $%s'):format(d.monthly.money,
                                    d.monthly.convoy > 0 and (' · convoi de %d'):format(d.monthly.convoy + 1) or '') or '') })
                    else target() end
                elseif not ok and step then notify(false, step) clear() end
                Wait(1500)
            end
            Wait(1000)
        end
    end)
end

RegisterCommand('carnet', function()
    local d = lib.callback.await('gs_roadbook:list', false)
    if not d then return end
    local options = { { title = d.title and ('Titre : ' .. d.title) or 'Aucun carnet terminé', icon = 'map', readOnly = true } }
    local m = d.monthly
    if m then
        local top = {}
        for i, t in ipairs(m.top) do top[i] = ('%d. %s — %d min%s'):format(i, t.name, t.minutes, t.convoy > 0 and ' (convoi)' or '') end
        options[#options + 1] = { title = ('★ Road trip de %s : %s'):format(m.month, m.label), icon = 'star', iconColor = '#ffd84a', readOnly = true,
            description = (m.done and 'Fait ce mois-ci ✔' or ('Premier fini du mois : XP x%s + %d $ · bonus si vous arrivez en convoi'):format(m.xpMult, m.money))
                .. (#top > 0 and ('\n' .. table.concat(top, '\n')) or '') }
    end
    for _, r in ipairs(d.routes) do
        local star = m and r.id == m.id
        options[#options + 1] = { title = (star and '★ ' or '') .. r.label, icon = r.best and 'circle-check' or 'route', iconColor = star and '#ffd84a' or (r.best and '#5aff8c' or nil),
            description = ('%s\n%d étapes · %d XP%s'):format(r.desc, r.steps, r.xp, r.best and (' · meilleur temps %d min'):format(r.best // 60) or ''),
            onSelect = function()
                local first = Config.Routes[r.id].steps[1]
                if #(GetEntityCoords(cache.ped) - first.coords) > Config.Radius then
                    SetNewWaypoint(first.coords.x, first.coords.y)
                    return notify(true, 'GPS posé sur le départ : ' .. first.label .. '. Relance /carnet une fois sur place.')
                end
                local ok, res = lib.callback.await('gs_roadbook:start', false, r.id)
                if not ok then return notify(false, res) end
                clear()
                run = { route = r.id, step = res }
                arrive(1)
                target()
                watch()
            end }
    end
    lib.registerContext({ id = 'gs_roadbook', title = 'Carnets de route Roadtrip', options = options })
    lib.showContext('gs_roadbook')
end, false)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then clear() end end)
