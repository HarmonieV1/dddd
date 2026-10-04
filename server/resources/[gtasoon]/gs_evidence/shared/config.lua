-- [CONFIG] V8 · Enquêtes avec preuves. Toutes les traces sont créées et gardées par le SERVEUR (le client ne peut ni en
-- fabriquer au nom d'un autre, ni en effacer sans kit). La police les voit à la lampe torche, les met sous scellé et
-- les fait analyser au labo du commissariat. Un résultat ne donne un NOM que si la personne est fichée (empreintes / ADN
-- relevés lors d'une arrestation) ; sinon un profil inconnu (P-XXXX) qui permet de relier plusieurs scènes entre elles.
Config = {}
Config.PoliceJob = 'police'

Config.Kinds = {
    casing = { label = 'Douilles', icon = 'bullseye', decay = 45 },
    blood  = { label = 'Traces de sang', icon = 'droplet', decay = 30, rain = 3 },        -- rain : vieillit X fois plus vite sous la pluie
    print  = { label = 'Empreintes digitales', icon = 'fingerprint', decay = 60 },
    tyre   = { label = 'Traces de pneus', icon = 'car-side', decay = 20, rain = 3 },
    paint  = { label = 'Éclats de peinture', icon = 'spray-can', decay = 40 },
}
Config.RainWeathers = { RAIN = true, THUNDER = true, CLEARING = true }
Config.MergeRadius = 6.0          -- même type, même auteur, à moins de X m et 2 min : une seule trace (compteur)
Config.MaxTraces = 400

-- Crimes (gs_wanted) qui laissent des empreintes sans gants
Config.PrintCrimes = { robbery = true, store_robbery = true, jewelry = true, bank = true, teller_robbery = true,
    carjack = true, duo_contract = true, mugging = true, contract = true }
Config.Blood = { health = 180 }   -- sang au sol quand la santé passe sous ce seuil (200 = pleine forme)
Config.Paint = { body = 950 }     -- éclats de peinture si la carrosserie est abîmée (1000 = neuve)

Config.Search = { range = 25.0, collect = 3.0 }   -- lampe torche : traces visibles à X m ; ramassage à 3 m
Config.Items = { bag = 'evidence_bag', gloves = 'gs_gloves', bleach = 'gs_bleach' }
Config.Clean = { radius = 6.0, duration = 12000 }

-- Labo du commissariat (Mission Row) : analyse en quelques minutes
Config.Lab = { coords = vec3(483.6, -988.7, 30.69), radius = 4.0, seconds = 180, history = 30 }

-- V9 · Appareil photo argentique : chaque photo devient un objet (lieu, date, personnes et plaques visibles ;
-- image réelle si l'hébergement des photos est configuré). Donner, garder, accrocher au mur, verser au labo, faire chanter.
Config.Camera = { item = 'gs_camera', photo = 'gs_photo', range = 30.0, front = 0.3, maxPlates = 3, maxWall = 200, perPlayerWall = 12 }
