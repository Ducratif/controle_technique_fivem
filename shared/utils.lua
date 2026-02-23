local function _trim(s)
    if not s then return '' end
    return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

function Utils_NormalizePlate(plate)
    plate = _trim(plate)
    plate = plate:gsub('%s+', ' ')
    return plate:upper()
end

function Utils_StripCharPrefix(identifier)
    if not identifier then return nil end
    return identifier:gsub('^char%d+:', '')
end

function Utils_ToISOString(ts)
    -- ts can be os.time() or string; returns readable date
    if type(ts) == 'number' then
        return os.date('%Y-%m-%d %H:%M:%S', ts)
    end
    return tostring(ts)
end

function Utils_DaysBetween(nowTs, pastTs)
    local diff = nowTs - pastTs
    if diff < 0 then diff = 0 end
    return math.floor(diff / 86400)
end

function Utils_Clamp(x, minv, maxv)
    if x < minv then return minv end
    if x > maxv then return maxv end
    return x
end

function Utils_TableHasValue(t, val)
    for _, v in pairs(t) do
        if v == val then return true end
    end
    return false
end
