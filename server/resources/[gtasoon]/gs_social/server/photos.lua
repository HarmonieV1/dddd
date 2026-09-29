-- gs_social (serveur) : photos et stories. L'image est envoyée par le client à l'hébergeur configuré (screenshot-basic) ;
-- le serveur n'accepte que les adresses de cet hébergeur (gs_security:ValidImageUrl). Stories visibles 24 h.
-- Heure dorée : une photo prise au coucher du soleil (heure du jeu) rapporte de l'XP, une fois par jour.
local Security = exports.gs_security
local Bridge   = exports.gs_bridge

Photos = {}

local function guard(src, key, max, window)
    return Security:RateLimit(src, 'gs_social:' .. key, max, window) and Bridge:IsLoaded(src)
end

--- Bonus heure dorée (une fois par jour réel) → XP gagnée ou nil
function Photos.golden(src, cid)
    if GetResourceState('gs_weather') ~= 'started' or GetResourceState('gs_quests') ~= 'started' then return nil end
    local hour = exports.gs_weather:GetGameTime()
    local g = Config.Photos.goldenHours
    if hour < g[1] or hour >= g[2] then return nil end
    local day = os.date('%Y-%m-%d')
    if Store.goldenDay(cid) == day then return nil end
    Store.setGoldenDay(cid, day)
    exports.gs_quests:AddXP(src, Config.Photos.goldenXp, 'photo à l\'heure dorée')
    return Config.Photos.goldenXp
end

lib.callback.register('gs_social:story', function(src, url)
    if not guard(src, 'story', 1, Config.Photos.storyCooldown * 1000) then return false, 'Une story à la fois, patiente un peu.' end
    local handle, cid = Neon.handleOf(src), Bridge:GetIdentifier(src)
    if not handle or not cid then return false, 'Crée d\'abord ton profil Vibe.' end
    url = Security:ValidImageUrl(url)
    if not url then return false, 'Photo refusée (hébergeur non autorisé ou non configuré).' end
    local id = Store.addStory(cid, handle, url)
    TriggerClientEvent('gs_social:client:story', -1, { id = id, handle = handle, url = url, time = os.time() })
    local xp = Photos.golden(src, cid)
    return true, xp and ('Story publiée · heure dorée : +%d XP !'):format(xp) or 'Story publiée (visible 24 h).'
end)

lib.callback.register('gs_social:stories', function(src)
    if not guard(src, 'stories', 6, 10000) then return {} end
    return Store.stories(Config.Photos.storyHours)
end)

--- Heure dorée aussi pour un post avec photo (appelé par gs_social:post)
function Photos.onImagePost(src, cid) return Photos.golden(src, cid) end

exports('PhotosEnabled', function() return GetConvar('gs_photo_upload_url', '') ~= '' and GetConvar('gs_photo_allowed_host', '') ~= '' end)

CreateThread(function()
    Store.initPhotos()
    while true do
        Store.purgeStories(Config.Photos.storyHours)
        Wait(3600000)
    end
end)
