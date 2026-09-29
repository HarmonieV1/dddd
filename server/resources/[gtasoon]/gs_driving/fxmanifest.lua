fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_driving'
description 'Auto-école : code (QCM tiré et corrigé par le serveur) puis examen de conduite (parcours, vitesse et dégâts relevés par le serveur). Moniteurs joueurs.'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'gs_security', 'gs_bridge', 'gs_jobs', 'gs_markers' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/main.lua' }
client_scripts { 'client/main.lua' }
