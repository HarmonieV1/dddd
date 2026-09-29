-- GTA SOON : copie de ox_inventory/data/shops.lua SANS General / Liquor / YouTool / PoliceArmoury / Medicine
-- (commerces = gs_economy ; équipement de service = armureries gs_jobs, gratuites et limitées).
-- Ammu-Nation : un armurier PNJ derrière chaque comptoir (on lui parle avec ox_target).
-- Posé automatiquement par INSTALLER.bat / METTRE-A-JOUR.bat.
return {



	Ammunation = {
		name = 'Ammunation',
		blip = {
			id = 110, colour = 69, scale = 0.8
		}, inventory = {
			{ name = 'ammo-9', price = 5, },
			{ name = 'WEAPON_KNIFE', price = 200 },
			{ name = 'WEAPON_BAT', price = 100 },
			{ name = 'WEAPON_PISTOL', price = 1000, metadata = { registered = true }, license = 'weapon' }
		}, locations = {
			vec3(-662.180, -934.961, 21.829),
			vec3(810.25, -2157.60, 29.62),
			vec3(1693.44, 3760.16, 34.71),
			vec3(-330.24, 6083.88, 31.45),
			vec3(252.63, -50.00, 69.94),
			vec3(22.56, -1109.89, 29.80),
			vec3(2567.69, 294.38, 108.73),
			vec3(-1117.58, 2698.61, 18.55),
			vec3(842.44, -1033.42, 28.19)
		}, targets = { -- vendeur PNJ derrière chaque comptoir (ox_inventory : ped + scenario ; z = sol)
			{ ped = `s_m_y_ammucity_01`, scenario = 'WORLD_HUMAN_COP_IDLES', loc = vec3(-661.96, -933.53, 20.83), heading = 177.05, distance = 2.5 },
			{ ped = `s_m_y_ammucity_01`, scenario = 'WORLD_HUMAN_COP_IDLES', loc = vec3(809.68, -2159.13, 28.62), heading = 1.43, distance = 2.5 },
			{ ped = `s_m_y_ammucity_01`, scenario = 'WORLD_HUMAN_COP_IDLES', loc = vec3(1692.67, 3761.38, 33.71), heading = 227.65, distance = 2.5 },
			{ ped = `s_m_y_ammucity_01`, scenario = 'WORLD_HUMAN_COP_IDLES', loc = vec3(-331.23, 6085.37, 30.45), heading = 228.02, distance = 2.5 },
			{ ped = `s_m_y_ammucity_01`, scenario = 'WORLD_HUMAN_COP_IDLES', loc = vec3(253.63, -51.02, 68.94), heading = 72.91, distance = 2.5 },
			{ ped = `s_m_y_ammucity_01`, scenario = 'WORLD_HUMAN_COP_IDLES', loc = vec3(23.00, -1105.67, 28.80), heading = 162.91, distance = 2.5 },
			{ ped = `s_m_y_ammucity_01`, scenario = 'WORLD_HUMAN_COP_IDLES', loc = vec3(2567.48, 292.59, 107.73), heading = 349.68, distance = 2.5 },
			{ ped = `s_m_y_ammucity_01`, scenario = 'WORLD_HUMAN_COP_IDLES', loc = vec3(-1118.59, 2700.05, 17.55), heading = 221.89, distance = 2.5 },
			{ ped = `s_m_y_ammucity_01`, scenario = 'WORLD_HUMAN_COP_IDLES', loc = vec3(841.92, -1035.32, 27.19), heading = 1.56, distance = 2.5 }
		}
	},



	BlackMarketArms = {
		name = 'Black Market (Arms)',
		inventory = {
			{ name = 'WEAPON_DAGGER', price = 5000, metadata = { registered = false	}, currency = 'black_money' },
			{ name = 'WEAPON_CERAMICPISTOL', price = 50000, metadata = { registered = false }, currency = 'black_money' },
			{ name = 'at_suppressor_light', price = 50000, currency = 'black_money' },
			{ name = 'ammo-rifle', price = 1000, currency = 'black_money' },
			{ name = 'ammo-rifle2', price = 1000, currency = 'black_money' }
		}, locations = {
			vec3(309.09, -913.75, 56.46)
		}, targets = {

		}
	},

	VendingMachineDrinks = {
		name = 'Vending Machine',
		inventory = {
			{ name = 'water', price = 10 },
			{ name = 'cola', price = 10 },
		},
		model = {
			`prop_vend_soda_02`, `prop_vend_fridge01`, `prop_vend_water_01`, `prop_vend_soda_01`
		}
	}
}
