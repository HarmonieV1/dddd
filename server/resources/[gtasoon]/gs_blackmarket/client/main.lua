-- gs_blackmarket (client) : /contact = appeler son contact (GPS vers la planque du jour, gang ou réputation de rue).
-- Le PNJ n'existe que pour ceux qui ont accès, à moins de 60 m. On lui parle avec ox_target.
local ped, loc
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error', duration = 7000 }) end end

local function buy(e)
    local r = lib.inputDialog(e.label, { { type = 'select', label = 'Paiement', required = true, default = 'dirty', options = {
        { value = 'dirty', label = ('Argent sale : %d $'):format(e.price) }, { value = 'cash', label = ('Liquide : %d $'):format(e.cashPrice) } } } })
    if r then notify(lib.callback.await('gs_blackmarket:buy', false, e.index, r[1])) end
end

local function openShop()
    local list, msg = lib.callback.await('gs_blackmarket:catalog', false)
    if not list then return notify(false, msg) end
    local options = {}
    for _, e in ipairs(list) do
        options[#options + 1] = { title = e.label, icon = e.weapon and 'gun' or 'box', disabled = e.left <= 0,
            description = e.left > 0 and ('%d $ sale · %d $ liquide · reste %d'):format(e.price, e.cashPrice, e.left) or 'Rupture',
            onSelect = function() buy(e) openShop() end }
    end
    lib.registerContext({ id = 'gs_blackmarket', title = 'Le contact', options = options })
    lib.showContext('gs_blackmarket')
end

local function despawn()
    if ped and DoesEntityExist(ped) then exports.ox_target:removeLocalEntity(ped) DeletePed(ped) end
    ped = nil
end

local function spawn()
    local hash = GetHashKey(Config.Dealer.model)
    lib.requestModel(hash, 5000)
    ped = CreatePed(4, hash, loc.x, loc.y, loc.z - 1.0, loc.w, false, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_SMOKING', 0, true)
    exports.ox_target:addLocalEntity(ped, { { name = 'gs_blackmarket', icon = 'fa-solid fa-mask', label = 'Parler au contact', distance = 2.5, onSelect = openShop } })
end

RegisterCommand('contact', function()
    local where, msg = lib.callback.await('gs_blackmarket:where', false)
    if not where then return notify(false, msg) end
    loc = vec4(where.x, where.y, where.z, where.w)
    SetNewWaypoint(where.x, where.y)
    notify(true, where.open and 'Ton contact t\'attend (GPS posé). Viens discret.' or 'Ton contact ne sort que la nuit (20 h – 6 h). GPS posé.')
end, false)

-- Planque du jour rafraîchie toutes les 5 min (seulement pour ceux qui y ont accès), PNJ à moins de 60 m.
CreateThread(function()
    local nextRefresh = 0
    while true do
        if GetGameTimer() > nextRefresh and LocalPlayer.state.isLoggedIn then
            nextRefresh = GetGameTimer() + 300000
            local where = lib.callback.await('gs_blackmarket:where', false)
            local newLoc = where and vec4(where.x, where.y, where.z, where.w) or nil
            if not newLoc or not loc or #(newLoc.xyz - loc.xyz) > 1.0 then despawn() end
            loc = newLoc
        end
        if loc then
            local d = #(GetEntityCoords(cache.ped) - loc.xyz)
            if d < 60.0 and not ped then spawn() elseif d > 80.0 and ped then despawn() end
        end
        Wait(2000)
    end
end)

AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then despawn() end end)
