-- gs_onboarding (serveur) · V8 « Mentors » : parrainage des nouveaux par des joueurs expérimentés, récompense si le
-- filleul reste (7 jours). Tout est vérifié ici : niveaux (gs_quests), places, délais, présence des deux joueurs.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge
local M = Config.Mentor

Mentors = { available = {}, requests = {} } -- available[src] = true ; requests[mentorSrc] = { newbie = src, at }

local function level(src)
    local ok, l = pcall(function() return exports.gs_quests:GetLevel(src) end)
    return ok and tonumber(l) or 1
end
local function today() return os.date('%Y-%m-%d') end

function Mentors.info(src)
    local cid = Bridge:GetIdentifier(src)
    if not cid then return nil end
    local lvl = level(src)
    if lvl >= M.minLevel then
        local list = {}
        for _, r in ipairs(Store.menteesOf(cid)) do
            local s = Bridge:GetSourceByIdentifier(r.newbie)
            list[#list + 1] = { cid = r.newbie, name = r.newbie_name, days = r.days, online = s ~= nil, rewarded = r.rewarded == 1 }
        end
        return { role = 'mentor', available = Mentors.available[src] == true, mentees = list, max = M.maxMentees }
    end
    local mine = Store.mentorOf(cid)
    if mine then return { role = 'newbie', mentor = mine.mentor_name, days = mine.days, goal = M.days } end
    if lvl > M.newbieMaxLevel then return { role = 'none', need = M.minLevel } end
    local list = {}
    for s in pairs(Mentors.available) do
        if GetPlayerName(s) then list[#list + 1] = { id = s, name = Bridge:GetName(s) or GetPlayerName(s), level = level(s) } end
    end
    return { role = 'newbie', mentors = list }
end

function Mentors.toggle(src)
    if level(src) < M.minLevel then return false, ('Il faut le niveau %d pour parrainer.'):format(M.minLevel) end
    Mentors.available[src] = not Mentors.available[src] or nil
    return true, Mentors.available[src] and 'Tu es disponible comme parrain : les nouveaux peuvent te choisir (/mentor).' or 'Tu n\'es plus disponible comme parrain.'
end

function Mentors.ask(src, mentor)
    mentor = tonumber(mentor)
    local cid = Bridge:GetIdentifier(src)
    if not cid or level(src) > M.newbieMaxLevel then return false, 'Le parrainage est réservé aux nouveaux.' end
    if Store.mentorOf(cid) then return false, 'Tu as déjà un parrain.' end
    if not mentor or mentor == src or not Mentors.available[mentor] or not GetPlayerName(mentor) then return false, 'Ce parrain n\'est plus disponible.' end
    if #Store.menteesOf(Bridge:GetIdentifier(mentor)) >= M.maxMentees then return false, 'Il a déjà trop de filleuls.' end
    Mentors.requests[mentor] = { newbie = src, at = os.time() }
    TriggerClientEvent('gs_onboarding:client:mentorRequest', mentor, Bridge:GetName(src) or GetPlayerName(src))
    return true, 'Demande envoyée. Il doit accepter.'
end

function Mentors.answer(src, accept)
    local r = Mentors.requests[src]
    Mentors.requests[src] = nil
    if not r or os.time() - r.at > M.requestSeconds or not GetPlayerName(r.newbie) then return false, 'Demande expirée.' end
    if not accept then
        Bridge:Notify(r.newbie, 'Le parrain a décliné. Essaie quelqu\'un d\'autre.', 'error')
        return true, 'Demande refusée.'
    end
    local ncid, mcid = Bridge:GetIdentifier(r.newbie), Bridge:GetIdentifier(src)
    if Store.mentorOf(ncid) then return false, 'Il a déjà un parrain.' end
    if #Store.menteesOf(mcid) >= M.maxMentees then return false, 'Tu as déjà trop de filleuls.' end
    local nname, mname = Bridge:GetName(r.newbie) or '?', Bridge:GetName(src) or '?'
    Store.pair(ncid, mcid, nname, mname, os.time(), today())
    Bridge:Notify(r.newbie, ('%s est ton parrain. Reste %d jours : vous serez récompensés tous les deux.'):format(mname, M.days), 'success')
    return true, ('Tu parraines %s.'):format(nname)
end

--- Le parrain retrouve son filleul en ville
function Mentors.locate(src, ncid)
    local row = Store.mentorOf(ncid)
    if not row or row.mentor ~= Bridge:GetIdentifier(src) then return false, 'Ce n\'est pas ton filleul.' end
    local s = Bridge:GetSourceByIdentifier(ncid)
    if not s then return false, 'Pas en ville en ce moment.' end
    local c = GetEntityCoords(GetPlayerPed(s))
    return true, { x = c.x, y = c.y, z = c.z }
end

--- Connexion : jour de jeu compté pour le filleul ; récompenses (filleul resté) ; parrain payé à sa connexion
function Mentors.onLoaded(src)
    local cid = Bridge:GetIdentifier(src)
    if not cid then return end
    local row = Store.mentorOf(cid)
    if row and row.rewarded ~= 1 then
        local days = row.days
        if row.last_day ~= today() then days = days + 1 Store.mentorDay(cid, days, today()) end
        if os.time() - row.started >= M.days * 86400 and days >= M.minDaysPlayed then
            Store.mentorRewarded(cid)
            Bridge:AddMoney(src, 'bank', M.rewardNewbie)
            Bridge:Notify(src, ('Une semaine à Los Santos ! Prime de bienvenue : %d $. Merci à %s.'):format(M.rewardNewbie, row.mentor_name), 'success')
            local m = Bridge:GetSourceByIdentifier(row.mentor)
            if m then Mentors.payMentor(m, row) end
        end
    end
    for _, r in ipairs(Store.menteesOf(cid)) do
        if r.rewarded == 1 and r.mentor_paid ~= 1 then Mentors.payMentor(src, r) end
    end
end

function Mentors.payMentor(src, row)
    Store.mentorPaid(row.newbie)
    Bridge:AddMoney(src, 'bank', M.rewardMentor)
    Bridge:Notify(src, ('Ton filleul %s est resté : prime de parrain %d $.'):format(row.newbie_name, M.rewardMentor), 'success')
    if GetResourceState('gs_reputation') == 'started' then pcall(function() exports.gs_reputation:Add(src, 'legal', 25) end) end
end

AddEventHandler('gs_bridge:server:playerLoaded', Mentors.onLoaded)
AddEventHandler('playerDropped', function() Mentors.available[source] = nil Mentors.requests[source] = nil end)

lib.callback.register('gs_onboarding:mentor', function(src, action, arg)
    if not Security:RateLimit(src, 'gs_onboarding:mentor', 6, 10000) then return false, 'Doucement.' end
    if action == 'info' then return true, Mentors.info(src)
    elseif action == 'toggle' then return Mentors.toggle(src)
    elseif action == 'ask' then return Mentors.ask(src, arg)
    elseif action == 'answer' then return Mentors.answer(src, arg == true)
    elseif action == 'locate' then return Mentors.locate(src, arg) end
    return false
end)
