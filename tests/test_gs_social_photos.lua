-- Tests photos Vibe : validation d'URL (hébergeur autorisé seulement), décodage base64, data URI (type, taille), stories
-- (profil, cooldown, 24 h), heure dorée (une fois par jour), post avec image.
dofile('tests/mock.lua')
local R = 'server/resources/[gtasoon]/'
local convars = { gs_photo_allowed_host = 'https://r2.fivemanage.com/', gs_photo_upload_url = 'https://api.fivemanage.com/api/image' }
function GetConvar(k, d) return convars[k] or d end
local hour, xp = 19, 0
provide('gs_weather', { GetGameTime = function() return hour, 0, 0 end })
provide('gs_quests', { AddXP = function(_, n) xp = xp + n return 1 end, GetTitle = function() return nil end })
provide('gs_jobs', { IsOnDutyAs = function() return false end })
loadResource('gs_security', { R .. 'gs_security/server/main.lua' })
loadResource('gs_social', { R .. 'gs_social/shared/config.lua' })
local stories, golden, profiles = {}, {}, { CID1 = 'lucia' }
Store = { init = function() end, initV2 = function() end, initPhotos = function() end, loadFeed = function() return {}, {} end,
    getHandle = function(cid) return profiles[cid] end, loadVerified = function() return {} end, loadFollowerCounts = function() return {} end,
    insertPost = function(_, _, _, image) stories.lastImage = image return 42 end,
    addStory = function(cid, h, url) stories[#stories + 1] = { handle = h, url = url } return #stories end,
    stories = function() return stories end, purgeStories = function() end,
    goldenDay = function(cid) return golden[cid] end, setGoldenDay = function(cid, d) golden[cid] = d end }
loadResource('gs_social', { R .. 'gs_social/server/main.lua', R .. 'gs_social/server/photos.lua', R .. 'gs_social/server/upload.lua' })
Neon.init()
local valid = getExport('gs_security', 'ValidImageUrl')

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.stderr:write('ÉCHEC : ' .. name .. '\n') end
end
local function step() advance(130000) end

-- URL
check('URL de l\'hébergeur : acceptée', valid('https://r2.fivemanage.com/abc/photo.jpg') ~= nil)
check('autre site : refusé', valid('https://evil.example/track.png') == nil)
check('javascript / http : refusés', valid('javascript:alert(1)') == nil and valid('http://r2.fivemanage.com/a.jpg') == nil)
check('caractères suspects : refusés', valid('https://r2.fivemanage.com/a.jpg" onerror="x') == nil)
convars.gs_photo_allowed_host = nil
check('hébergeur non configuré : tout refusé', valid('https://r2.fivemanage.com/abc/photo.jpg') == nil)
convars.gs_photo_allowed_host = 'https://r2.fivemanage.com/'

-- Base64 / data URI
check('base64 décodé', Upload.decode('SGVsbG8=') == 'Hello' and Upload.decode('SGk=') == 'Hi')
check('base64 invalide', Upload.decode('SGV$bG8=') == nil and Upload.decode('abc') == nil)
local bin, mime = Upload.parse('data:image/jpeg;base64,SGVsbG8=')
check('data URI jpeg', bin == 'Hello' and mime == 'image/jpeg')
check('pas une image : refusé', Upload.parse('data:text/html;base64,SGVsbG8=') == nil)
check('trop lourde : refusée', Upload.parse('data:image/jpeg;base64,' .. ('A'):rep(Config.Photos.maxBytes * 2)) == nil)
local body, ctype = Upload.multipart('file', 'BIN', 'image/jpeg')
check('multipart : champ, fichier, contenu', body:find('name="file"; filename="photo.jpg"', 1, true) and body:find('BIN', 1, true) and ctype:find('boundary='))

-- Stories et heure dorée
join(1, 'CID1', 'Lucia', vec3(0.0, 0.0, 0.0)) join(2, 'CID2', 'Sans profil', vec3(0.0, 0.0, 0.0))
local ok, msg = cb('gs_social:story', 2, 'https://r2.fivemanage.com/a.jpg'); step()
check('story sans profil : refusée', not ok)
ok = cb('gs_social:story', 1, 'https://evil.example/a.jpg'); step()
check('story d\'un autre site : refusée', not ok and #stories == 0)
ok, msg = cb('gs_social:story', 1, 'https://r2.fivemanage.com/a.jpg'); step()
check('story publiée + heure dorée', ok and #stories == 1 and xp == Config.Photos.goldenXp and msg:find('dorée'))
ok, msg = cb('gs_social:story', 1, 'https://r2.fivemanage.com/b.jpg'); step()
check('heure dorée une fois par jour', ok and xp == Config.Photos.goldenXp)
hour = 12
check('en dehors de l\'heure dorée : pas de bonus', Photos.golden(1, 'CID9') == nil)

-- Post avec image
ok = cb('gs_social:post', 1, '', 'https://r2.fivemanage.com/c.jpg'); advance(31000)
check('post photo sans texte : accepté', ok and stories.lastImage == 'https://r2.fivemanage.com/c.jpg' and Neon.feed[1].content == '📸')
ok = cb('gs_social:post', 1, 'Regardez !', 'https://evil.example/x.png'); advance(31000)
check('image d\'un autre site : ignorée (texte gardé)', ok and stories.lastImage == nil)

io.write(('\n%d réussis, %d échoués\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
