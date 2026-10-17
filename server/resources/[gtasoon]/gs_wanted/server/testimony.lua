-- gs_wanted (serveur) · V12.65 · Témoins (proposition n° 317) : chaque crime SIGNALÉ laisse un témoignage (ce que les passants
-- ont vu : tenue, véhicule, plaque partielle ; jamais l'identité), rattaché au suspect et gardé `days` jours. Au procès,
-- un passant PNJ vient le raconter à la barre (gs_justice).
Testimony = {}
local T = Config.Testimony or { keep = 5, days = 14 }

local function key(cid) return 'testimony:' .. tostring(cid) end

function Testimony.list(cid)
    if not cid then return {} end
    local ok, l = pcall(json.decode, GetResourceKvpString(key(cid)) or '[]')
    l = ok and type(l) == 'table' and l or {}
    local since, out = os.time() - T.days * 86400, {}
    for _, t in ipairs(l) do if (tonumber(t.at) or 0) >= since then out[#out + 1] = t end end
    return out
end

function Testimony.add(cid, report, coords)
    if not cid or not report or (report.witnesses or 0) == 0 and not report.camera then return end -- personne n'a rien vu
    local place
    if GetResourceState('gs_city') == 'started' and coords then
        local ok, _, label = pcall(function() return exports.gs_city:GetLevel(coords) end)
        if ok then place = label end
    end
    local l = Testimony.list(cid)
    table.insert(l, 1, { crime = report.label, desc = table.concat(report.desc or {}, ', '), plate = report.plate, camera = report.camera,
        place = place, at = os.time(), police = report.witnesses == -1 or nil })
    while #l > T.keep do table.remove(l) end
    SetResourceKvp(key(cid), json.encode(l))
end

--- Phrase du témoin à la barre (jamais le nom du suspect)
function Testimony.speech(t)
    local when = os.date('le %d/%m vers %H h', tonumber(t.at) or os.time())
    local where = t.place and (' à ' .. t.place) or ''
    local seen = (t.desc and t.desc ~= '') and t.desc or 'je n\'ai pas bien vu son visage'
    local plate = t.plate and (' Le véhicule avait une plaque qui commençait par « %s ».'):format(t.plate) or ''
    local who = t.police and 'Un agent de police' or 'Un passant'
    return ('%s témoigne : « %s%s, j\'ai assisté à : %s. J\'ai vu %s.%s »'):format(who, when, where, (t.crime or 'un crime'):lower(), seen, plate)
end

exports('Testimonies', function(cid) return Testimony.list(cid) end)
exports('TestimonySpeech', function(t) return Testimony.speech(t) end)
