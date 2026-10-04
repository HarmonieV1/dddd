fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_discord'
description 'V9 · Discord : message de statut en direct (joueurs, services, météo) modifié en place, annonces (démarrage, redémarrages txAdmin), rôles Discord synchronisés avec le métier, bot RoadLine intégré au serveur (présence, /statut, /rejoindre, /rdv, /site) dès que le jeton est rempli.'
version '0.1.0'

dependencies { 'gs_bridge' }

shared_scripts { 'shared/config.lua' }
server_scripts { 'server/main.lua', 'server/bot.js' }
