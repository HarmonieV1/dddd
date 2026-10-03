fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_jobs'
description 'Multi-job : contrats, service, direction, caisse société, paie, garages, coffres, factures, missions, actions véhicule'
version '0.1.0'

dependencies { 'oxmysql', 'ox_lib', 'ox_target', 'gs_security', 'gs_bridge', 'gs_markers' }

shared_scripts {
    '@ox_lib/init.lua',
    'shared/locale.lua',
    'shared/config.lua',
    'shared/locations.lua',
    'shared/jobs.lua',
    '@gs_bridge/shared/points.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/core.lua',
    'server/db.lua',
    'server/society.lua',
    'server/members.lua',
    'server/payroll.lua',
    'server/garage.lua',
    'server/stash.lua',
    'server/points.lua',
    'server/boss.lua',
    'server/billing.lua',
    'server/vehicle_actions.lua',
    'server/missions.lua',
    'server/admin.lua',
    'server/orders.lua',
    'server/init.lua',
}

client_scripts {
    'client/core.lua',
    'client/zones.lua',
    'client/menus.lua',
    'client/missions.lua',
    'client/vehicle_actions.lua',
    'client/orders.lua',
}
