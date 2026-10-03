fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_casino'
description 'Casino Diamond : roue de la fortune (1 tour gratuit / jour) et tickets à gratter (supérettes, défis du jour). Tirages côté serveur.'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'gs_security', 'gs_bridge', 'gs_markers' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/main.lua', 'server/lotto.lua' }
client_scripts { 'client/main.lua' }
