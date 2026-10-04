fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_social'
description 'Vibe : réseau social in-game (app du téléphone) (fil, profils, likes, mentions, modération, miroir Discord)'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'gs_security', 'gs_bridge' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/main.lua', 'server/vibe2.lua', 'server/trends.lua', 'server/photos.lua', 'server/upload.lua', 'server/journal.lua', 'server/live.lua' }
client_scripts { 'client/main.lua', 'client/journal.lua', 'client/live.lua' }

ui_page 'web/dist/index.html'
files { 'web/dist/index.html', 'web/dist/assets/*' }
