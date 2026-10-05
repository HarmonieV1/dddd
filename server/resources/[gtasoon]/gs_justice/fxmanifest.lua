fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_justice'
description 'Justice : procès (juge, prévenu, avocat), verdicts appliqués et inscrits au casier, accès avocat au casier ; V10.1 : pièces au dossier (photos, scellés), mandats de perquisition.'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'gs_security', 'gs_bridge', 'gs_jobs', 'gs_police', 'gs_markers' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', '@gs_bridge/shared/points.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/main.lua', 'server/warrant.lua', 'server/pieces.lua', 'server/jury.lua' }
client_scripts { 'client/main.lua', 'client/warrant.lua', 'client/jury.lua' }
