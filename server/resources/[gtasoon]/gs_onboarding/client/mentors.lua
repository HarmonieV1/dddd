-- gs_onboarding (client) · V8 « Mentors » : /mentor (parrain : disponibilité, filleuls, GPS ; nouveau : choisir un parrain).
local function notify(ok, msg) if msg then lib.notify({ description = msg, type = ok and 'success' or 'error', duration = 7000 }) end end
local function call(action, arg) return lib.callback.await('gs_onboarding:mentor', false, action, arg) end

local function menu()
    local ok, d = call('info')
    if not ok or not d then return end
    local options = {}
    if d.role == 'mentor' then
        options[#options + 1] = { title = d.available and 'Disponible comme parrain ✔' or 'Me rendre disponible comme parrain', icon = 'hands-holding-child',
            description = ('Filleuls : %d / %d · prime quand un filleul reste 7 jours'):format(#d.mentees, d.max), onSelect = function() notify(call('toggle')) end }
        for _, m in ipairs(d.mentees) do
            options[#options + 1] = { title = m.name, icon = m.online and 'location-dot' or 'user-clock', iconColor = m.online and '#5aff8c' or '#6b6380',
                description = ('%d jour(s) de jeu%s%s'):format(m.days, m.rewarded and ' · resté ✔' or '', m.online and ' · en ville : GPS' or ''),
                onSelect = m.online and function()
                    local ok2, c = call('locate', m.cid)
                    if not ok2 then return notify(false, c) end
                    SetNewWaypoint(c.x, c.y) notify(true, 'GPS vers ton filleul.')
                end or nil }
        end
    elseif d.role == 'newbie' and d.mentor then
        options[#options + 1] = { title = 'Ton parrain : ' .. d.mentor, icon = 'hands-holding-child', readOnly = true,
            description = ('Jours de jeu : %d · reste %d jours en ville pour la prime de bienvenue'):format(d.days, d.goal) }
    elseif d.role == 'newbie' then
        options[#options + 1] = { title = 'Choisis un parrain', icon = 'hands-holding-child', readOnly = true,
            description = 'Un joueur expérimenté pour te guider. Reste 7 jours : prime pour vous deux.' }
        for _, m in ipairs(d.mentors) do
            options[#options + 1] = { title = m.name, description = ('Niveau %d'):format(m.level), icon = 'user-check',
                onSelect = function() notify(call('ask', m.id)) end }
        end
        if #d.mentors == 0 then options[#options + 1] = { title = 'Aucun parrain disponible pour l\'instant', icon = 'clock', readOnly = true } end
    else
        options[#options + 1] = { title = ('Parrainage : niveau %d requis pour parrainer'):format(d.need), icon = 'lock', readOnly = true }
    end
    lib.registerContext({ id = 'gs_mentor', title = 'Parrainage', options = options })
    lib.showContext('gs_mentor')
end
RegisterCommand('mentor', menu, false)

RegisterNetEvent('gs_onboarding:client:mentorRequest', function(name)
    local r = lib.alertDialog({ header = 'Demande de parrainage', content = ('%s, nouveau en ville, aimerait que tu sois son parrain.'):format(name),
        centered = true, cancel = true, labels = { confirm = 'Accepter', cancel = 'Refuser' } })
    notify(call('answer', r == 'confirm'))
end)
