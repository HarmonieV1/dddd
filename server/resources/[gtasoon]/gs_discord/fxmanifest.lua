fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_discord'
description 'V9 · Discord : message de statut en direct (joueurs, services, météo) modifié en place, annonces (démarrage, redémarrages txAdmin), rôles Discord synchronisés avec le métier (optionnel, jeton de bot).'
version '0.1.0'

dependencies { 'gs_bridge' }

shared_scripts { 'shared/config.lua' }
server_scripts { 'server/main.lua' }
