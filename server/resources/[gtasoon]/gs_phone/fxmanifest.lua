fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_phone'
description 'Téléphone GTA SOON : messages, contacts, appels (pma-voice), banque, factures, emploi, 911, Vibe (réseau social)'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'gs_security', 'gs_bridge', 'gs_jobs' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/main.lua' }
client_scripts { 'client/main.lua' }

ui_page 'web/dist/index.html'
files { 'web/dist/index.html', 'web/dist/assets/*' }
