fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_reputation'
description 'Réputation de la ville (rue, légale, média) : gagnée en jouant, elle change les prix des commerçants, le prix de la drogue et l\'accueil des vendeurs.'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'gs_security', 'gs_bridge' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/main.lua' }
client_scripts { 'client/main.lua' }
