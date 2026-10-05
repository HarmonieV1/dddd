fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_rumors'
description 'V8 · La ville parle : rumeurs tirées des vrais événements du serveur (barmans, pompistes…) et indic\' qui vend les activités des gangs, au risque de balancer'
version '0.1.0'

dependencies { 'ox_lib', 'gs_security', 'gs_bridge' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { 'server/main.lua', 'server/seeds.lua' }
client_scripts { 'client/main.lua' }
