fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_smuggling'
description 'V8 · Contrebande maritime : cargaisons repêchées en mer la nuit, livrées sur une plage ; radar côtier, garde-côtes'
version '0.1.0'

dependencies { 'ox_lib', 'gs_security', 'gs_bridge' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { 'server/main.lua' }
client_scripts { 'client/main.lua' }
