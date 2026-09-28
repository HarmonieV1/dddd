fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'gs_bridge'
description 'Couche d\'adaptation Qbox / ox : seule ressource autorisée à appeler qbx_core et ox_inventory'
version '0.1.0'

dependencies { 'qbx_core', 'ox_inventory', 'ox_lib' }

server_scripts { 'server/main.lua' }

server_exports {
    'GetPlayer', 'GetIdentifier', 'GetJob', 'IsOnDuty', 'HasPermission',
    'GetMoney', 'AddMoney', 'RemoveMoney',
    'CanCarry', 'GetItemCount', 'AddItem', 'RemoveItem',
    'Notify',
}
