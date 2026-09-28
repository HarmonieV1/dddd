-- Horloge déterministe partagée serveur/client : aucune donnée n'est envoyée chaque minute.
-- Le serveur publie un point d'ancrage { real, minute } ; chacun calcule l'heure de jeu localement.
Clock = {}

local segments, dayLength = {}, 0
for _, s in ipairs(Config.DayProfile) do
    segments[#segments + 1] = { from = s.from * 60, to = s.to * 60, spm = s.spm }
    dayLength = dayLength + (s.to - s.from) * 60 * s.spm
end
for i, s in ipairs(segments) do
    local expected = i == 1 and 0 or segments[i - 1].to
    assert(s.from == expected and s.to > s.from and s.spm > 0, 'gs_weather : Config.DayProfile invalide (trou ou chevauchement)')
end
assert(segments[#segments].to == 1440, 'gs_weather : Config.DayProfile doit finir à 24h')

local function segmentAt(minute)
    for _, s in ipairs(segments) do
        if minute >= s.from and minute < s.to then return s end
    end
    return segments[#segments]
end

--- Durée réelle (secondes) d'une journée de jeu complète.
function Clock.dayLength() return dayLength end

--- Minute de jeu (0 ≤ m < 1440) atteinte depuis `minute` après `elapsed` secondes réelles.
function Clock.advance(minute, elapsed)
    elapsed = elapsed % dayLength
    local m = minute % 1440
    while elapsed > 0 do
        local s = segmentAt(m)
        local toEnd = (s.to - m) * s.spm
        if elapsed < toEnd then
            m = m + elapsed / s.spm
            elapsed = 0
        else
            m = s.to % 1440
            elapsed = elapsed - toEnd
        end
    end
    return m
end

--- Minute de jeu courante pour un ancrage { real, minute, frozen } et l'heure réelle `now`.
function Clock.now(anchor, now)
    if anchor.frozen then return anchor.minute end
    return Clock.advance(anchor.minute, now - anchor.real)
end

function Clock.split(minute)
    local h = math.floor(minute / 60)
    local m = math.floor(minute % 60)
    return h, m, math.floor((minute % 1) * 60)
end
