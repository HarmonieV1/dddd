-- [CONFIG] gs_furniture · V12.42 Mobilier utilisable (Alt dessus) : s'asseoir, s'allonger, rouler en fauteuil roulant. Vaut pour TOUS les objets
-- de ces modèles : ceux posés par le staff (F11 → Mapping) comme ceux de la ville. Décalages par rapport à l'objet :
-- y = avant / arrière, z = hauteur, h = rotation du personnage (180 = dos au dossier). seats = plusieurs places (x).
-- Pendant la pose : PgUp / PgDn = hauteur, flèches haut / bas = avant / arrière, gauche / droite = rotation.
-- V12.58 : /meubleregle (staff, assis dessus) enregistre le réglage du modèle POUR TOUT LE MONDE (sans toucher à ce fichier) ;
-- /meubleregle annuler revient aux valeurs ci-dessous.
local BENCH3 = { -0.55, 0.0, 0.55 }
Config = {}
Config.Furniture = {
    keyUp = 73,           -- X : se lever
    rollSpeed = 1.1,      -- fauteuil roulant : m/s (Maj : × 1.8)
    turnSpeed = 90.0,     -- degrés / s
    anims = {
        sit = { dict = 'anim@heists@prison_heistunfinished_biztarget_idle', clip = 'target_idle' },
        lie = { dict = 'anim@gangops@morgue@table@', clip = 'body_search' },
        wheel = { dict = 'anim@heists@prison_heistunfinished_biztarget_idle', clip = 'target_idle' },
    },
    models = {
        -- Bancs
        prop_bench_01a = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0, seats = BENCH3 },
        prop_bench_01b = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0, seats = BENCH3 },
        prop_bench_01c = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0, seats = BENCH3 },
        prop_bench_02 = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0, seats = BENCH3 },
        prop_bench_03 = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0, seats = BENCH3 },
        prop_bench_04 = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0, seats = BENCH3 },
        prop_bench_05 = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0, seats = BENCH3 },
        prop_bench_06 = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0, seats = BENCH3 },
        prop_bench_07 = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0, seats = BENCH3 },
        prop_bench_08 = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0, seats = BENCH3 },
        prop_bench_09 = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0, seats = BENCH3 },
        prop_bench_10 = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0, seats = BENCH3 },
        prop_bench_11 = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0, seats = BENCH3 },
        prop_wait_bench_01 = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0, seats = BENCH3 },
        -- Chaises, fauteuils, canapés
        prop_chair_01a = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0 },
        prop_chair_01b = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0 },
        prop_chair_02 = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0 },
        prop_chair_03 = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0 },
        prop_chair_04a = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0 },
        prop_chair_05 = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0 },
        prop_chair_06 = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0 },
        prop_chair_07 = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0 },
        prop_chair_08 = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0 },
        prop_chair_09 = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0 },
        prop_chair_10 = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0 },
        prop_off_chair_01 = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0 },
        prop_off_chair_03 = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0 },
        prop_off_chair_04 = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0 },
        prop_off_chair_05 = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0 },
        prop_skid_chair_01 = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0 },
        prop_skid_chair_02 = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0 },
        prop_skid_chair_03 = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0 },
        prop_camping_chair_01 = { kind = 'sit', z = 0.45, y = 0.0, h = 180.0 },
        prop_old_deck_chair = { kind = 'sit', z = 0.45, y = 0.0, h = 180.0 },
        prop_sofa_01 = { kind = 'sit', z = 0.5, y = 0.0, h = 180.0, seats = { -0.5, 0.5 } },
        -- Lits, matelas
        prop_hosp_bed_01 = { kind = 'lie', z = 1.35, y = 0.0, h = 0.0 },
        v_med_bed1 = { kind = 'lie', z = 1.35, y = 0.0, h = 0.0 },
        v_med_bed2 = { kind = 'lie', z = 1.35, y = 0.0, h = 0.0 },
        prop_rub_matress_01 = { kind = 'lie', z = 0.6, y = 0.0, h = 0.0 },
        prop_beach_lilo_01 = { kind = 'lie', z = 0.55, y = 0.0, h = 0.0 },
        prop_beach_towel_01 = { kind = 'lie', z = 0.5, y = 0.0, h = 0.0 },
        -- Fauteuil roulant : s'asseoir et rouler (Z / S, Q / D, Maj)
        prop_wheelchair_01 = { kind = 'wheel', z = 0.55, y = 0.0, h = 180.0 },
    },
}
