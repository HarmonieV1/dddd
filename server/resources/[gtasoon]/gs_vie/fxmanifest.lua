fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_vie'
description 'Vie quotidienne (V12.57) : fouiller les poubelles, se laver, démarche blessée, passagers bavards, porter / prendre en otage, mesure de charge, salle de sport (V12.64)'
version '0.1.0'

dependencies { 'ox_lib', 'ox_target', 'gs_security', 'gs_bridge' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
client_scripts { 'client/main.lua', 'client/carry.lua', 'client/vue.lua', 'client/gym.lua' }
server_scripts { 'server/main.lua', 'server/carry.lua', 'server/perf.lua', 'server/gym.lua' } -- V12.64 : salle de sport
