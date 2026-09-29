fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_events'
description 'Événements saisonniers (calendrier) et événements staff (/gsevent) : bonus d\'XP, tours de roue en plus, annonce à la connexion.'
version '0.1.0'

dependencies { 'ox_lib', 'gs_security', 'gs_bridge' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
server_scripts { 'server/main.lua' }
