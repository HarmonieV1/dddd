fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_gangs'
description 'Gangs et territoires : influence, présence policière, racket, tags, garage du gang, receleur (vente en gros)'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'gs_security', 'gs_bridge', 'gs_jobs', 'gs_markers' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/main.lua', 'server/extras.lua', 'server/wars.lua', 'server/racket.lua' }
client_scripts { 'client/main.lua', 'client/extras.lua', 'client/racket.lua' }
