fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_lsradio'
description 'V10 · Radio Los Santos : en voiture, l\'animateur raconte la ville en direct (rendez-vous, fugitifs, faits divers, tempêtes, bruits de comptoir, météo). Sous-titres natifs : aucune interface, aucune boucle.'
version '0.1.0'

dependencies { 'ox_lib', 'gs_security' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
server_scripts { 'server/main.lua' }
client_scripts { 'client/main.lua' }
