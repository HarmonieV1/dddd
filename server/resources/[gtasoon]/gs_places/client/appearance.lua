-- gs_places (client) : boutiques d'apparence du jeu (illenium-appearance) rendues visibles. Avant : seulement un logo
-- sur la carte, rien sur place → « coiffeur non fonctionnel ». Maintenant : un vendeur PNJ (coiffeur, tatoueur,
-- chirurgien, vendeuse) et un point [E] au comptoir. La zone ox_target d'illenium (tout le magasin) reste valable.
-- Coordonnées = celles d'illenium-appearance (Config.Stores, emplacement prévu pour son vendeur).
local KINDS = {
    barber   = { event = 'illenium-appearance:client:OpenBarberShop', prompt = 'Coiffeur', model = 's_m_m_hairdress_01', scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
    tattoo   = { event = 'illenium-appearance:client:OpenTattooShop', prompt = 'Tatoueur', model = 'u_m_y_tattoo_01', scenario = 'WORLD_HUMAN_SMOKING' },
    surgeon  = { event = 'illenium-appearance:client:OpenSurgeonShop', prompt = 'Chirurgien esthétique (visage)', model = 's_m_m_doctor_01', scenario = 'WORLD_HUMAN_CLIPBOARD' },
    clothing = { event = 'illenium-appearance:client:openClothingShopMenu', prompt = 'Boutique de vêtements', model = 's_f_y_shop_mid', scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
}
local STORES = {
    { 'clothing', vec4(1693.2, 4828.11, 42.07, 188.66) }, { 'clothing', vec4(-705.5, -149.22, 37.42, 122.0) },
    { 'clothing', vec4(-1192.61, -768.4, 17.32, 216.6) }, { 'clothing', vec4(425.91, -801.03, 29.49, 177.79) },
    { 'clothing', vec4(-168.73, -301.41, 39.73, 238.67) }, { 'clothing', vec4(75.39, -1398.28, 29.38, 6.73) },
    { 'clothing', vec4(-827.39, -1075.93, 11.33, 294.31) }, { 'clothing', vec4(-1445.86, -240.78, 49.82, 36.17) },
    { 'clothing', vec4(9.22, 6515.74, 31.88, 131.27) }, { 'clothing', vec4(615.35, 2762.72, 42.09, 170.51) },
    { 'clothing', vec4(1191.61, 2710.91, 38.22, 269.96) }, { 'clothing', vec4(-3171.32, 1043.56, 20.86, 334.3) },
    { 'clothing', vec4(-1105.52, 2707.79, 19.11, 317.19) }, { 'clothing', vec4(-1119.24, -1440.6, 5.23, 300.5) },
    { 'clothing', vec4(124.82, -224.36, 54.56, 335.41) },
    { 'barber', vec4(-814.22, -183.7, 37.57, 116.91) }, { 'barber', vec4(136.78, -1708.4, 29.29, 144.19) },
    { 'barber', vec4(-1282.57, -1116.84, 6.99, 89.25) }, { 'barber', vec4(1931.41, 3729.73, 32.84, 212.08) },
    { 'barber', vec4(1212.8, -472.9, 65.2, 60.94) }, { 'barber', vec4(-32.9, -152.3, 56.1, 335.22) },
    { 'barber', vec4(-278.1, 6228.5, 30.7, 49.32) },
    { 'tattoo', vec4(1322.6, -1651.9, 51.2, 42.47) }, { 'tattoo', vec4(-1154.01, -1425.31, 4.95, 23.21) },
    { 'tattoo', vec4(322.62, 180.34, 103.59, 156.2) }, { 'tattoo', vec4(-3169.52, 1074.86, 20.83, 253.29) },
    { 'tattoo', vec4(1864.1, 3747.91, 33.03, 17.23) }, { 'tattoo', vec4(-294.24, 6200.12, 31.49, 195.72) },
    { 'surgeon', vec4(298.78, -572.81, 43.26, 114.27) },
}
Appearance = { STORES = STORES, KINDS = KINDS }

local peds = {}

local function spawnPed(i, kind, c)
    local hash = GetHashKey(kind.model)
    if not lib.requestModel(hash, 5000) then return end
    local ped = CreatePed(4, hash, c.x, c.y, c.z - 1.0, c.w, false, true)
    SetModelAsNoLongerNeeded(hash)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStartScenarioInPlace(ped, kind.scenario, 0, true)
    peds[i] = ped
end

-- Le point [E] est 1 m devant le vendeur (sinon on serait dans le PNJ)
local function front(c)
    local h = math.rad(c.w)
    return vec3(c.x - math.sin(h) * 1.0, c.y + math.cos(h) * 1.0, c.z)
end

AddEventHandler('gs_places:client:appearance', function(kindName)
    local k = KINDS[kindName]
    if k then TriggerEvent(k.event) end
end)

CreateThread(function()
    if GetResourceState('illenium-appearance') == 'missing' then return end
    for i, s in ipairs(STORES) do
        local kind = KINDS[s[1]]
        exports.gs_markers:Add('gs_places:app:' .. i, { coords = front(s[2]), style = 'shop', label = kind.prompt, prompt = kind.prompt,
            event = 'gs_places:client:appearance', args = { s[1] }, reach = 1.6 })
    end
    -- Vendeurs : créés à l'approche (60 m), supprimés au départ (pas 30 PNJ permanents)
    while true do
        local me = GetEntityCoords(PlayerPedId())
        for i, s in ipairs(STORES) do
            local d = #(me - s[2].xyz)
            if d < 60.0 and not peds[i] then spawnPed(i, KINDS[s[1]], s[2])
            elseif d > 80.0 and peds[i] then
                if DoesEntityExist(peds[i]) then DeletePed(peds[i]) end
                peds[i] = nil
            end
        end
        Wait(1500)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, p in pairs(peds) do if DoesEntityExist(p) then DeletePed(p) end end
end)
