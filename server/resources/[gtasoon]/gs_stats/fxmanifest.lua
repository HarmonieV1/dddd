fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_stats'
description 'V9 · Récap RoadLine / biographie (ton mois à Los Santos : heures, km, gains, crimes, arrestations, combats, rencontres, photos, titre et classement) et statistiques de rétention pour le staff (nouveaux joueurs, retour J+1 / J+7, abandon à la première session, durée des sessions, pic).'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'gs_security', 'gs_bridge' }

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/bio.lua', 'server/retention.lua' }
client_scripts { 'client/main.lua' }
