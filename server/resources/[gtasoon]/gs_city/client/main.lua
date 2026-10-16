-- gs_city (client) : message en entrant dans un quartier tendu, densité de passants / trafic réduite (lue par gs_world),
-- commande /quartiers.
local peds, vehicles = 1.0, 1.0
local lastKey

local function districtAt(coords)
    local p, best, bestD = vec2(coords.x, coords.y), nil, nil
    for _, d in ipairs(Config.Districts) do
        local dist = #(p - d.center)
        if dist <= d.radius and (not bestD or dist < bestD) then best, bestD = d, dist end
    end
    return best
end

--- Multiplicateurs de densité du quartier où se trouve le joueur (lus par gs_world toutes les 10 s).
exports('GetDensity', function() return peds, vehicles end)

CreateThread(function()
    while true do
        local d = districtAt(GetEntityCoords(cache.ped))
        local lvl = d and (GlobalState.gsCity or {})[d.id] or 1
        local l = Config.Levels[lvl] or Config.Levels[1]
        peds, vehicles = l.peds or 1.0, l.vehicles or 1.0
        local key = d and (d.id .. ':' .. lvl) or nil
        if key ~= lastKey then
            if d and lvl > 1 and l.enter then
                lib.notify({ title = d.label, description = l.enter, type = lvl >= 3 and 'error' or 'warning', icon = 'city', duration = 9000 })
            end
            lastKey = key
        end
        Wait(3000)
    end
end)

local ICONS = { 'sun', 'triangle-exclamation', 'fire' }
local COLORS = { '#5aff8c', '#ffb347', '#ff5a5a' }

RegisterCommand('quartiers', function()
    local list = lib.callback.await('gs_city:status', false)
    if not list then return end
    local options = {}
    for _, q in ipairs(list) do
        options[#options + 1] = { title = q.label, icon = ICONS[q.level], iconColor = COLORS[q.level], readOnly = true,
            description = ('Ambiance : %s · Quartier %s'):format(q.name, q.standing or 'ordinaire'), progress = q.pct, colorScheme = q.level >= 3 and 'red' or (q.level == 2 and 'orange' or 'green') }
    end
    lib.registerContext({ id = 'gs_city_status', title = 'Los Santos : ambiance des quartiers', options = options })
    lib.showContext('gs_city_status')
end, false)

-- V11.2 · /gazette : dernière édition (et un aperçu de celle de dimanche)
RegisterCommand(Config.Gazette.command, function()
    local last, preview = lib.callback.await('gs_city:gazette', false)
    if not preview then return end
    lib.alertDialog({ header = Config.Gazette.name, size = 'lg', centered = true,
        content = last or ('Pas encore d\'édition : la première sort dimanche à %d h.\n\n**Aperçu de la semaine**\n\n%s'):format(Config.Gazette.hour, preview) })
end, false)

-- V12.63 · /voisins : voisins vigilants du quartier (proposition n° 173)
RegisterCommand('voisins', function()
    local info = lib.callback.await('gs_city:watchInfo', false)
    if not info then return end
    local options = {
        { title = info.mine and ('Ton groupe : %s'):format(info.mine) or 'Tu ne fais partie d\'aucun groupe', icon = 'eye', readOnly = true,
          description = 'Prévenu des délits signalés dans ton quartier ; plus vous êtes nombreux, plus le calme revient vite.' },
    }
    if info.here then
        options[#options + 1] = { title = ('%s : %d bénévole(s) connecté(s)'):format(info.here, info.count), icon = 'users', readOnly = true }
        if not info.gang and info.mine ~= info.here then
            options[#options + 1] = { title = 'Rejoindre les voisins vigilants de ' .. info.here, icon = 'hand-holding-heart', onSelect = function()
                local ok, msg = lib.callback.await('gs_city:watchJoin', false, true)
                lib.notify({ type = ok and 'success' or 'error', description = msg })
            end }
        end
    end
    if info.mine then
        options[#options + 1] = { title = 'Quitter mon groupe', icon = 'right-from-bracket', onSelect = function()
            local ok, msg = lib.callback.await('gs_city:watchJoin', false, false)
            lib.notify({ type = ok and 'success' or 'error', description = msg })
        end }
    end
    lib.registerContext({ id = 'gs_city_watch', title = 'Voisins vigilants', options = options })
    lib.showContext('gs_city_watch')
end, false)
