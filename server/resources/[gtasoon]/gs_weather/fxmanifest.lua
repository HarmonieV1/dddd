fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_weather'
description 'Météo et heure synchronisées, golden hour allongée, événements météo annoncés'
version '0.1.0'

dependencies { 'ox_lib', 'gs_security' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', 'shared/clock.lua' }
server_scripts { 'server/main.lua' }
client_scripts { 'client/main.lua' }
