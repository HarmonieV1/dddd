-- gs_casino (client) : roue posée dans le casino (props du jeu, locaux), [E] pour tourner, animation jusqu'à la case tirée
-- par le serveur ; ticket à gratter utilisé depuis l'inventaire (ox_inventory → export scratch).
local W = Config.Wheel
local wheel, base
local spinning = false

local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error' }) end end

local function loadModel(name)
    local hash = GetHashKey(name)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(0) end
    return HasModelLoaded(hash) and hash or nil
end

local function spawnWheel()
    if wheel and DoesEntityExist(wheel) then return end
    local hb, hw = loadModel('vw_prop_vw_luckywheel_01a'), loadModel('vw_prop_vw_luckywheel_02a') -- [API] props DLC casino
    if not hb or not hw then return end
    base = CreateObject(hb, W.base.x, W.base.y, W.base.z, false, false, false)
    wheel = CreateObject(hw, W.coords.x, W.coords.y, W.coords.z, false, false, false)
    for _, e in ipairs({ base, wheel }) do SetEntityHeading(e, W.heading) FreezeEntityPosition(e, true) end
    SetModelAsNoLongerNeeded(hb) SetModelAsNoLongerNeeded(hw)
end

local function despawnWheel()
    for _, e in ipairs({ wheel, base }) do if e and DoesEntityExist(e) then DeleteEntity(e) end end
    wheel, base = nil, nil
end

-- Props créés seulement quand on est dans le casino (intérieur sous la map)
CreateThread(function()
    while true do
        local near = #(GetEntityCoords(cache.ped) - W.coords) < 80.0
        if near and not wheel then spawnWheel() elseif not near and wheel then despawnWheel() end
        Wait(2000)
    end
end)

AddEventHandler('gs_casino:client:wheel', function()
    if spinning then return end
    local st = lib.callback.await('gs_casino:status', false)
    if st and not st.wheel then return notify(false, 'Tu as déjà tourné la roue aujourd\'hui. Reviens demain !') end
    local ok, idx, label = lib.callback.await('gs_casino:spin', false)
    if not ok then return notify(false, idx) end
    spinning = true
    -- 20 cases de 18° : plusieurs tours puis arrêt en douceur sur la case tirée
    local n = #W.segments
    local target = 360.0 * 6 + (idx - 1) * (360.0 / n)
    local start = GetGameTimer()
    -- par frame : animation de la roue, quelques secondes seulement
    while true do
        local t = math.min(1.0, (GetGameTimer() - start) / W.spinMs)
        local eased = 1.0 - (1.0 - t) ^ 3
        if wheel and DoesEntityExist(wheel) then SetEntityRotation(wheel, 0.0, eased * target, W.heading, 2, true) end
        if t >= 1.0 then break end
        Wait(0)
    end
    spinning = false
    PlaySoundFrontend(-1, 'WIN', 'HUD_AWARDS', true)
    lib.notify({ title = 'Roue de la fortune', description = 'Gagné : ' .. label, type = 'success', duration = 8000 })
end)

CreateThread(function()
    exports.gs_markers:Add('gs_casino:wheel', { coords = W.stand, style = 'shop', label = 'Roue de la fortune',
        event = 'gs_casino:client:wheel', prompt = 'Tourner la roue (1 fois par jour)', reach = W.range, distance = 20.0 })
end)

-- Ticket à gratter (item scratch_ticket, client.export = 'gs_casino.scratch')
exports('scratch', function()
    if not lib.progressBar({ duration = Config.Scratch.scratchMs, label = 'Tu grattes le ticket…', canCancel = true,
        anim = { dict = 'mp_common', clip = 'givetake1_a' }, disable = { move = false, car = false, combat = true } }) then return end
    local ok, cash = lib.callback.await('gs_casino:scratch', false)
    if not ok then return notify(false, cash) end
    if cash > 0 then
        PlaySoundFrontend(-1, 'WIN', 'HUD_AWARDS', true)
        lib.notify({ title = 'Ticket à gratter', description = ('Gagnant : %d $ en liquide !'):format(cash), type = 'success', duration = 7000 })
    else
        lib.notify({ title = 'Ticket à gratter', description = 'Perdu… Retente ta chance demain.', type = 'inform' })
    end
end)

AddEventHandler('gs_casino:client:lotto', function()
    local info = lib.callback.await('gs_casino:lottoInfo', false)
    if not info then return notify(false, 'Caisse indisponible.') end
    local last = info.last
    local lines = {}
    if last then
        if #last.winners == 0 then lines[1] = ('Dernier tirage : reporté (%d $)'):format(last.carried)
        else for i, w in ipairs(last.winners) do lines[#lines + 1] = ('%d. %s : %d $'):format(i, w.name, w.amount) end end
    end
    lib.registerContext({ id = 'gs_lotto', title = 'Loto de Los Santos', options = {
        { title = ('Cagnotte : %d $'):format(info.pot), description = ('%d ticket(s) vendus · tirage dimanche %dh'):format(info.sold, Config.Lotto.drawHour), icon = 'sack-dollar', readOnly = true },
        { title = ('Tes tickets : %d / %d'):format(info.mine, info.max), icon = 'ticket', readOnly = true },
        { title = ('Acheter (%d $ le ticket)'):format(info.price), icon = 'cart-shopping', onSelect = function()
            local r = lib.inputDialog('Loto', { { type = 'number', label = 'Combien de tickets ?', default = 1, min = 1, max = info.max - info.mine, required = true } })
            if r then notify(lib.callback.await('gs_casino:lottoBuy', false, r[1])) end
        end },
        { title = last and 'Dernier tirage' or 'Aucun tirage pour l\'instant', description = table.concat(lines, ' · '), icon = 'trophy', readOnly = true },
    } })
    lib.showContext('gs_lotto')
end)

CreateThread(function()
    exports.gs_markers:Add('gs_casino:lotto', { coords = Config.Lotto.cashier, style = 'shop', label = 'Loto', event = 'gs_casino:client:lotto',
        prompt = 'Loto hebdomadaire', reach = Config.Lotto.range, distance = 20.0 })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then despawnWheel() exports.gs_markers:RemovePrefix('gs_casino:') end
end)
