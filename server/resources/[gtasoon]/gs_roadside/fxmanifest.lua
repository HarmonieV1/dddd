fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_roadside'
description 'V8 · Rencontres de la route : scènes rares et facultatives sur les routes hors de la ville (auto-stoppeur, panne, accident, animal, portefeuille, vendeur, shérif), parfois dangereuses ; PNJ qui se souviennent'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'gs_security', 'gs_bridge' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/main.lua' }
client_scripts { 'client/main.lua' }
