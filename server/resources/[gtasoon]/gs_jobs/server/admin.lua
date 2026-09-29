-- API staff (gs_admin) : mêmes règles que /gsjob, audit fait par l'appelant.
exports('AdminAddContract', function(cid, job, grade, name) return GSJ.addMembership(cid, job, grade or 0, name) end)
exports('AdminRemoveContract', function(cid, job) return GSJ.removeMembership(cid, job) end)
exports('AdminSetGrade', function(cid, job, grade) return GSJ.setMembershipGrade(cid, job, grade) end)

--- Staff (tests) : contrat créé ou regradé si besoin, puis job actif (hors service). Retourne ok, err.
exports('AdminSetActive', function(src, job, grade)
    local m = Members[src]
    if not m then return false, 'not_loaded' end
    grade = tonumber(grade) or 0
    if not Jobs[job] or not Jobs[job].grades[grade] then return false, 'invalid' end
    local ok, err = true, nil
    if m.jobs[job] == nil then ok, err = GSJ.addMembership(m.cid, job, grade, Bridge:GetName(src))
    elseif m.jobs[job] ~= grade then ok, err = GSJ.setMembershipGrade(m.cid, job, grade) end
    if not ok then return false, err end
    GSJ.endService(src)
    Bridge:SetJob(src, job, grade)
    Bridge:SetDuty(src, false)
    return true
end)

--- { { name, label, grades = { { grade, label } } } } triés (menus staff).
exports('ListJobs', function()
    local list = {}
    for name, j in pairs(Jobs) do
        local grades = {}
        for g, d in pairs(j.grades) do grades[#grades + 1] = { grade = g, label = d.label } end
        table.sort(grades, function(a, b) return a.grade < b.grade end)
        list[#list + 1] = { name = name, label = j.label, grades = grades }
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end)

-- /gsjob <add|remove|grade|list> <id> [job] [grade] : gestion staff. ACE : group.admin (auto par ox_lib).
-- Remplace le /setjob du framework : passer par ici pour garder les contrats cohérents.
local function reply(src, msg, ntype)
    if src == 0 then print('[gs_jobs] ' .. msg) else GSJ.notify(src, msg, ntype) end
end

lib.addCommand('gsjob', {
    help = 'Gestion des contrats (staff)',
    params = {
        { name = 'action', type = 'string', help = 'add | remove | grade | list' },
        { name = 'target', type = 'playerId', help = 'ID serveur du joueur' },
        { name = 'job', type = 'string', help = 'Nom du job', optional = true },
        { name = 'grade', type = 'number', help = 'Grade', optional = true },
    },
    restricted = 'group.admin',
}, function(src, args)
    local target, job, grade = args.target, args.job, args.grade or 0
    local m = Members[target]
    if not m then return reply(src, L('player_not_found'), 'error') end

    if args.action == 'list' then
        local parts = {}
        for name, g in pairs(m.jobs) do parts[#parts + 1] = ('%s (%s)'):format(name, GSJ.gradeLabel(name, g)) end
        return reply(src, ('%s : %s'):format(GetPlayerName(target), #parts > 0 and table.concat(parts, ', ') or L('unemployed')))
    end

    if not job or not Jobs[job] then return reply(src, L('invalid'), 'error') end
    local ok, err
    if args.action == 'add' then
        ok, err = GSJ.addMembership(m.cid, job, grade, Bridge:GetName(target))
    elseif args.action == 'remove' then
        ok, err = GSJ.removeMembership(m.cid, job)
    elseif args.action == 'grade' then
        ok, err = GSJ.setMembershipGrade(m.cid, job, grade)
    else
        return reply(src, L('invalid'), 'error')
    end
    if not ok then return reply(src, L(err), 'error') end

    local who = src == 0 and 'console' or ('%s (%s)'):format(GetPlayerName(src), GSJ.cid(src) or '?')
    Security:LogStaff(('/gsjob %s par %s : %s (%s) %s grade %s'):format(args.action, who, GetPlayerName(target), m.cid, job, grade))
    DB.audit('admin_' .. args.action, job, src == 0 and 'console' or GSJ.cid(src), m.cid, grade, nil)
    reply(src, L('action_done'), 'success')
end)
