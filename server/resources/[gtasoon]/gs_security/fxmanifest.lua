fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_security'
description 'Sécurité serveur : rate-limit + anti-flood, distances, nettoyage de texte, logs Discord, blocage des events natifs de triche'
version '0.2.0'

server_scripts { 'server/main.lua', 'server/anticheat.lua' }
