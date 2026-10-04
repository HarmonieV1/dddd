fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_events'
description 'Événements saisonniers (calendrier), rendez-vous fixes de la semaine (/rdv, rappels en jeu et sur Discord) et événements staff (/gsevent) : bonus d\'XP, tours de roue en plus.'
version '0.1.0'

dependencies { 'ox_lib', 'gs_security', 'gs_bridge' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { 'server/main.lua' }
client_scripts { 'client/main.lua' }
