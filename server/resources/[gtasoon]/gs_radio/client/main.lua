-- gs_radio (client) : on règle sa fréquence une fois, ensuite on parle en maintenant Verr. Maj (pma-voice), sans rouvrir
-- de menu. La dernière fréquence est retenue et reprise à la connexion si on a toujours une radio sur soi.
local voice = exports['pma-voice']
local current = 0

local function hasRadio()
    return (exports.ox_inventory:Search('count', Config.Item) or 0) > 0
end

local function leave(silent)
    if current == 0 then return end
    current = 0
    voice:setRadioChannel(0)
    voice:setVoiceProperty('radioEnabled', false)
    if not silent then lib.notify({ description = 'Radio éteinte.', type = 'inform', icon = 'walkie-talkie' }) end
end

local function watchItem()
    CreateThread(function()
        while current ~= 0 do
            Wait(Config.ItemCheck)
            if current ~= 0 and (not hasRadio() or LocalPlayer.state.isDead) then
                leave(true)
                lib.notify({ description = 'Plus de radio sur toi : déconnecté.', type = 'error', icon = 'walkie-talkie' })
            end
        end
    end)
end

local function join(channel, label)
    channel = tonumber(channel)
    if not channel or channel <= 0 or channel > Config.MaxChannel then return lib.notify({ description = 'Fréquence invalide.', type = 'error' }) end
    channel = math.floor(channel * 100 + 0.5) / 100
    if not hasRadio() then return lib.notify({ description = 'Il te faut une radio (quincaillerie).', type = 'error', icon = 'walkie-talkie' }) end
    if not lib.callback.await('gs_radio:canJoin', false, channel) then
        return lib.notify({ description = 'Canal réservé.', type = 'error', icon = 'lock' })
    end
    local wasOff = current == 0
    current = channel
    voice:setVoiceProperty('radioEnabled', true)
    voice:setRadioChannel(channel)
    SetResourceKvp('gs_radio:last', tostring(channel))
    lib.notify({ title = 'Radio ' .. channel .. ' MHz', description = (label and (label .. ' · ') or '') .. 'Maintiens Verr. Maj pour parler.',
        type = 'success', icon = 'walkie-talkie' })
    if wasOff then watchItem() end
end

local function openMenu()
    local presets = lib.callback.await('gs_radio:presets', false) or {}
    local options = {}
    for _, p in ipairs(presets) do
        options[#options + 1] = { title = ('%s · %s'):format(p.label, p.gang and 'canal privé' or (p.channel .. ' MHz')), icon = p.gang and 'people-group' or 'briefcase',
            iconColor = current == p.channel and '#5aff8c' or nil, onSelect = function() join(p.channel, p.label) end }
    end
    options[#options + 1] = { title = 'Fréquence libre…', icon = 'sliders', onSelect = function()
        local r = lib.inputDialog('Fréquence', { { type = 'number', label = 'MHz (11 à 499 : libres)', min = 1, max = Config.MaxChannel, precision = 2, step = 0.1, required = true } })
        if r then join(r[1]) end
    end }
    local last = tonumber(GetResourceKvpString('gs_radio:last') or '')
    if last and last ~= current then
        options[#options + 1] = { title = ('Reprendre %s MHz'):format(last), icon = 'rotate-left', onSelect = function() join(last) end }
    end
    if current ~= 0 then
        options[#options + 1] = { title = 'Éteindre la radio', icon = 'power-off', iconColor = '#ff2e88', onSelect = function() leave() end }
    end
    lib.registerContext({ id = 'gs_radio', title = current ~= 0 and ('Radio · %s MHz'):format(current) or 'Radio · éteinte', options = options })
    lib.showContext('gs_radio')
end

RegisterCommand('radio', function(_, args)
    if args[1] == 'off' then return leave() end
    if args[1] then return join(args[1]) end
    openMenu()
end, false)

lib.addRadialItem({ id = 'gs_radio', icon = 'walkie-talkie', label = 'Radio', onSelect = openMenu }) -- [API] ox_lib (menu Z)

-- Reprise automatique à la connexion (même fréquence, si la radio est toujours dans les poches).
AddStateBagChangeHandler('isLoggedIn', ('player:%s'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
    if not value then return leave(true) end
    SetTimeout(8000, function()
        local last = tonumber(GetResourceKvpString('gs_radio:last') or '')
        if last and current == 0 and hasRadio() then join(last) end
    end)
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then leave(true) end end)
