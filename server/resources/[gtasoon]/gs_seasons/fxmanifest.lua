fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_seasons'
description 'Saisons de 8 semaines : thème, pass (piste gratuite + piste premium cosmétique via Tebex), points gagnés avec l\'XP, classement, palmarès.'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'gs_security', 'gs_bridge' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/main.lua' }
client_scripts { 'client/main.lua' }
