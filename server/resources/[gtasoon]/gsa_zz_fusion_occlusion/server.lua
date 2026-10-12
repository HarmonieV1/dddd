-- V12.24 · Écrit les fusions d'occlusion calculées par gs_admin (server/maps.js) dans le dossier stream de CETTE ressource.
-- FXServer n'autorise une ressource à écrire que dans son propre dossier (« write not allowed » quand gs_admin écrivait ici).
-- Événement LOCAL au serveur (aucun joueur ne peut le déclencher), accepté seulement de gs_admin, nom de fichier .ymap simple.
local B = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function b64dec(s)
    s = s:gsub('[^%w%+/=]', '')
    return (s:gsub('.', function(c)
        if c == '=' then return '' end
        local v, r = B:find(c, 1, true) - 1, ''
        for i = 6, 1, -1 do r = r .. (v % 2 ^ i - v % 2 ^ (i - 1) > 0 and '1' or '0') end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if #x ~= 8 then return '' end
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0) end
        return string.char(c)
    end))
end

AddEventHandler('gsa_fusion:save', function(file, b64, cb)
    local by = GetInvokingResource()
    local ok, why = false, nil
    if by and by ~= 'gs_admin' then
        why = 'refusé (demande de ' .. tostring(by) .. ')'
    elseif type(file) ~= 'string' or not file:match('^[%w_@%-]+%.ymap$') then
        why = 'nom de fichier refusé : ' .. tostring(file)
    else
        local data = b64dec(tostring(b64 or ''))
        ok = SaveResourceFile(GetCurrentResourceName(), 'stream/' .. file, data, #data) and true or false
        if not ok then why = 'SaveResourceFile refusé (dossier stream absent ? relance METTRE-A-JOUR)' end
    end
    if cb then cb(ok, why) end
end)
