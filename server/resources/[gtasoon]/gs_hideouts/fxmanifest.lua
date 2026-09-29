fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_hideouts'
description 'Planques de départ : chambre de motel louée à la semaine (coffre perso, garde-robe), intérieur instancié par joueur. Pour un vrai logement : agent immobilier.'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'ox_inventory', 'gs_security', 'gs_bridge', 'gs_markers' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/main.lua' }
client_scripts { 'client/main.lua' }
