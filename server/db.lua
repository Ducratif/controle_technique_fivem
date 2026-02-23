local function dbg(...)
    if Config.Debug then
        print('^6[ducratif_ct]^7', ...)
    end
end

DB = {}

function DB.GetVehicleByPlate(plate)
    local t = Config.DB.ownedVehiclesTable
    local plateCol = Config.DB.ownedVehiclesPlateCol
    local q = ('SELECT * FROM %s WHERE %s = ? LIMIT 1'):format(t, plateCol)
    return MySQL.single.await(q, { plate })
end

function DB.UpdateCT(plate, validUntil, days)
    local t = Config.DB.ownedVehiclesTable
    local plateCol = Config.DB.ownedVehiclesPlateCol
    local q = ('UPDATE %s SET %s = ?, %s = NOW(), %s = ? WHERE %s = ?'):format(
        t,
        Config.DB.ctValidUntilCol,
        Config.DB.ctLastCheckCol,
        Config.DB.ctLastDurationCol,
        plateCol
    )
    return MySQL.update.await(q, { validUntil, days, plate })
end

function DB.GetOwnerName(identifier)
    local u = Config.DB.usersTable
    local idCol = Config.DB.usersIdentifierCol
    local fn = Config.DB.usersFirstnameCol
    local ln = Config.DB.usersLastnameCol

    local lookup = identifier
    if Config.StripCharPrefixForUsersLookup then
        lookup = Utils_StripCharPrefix(identifier)
    end

    local q = ('SELECT %s as firstname, %s as lastname FROM %s WHERE %s = ? LIMIT 1'):format(fn, ln, u, idCol)
    local row = MySQL.single.await(q, { lookup })
    if not row then return nil end
    local name = (row.firstname or '') .. ' ' .. (row.lastname or '')
    name = name:gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' then return nil end
    return name
end

function DB.InsertHistory(data)
    local t = Config.DB.historyTable
    local q = ('INSERT INTO %s (plate, owner_identifier, vehicle_model, vehicle_class, duration_days, price_paid, result, defects_json, passed_by_type, passed_by_identifier, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,NOW())'):format(t)
    return MySQL.insert.await(q, {
        data.plate,
        data.owner_identifier,
        tostring(data.vehicle_model or ''),
        tonumber(data.vehicle_class or -1),
        tonumber(data.duration_days or 0),
        tonumber(data.price_paid or 0),
        data.result or 'passed',
        json.encode(data.defects or {}),
        data.passed_by_type or 'npc',
        data.passed_by_identifier
    })
end

function DB.InsertPoliceLog(data)
    local t = Config.DB.policeLogTable
    local q = ('INSERT INTO %s (officer_identifier, officer_job, plate, owner_identifier, action, scan_type, fine_amount, days_overdue, vehicle_class, created_at) VALUES (?,?,?,?,?,?,?,?,?,NOW())'):format(t)
    return MySQL.insert.await(q, {
        data.officer_identifier,
        data.officer_job,
        data.plate,
        data.owner_identifier,
        data.action,
        data.scan_type,
        data.fine_amount,
        data.days_overdue,
        data.vehicle_class
    })
end

function DB.GetLastFineAt(plate)
    local t = Config.DB.policeLogTable
    local q = ('SELECT created_at FROM %s WHERE plate = ? AND action = "fine_issued" ORDER BY id DESC LIMIT 1'):format(t)
    return MySQL.single.await(q, { plate })
end

function DB.InsertFine(data)
    local t = Config.DB.finesTable
    local q = ('INSERT INTO %s (owner_identifier, plate, fine_amount, reason, status, created_at) VALUES (?,?,?,?,?,NOW())'):format(t)
    return MySQL.insert.await(q, {
        data.owner_identifier,
        data.plate,
        data.fine_amount,
        data.reason or 'CT expiré',
        data.status or 'unpaid'
    })
end
