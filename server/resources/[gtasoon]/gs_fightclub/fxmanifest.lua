fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_fightclub'
description 'V9 · Combats clandestins : un ring caché dont l\'adresse change chaque nuit (on l\'apprend par les rumeurs), combats à mains nues avec mise, paris des spectateurs. Tout est arbitré par le serveur.'
version '0.1.0'

dependencies { 'ox_lib', 'gs_security', 'gs_bridge' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
server_scripts { 'server/main.lua' }
client_scripts { 'client/main.lua' }
