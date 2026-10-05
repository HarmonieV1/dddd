-- [CONFIG] Lieux publics. Les lieux de base ci-dessous s'ajoutent à ceux posés en jeu par le staff
-- (F11 → « Lieux publics »), sauvegardés en BDD. Coords [À VÉRIFIER] : à recaler en jeu si besoin (supprimer + reposer).
Config = {}

Config.StaffLevel = 3            -- niveau staff gs_admin requis pour poser / retirer (3 = admin)
Config.MaxDistance = 6.0         -- « retirer le lieu le plus proche » : à moins de 6 m

Config.Kinds = {
    parking = { label = 'Parking public', blip = { sprite = 357, color = 3 } },
    clothing = { label = 'Boutique de vêtements', blip = { sprite = 73, color = 47 } },
}

-- Lieux de base (vides : les parkings publics de qbx_garages suffisent). Ex. :
-- { kind = 'clothing', label = 'Boutique Ponsonbys', coords = vec4(x, y, z, h) },
Config.Defaults = {}

-- V10.2 · Coiffeur : menu de barbier classique (coupe, couleur, reflets, barbe, sourcils, maquillage) au lieu de l'éditeur
-- complet. false = garder le menu d'illenium-appearance.
Config.Barber = { enabled = true, price = 150, range = 8.0 }
