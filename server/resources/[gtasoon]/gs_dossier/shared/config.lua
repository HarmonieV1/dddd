-- [CONFIG] gs_dossier · qui voit quoi. Chaque rôle = métier(s) en service + rubriques visibles.
Config = {}
Config.Command = 'dossier'
Config.Roles = {
    police = { jobs = { 'police', 'sheriff' }, label = 'Fiche police',
        show = { identity = true, records = true, warrants = true, cases = true, jobs = true, gang = true, vehicles = true, reputation = true, press = true } },
    judge = { jobs = { 'judge' }, label = 'Fiche du tribunal',
        show = { identity = true, records = true, warrants = true, cases = true, jobs = true, press = true } },
    press = { jobs = { 'weazel' }, label = 'Fiche de la rédaction',
        -- la presse ne voit que ce qui est public : verdicts rendus, métiers, notoriété, articles
        show = { identity = true, publicCases = true, jobs = true, fame = true, press = true } },
}
Config.Max = { search = 8, records = 10, cases = 8, vehicles = 8, press = 6 }
