-- gs_social (serveur) : envoi des photos à l'hébergeur. Le client capture l'écran (screenshot-basic) et envoie l'image ici ;
-- c'est le SERVEUR qui l'envoie à l'hébergeur : la clé d'API (convar gs_photo_auth) ne sort jamais vers les joueurs.
local Security = exports.gs_security

Upload = {}

local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local DEC = {}
for i = 1, #B64 do DEC[B64:byte(i)] = i - 1 end

--- Décodage base64 (données d'image) → binaire, ou nil si invalide.
function Upload.decode(s)
    s = s:gsub('%s', '')
    if #s % 4 ~= 0 or s:find('[^%w%+/=]') then return nil end
    local out, n = {}, 0
    for i = 1, #s, 4 do
        local a, b, c, d = s:byte(i, i + 3)
        local va, vb = DEC[a], DEC[b]
        local vc, vd = c ~= 61 and DEC[c] or 0, d ~= 61 and DEC[d] or 0
        if not va or not vb or (c ~= 61 and not DEC[c]) or (d ~= 61 and not DEC[d]) then return nil end
        local v = va * 262144 + vb * 4096 + vc * 64 + vd
        n = n + 1 out[n] = string.char(v // 65536 % 256)
        if c ~= 61 then n = n + 1 out[n] = string.char(v // 256 % 256) end
        if d ~= 61 then n = n + 1 out[n] = string.char(v % 256) end
    end
    return table.concat(out)
end

--- data URI jpg / png / webp → binaire, type MIME ; nil si ce n'est pas une image acceptée ou trop lourde.
function Upload.parse(dataUri)
    if type(dataUri) ~= 'string' or #dataUri > Config.Photos.maxBytes * 4 // 3 + 64 then return nil end
    local mime, b64 = dataUri:match('^data:(image/[%a]+);base64,(.+)$')
    if mime ~= 'image/jpeg' and mime ~= 'image/png' and mime ~= 'image/webp' then return nil end
    local bin = Upload.decode(b64)
    if not bin or #bin == 0 or #bin > Config.Photos.maxBytes then return nil end
    return bin, mime
end

function Upload.multipart(field, bin, mime)
    local boundary = ('----RoadtripPhoto%d'):format(math.random(100000000, 999999999))
    local ext = mime:match('/(%a+)$')
    local body = table.concat({
        '--', boundary, '\r\n',
        ('Content-Disposition: form-data; name="%s"; filename="photo.%s"\r\n'):format(field, ext == 'jpeg' and 'jpg' or ext),
        'Content-Type: ', mime, '\r\n\r\n', bin, '\r\n--', boundary, '--\r\n',
    })
    return body, 'multipart/form-data; boundary=' .. boundary
end

RegisterNetEvent('gs_social:server:upload', function(token, dataUri)
    local src = source
    if not Security:RateLimit(src, 'gs_social:upload', 1, Config.Photos.uploadCooldown * 1000) then
        return TriggerClientEvent('gs_social:client:uploaded', src, token, nil, 'Une photo toutes les ' .. Config.Photos.uploadCooldown .. ' s.')
    end
    local url = GetConvar('gs_photo_upload_url', '')
    if url == '' then return TriggerClientEvent('gs_social:client:uploaded', src, token, nil, 'Appareil photo non configuré sur ce serveur.') end
    local bin, mime = Upload.parse(dataUri)
    if not bin then return TriggerClientEvent('gs_social:client:uploaded', src, token, nil, 'Image invalide ou trop lourde.') end
    local body, ctype = Upload.multipart(GetConvar('gs_photo_field', 'file'), bin, mime)
    local headers = { ['Content-Type'] = ctype }
    local auth = GetConvar('gs_photo_auth', '')
    if auth ~= '' then headers['Authorization'] = auth end
    PerformHttpRequest(url, function(status, response)
        local link
        if status >= 200 and status < 300 and response then
            local ok, data = pcall(json.decode, response)
            local field = GetConvar('gs_photo_url_field', 'url')
            if ok and type(data) == 'table' then link = data[field] or (type(data.data) == 'table' and data.data[field]) end
        end
        link = link and Security:ValidImageUrl(link)
        TriggerClientEvent('gs_social:client:uploaded', src, token, link, link and nil or 'L\'hébergeur a refusé la photo.')
    end, 'POST', body, headers)
end)
