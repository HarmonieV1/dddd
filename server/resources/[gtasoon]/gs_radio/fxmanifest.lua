fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_radio'
description 'Radio sans prise de tête : canaux métier / gang réservés (vérifiés par pma-voice côté serveur), dernière fréquence retenue, parler en maintenant Verr. Maj sans rouvrir la radio.'
version '0.1.0'

dependencies { 'ox_lib', 'pma-voice', 'gs_security', 'gs_bridge' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
server_scripts { 'server/main.lua' }
client_scripts { 'client/main.lua' }
