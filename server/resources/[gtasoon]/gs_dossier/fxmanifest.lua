fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_dossier'
description 'V10.2 · Le dossier du citoyen : une seule fiche (identité, casier, mandats, affaires, métiers, véhicules, réputation, articles de presse) que la police, les juges et les journalistes consultent chacun à leur façon. Lecture seule.'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'gs_bridge', 'gs_security' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }
client_scripts { 'client/main.lua' }
