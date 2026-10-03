-- gs_rumors (client) : PNJ qui racontent (barmans, pompiste…) et indic'. PNJ créés à l'approche, [E] pour parler.
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error', duration = 9000 }) end end
local peds = {}

local function list(title, lines)
    local options = {}
    for _, l in ipairs(lines) do options[#options + 1] = { title = l, icon = 'comment-dots', readOnly = true } end
    lib.registerContext({ id = 'gs_rumors_list', title = title, options = options })
    lib.showContext('gs_rumors_list')
end

AddEventHandler('gs_rumors:client:teller', function(i)
    local t = Config.Tellers[i]
    lib.registerContext({ id = 'gs_rumors_teller', title = t.label, options = {
        { title = '« Quoi de neuf ? »', icon = 'ear-listen', onSelect = function()
            lib.notify({ title = t.label, description = lib.callback.await('gs_rumors:free', false), type = 'inform', icon = 'comment-dots', duration = 10000 })
        end },
        { title = ('« Ce que tu sais vraiment » (%d $)'):format(Config.Price), icon = 'money-bill', description = 'Les dernières nouvelles, avec les détails',
          onSelect = function()
            local ok, d = lib.callback.await('gs_rumors:paid', false)
            if not ok then return notify(false, d) end
            list(t.label, d)
        end },
    } })
    lib.showContext('gs_rumors_teller')
end)

AddEventHandler('gs_rumors:client:indic', function(i)
    local inf = Config.Informants[i]
    local gangs = lib.callback.await('gs_rumors:gangs', false) or {}
    local options = {}
    for _, g in ipairs(gangs) do
        options[#options + 1] = { title = g.label, icon = 'user-secret', description = ('%d $ · il sait des choses… et il parle'):format(Config.Indic.price),
            onSelect = function()
                local ok, d = lib.callback.await('gs_rumors:indic', false, g.name)
                if not ok then return notify(false, d) end
                list(inf.label .. ' · ' .. g.label, d)
            end }
    end
    if #options == 0 then options[1] = { title = '« Je ne connais personne. »', readOnly = true } end
    lib.registerContext({ id = 'gs_rumors_indic', title = inf.label, options = options })
    lib.showContext('gs_rumors_indic')
end)

local function spot(key, def, event, i, prompt)
    exports.gs_markers:Add('gs_rumors:' .. key, { coords = vec3(def.coords.x, def.coords.y, def.coords.z), style = 'hidden', event = event, args = { i },
        prompt = prompt, reach = 2.0 })
end

CreateThread(function()
    for i, t in ipairs(Config.Tellers) do spot('t' .. i, t, 'gs_rumors:client:teller', i, 'Parler à : ' .. t.label) end
    for i, inf in ipairs(Config.Informants) do spot('i' .. i, inf, 'gs_rumors:client:indic', i, 'Parler à l\'homme louche') end
    local all = {}
    for _, t in ipairs(Config.Tellers) do all[#all + 1] = t end
    for _, t in ipairs(Config.Informants) do all[#all + 1] = t end
    while true do
        local me = GetEntityCoords(cache.ped)
        for i, d in ipairs(all) do
            local c = vec3(d.coords.x, d.coords.y, d.coords.z)
            local dist = #(me - c)
            if dist < 60.0 and not peds[i] then
                local h = GetHashKey(d.model)
                if lib.requestModel(h, 5000) then
                    local p = CreatePed(4, h, c.x, c.y, c.z - 1.0, d.coords.w, false, true)
                    SetEntityInvincible(p, true) FreezeEntityPosition(p, true) SetBlockingOfNonTemporaryEvents(p, true)
                    TaskStartScenarioInPlace(p, i > #Config.Tellers and 'WORLD_HUMAN_SMOKING' or 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
                    SetModelAsNoLongerNeeded(h)
                    peds[i] = p
                end
            elseif dist > 80.0 and peds[i] then
                DeletePed(peds[i]) peds[i] = nil
            end
        end
        Wait(2000)
    end
end)

RegisterCommand('rumeurs', function()
    lib.notify({ title = 'Rumeurs', description = 'Les barmans, le pompiste de la Route 68 ou la patronne du Hen House savent toujours quelque chose.', type = 'inform', duration = 8000 })
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    exports.gs_markers:RemovePrefix('gs_rumors:')
    for _, p in pairs(peds) do if DoesEntityExist(p) then DeletePed(p) end end
end)
