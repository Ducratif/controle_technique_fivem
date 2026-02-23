local ESX = exports['es_extended']:getSharedObject()

local function dbg(...)
    if Config.Debug then
        print('^6[ducratif_ct]^7', ...)
    end
end

local function isPolice(xPlayer)
    if not xPlayer then return false end
    local job = xPlayer.getJob()
    if not job then return false end
    return Utils_TableHasValue(Config.Police.jobs, job.name)
end

local function isCTWorker(xPlayer)
    if not xPlayer then return false end
    local job = xPlayer.getJob()
    if not job then return false end
    if job.name ~= Config.CTJob.name then return false end
    return (job.grade or 0) >= (Config.CTJob.gradeMin or 0)
end

local function calcCTPrice(vehicleClass, days)
    local base = Config.BasePriceByClass[vehicleClass] or Config.DefaultBasePrice
    local mult = 1.0
    for _, d in ipairs(Config.CTDurations) do
        if d.days == days then
            mult = d.multiplier or 1.0
            break
        end
    end
    return math.floor(base * mult)
end

local function getVehicleClassFromModel(model)
    if not model then return -1 end
    local ok, cls = pcall(function()
        return GetVehicleClassFromName(model)
    end)
    if ok and cls ~= nil then return tonumber(cls) end
    return -1
end

local function getCTStatus(validUntilStr)
    if not validUntilStr or validUntilStr == '' then
        return true, nil, 9999
    end

    -- oxmysql peut renvoyer un timestamp (number) au lieu d'une string DATETIME
    if type(validUntilStr) == 'number' then
        local ts = validUntilStr
        -- si c'est en millisecondes, on convertit en secondes
        if ts > 1000000000000 then
            ts = math.floor(ts / 1000)
        end

        local now = os.time()
        local expired = now > ts
        local daysOver = expired and Utils_DaysBetween(now, ts) or 0
        return expired, os.date('%Y-%m-%d %H:%M:%S', ts), daysOver
    end

    validUntilStr = tostring(validUntilStr)

    -- MySQL DATETIME string -> timestamp (server)
    local y,mo,d,h,mi,s = validUntilStr:match('(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)')
    if not y then
        return true, validUntilStr, 9999
    end

    local ts = os.time({
        year = tonumber(y),
        month = tonumber(mo),
        day = tonumber(d),
        hour = tonumber(h),
        min = tonumber(mi),
        sec = tonumber(s)
    })

    local now = os.time()
    local expired = now > ts
    local daysOver = expired and Utils_DaysBetween(now, ts) or 0
    return expired, validUntilStr, daysOver
end


local function calcFine(vehicleClass, daysOverdue)
    local cfg = Config.Fines
    local base = (cfg.baseFineByClass and cfg.baseFineByClass[vehicleClass]) or cfg.defaultBase or 400
    local perDay = cfg.perDay or 35
    local mult = 1.0
    if cfg.perDayByClassMultiplier and cfg.perDayByClassMultiplier[vehicleClass] then
        mult = cfg.perDayByClassMultiplier[vehicleClass]
    end
    local total = base + math.floor((perDay * mult) * daysOverdue)
    total = Utils_Clamp(total, cfg.minFine or 0, cfg.maxFine or 999999)
    return total
end

-- ============================================================
-- Fonction du CT PAPER
-- ============================================================
local function giveCTPaper(source, plate, validUntil, days, issuedBy)
    local itemName = Config.Items.ctPaper
    local maxOwned = (Config.CTPaper and Config.CTPaper.maxOwned) or 1
    local ask = (Config.CTPaper and Config.CTPaper.askIfAlreadyHas) == true

    local count = exports.ox_inventory:Search(source, 'count', itemName) or 0

    -- Si le joueur en a déjà, soit on bloque, soit on demande
    if count >= maxOwned then
        if ask then
            local confirm = lib.callback.await('ducratif_ct:confirmNewPaper', source, {
                plate = plate,
                valid_until = validUntil,
                days = days,
                issued_by = issuedBy
            })
            if not confirm then
                return false
            end
        else
            return false
        end
    end

    -- Donne un papier (sans metadata obligatoire vu que le papier lit la DB)
    return exports.ox_inventory:AddItem(source, itemName, 1)
end




-- ============================================================
-- CT purchase (NPC mode)
-- ============================================================
lib.callback.register('ducratif_ct:buyCT', function(source, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false, 'Joueur introuvable.' end
    if not Config.UseNPC then return false, 'Mode NPC désactivé.' end

    local plate = Utils_NormalizePlate(data.plate)
    local veh = DB.GetVehicleByPlate(plate)
    if not veh then return false, 'Véhicule introuvable en base.' end

    local owner = veh[Config.DB.ownedVehiclesOwnerCol]
    local modelHash = nil
    if data.model then modelHash = tonumber(data.model) end

    local vclass = getVehicleClassFromModel(modelHash)
    if vclass < 0 and data.class then vclass = tonumber(data.class) end
    if vclass < 0 then vclass = 0 end

    local days = tonumber(data.days)
    local price = calcCTPrice(vclass, days)

    -- payment
    local paid = false
    local bank = xPlayer.getAccount('bank') and xPlayer.getAccount('bank').money or 0
    local cash = xPlayer.getMoney()
    if bank >= price then
        xPlayer.removeAccountMoney('bank', price)
        paid = true
    elseif cash >= price then
        xPlayer.removeMoney(price)
        paid = true
    end

    if not paid then return false, 'Fonds insuffisants.' end

    local validUntil = os.date('%Y-%m-%d %H:%M:%S', os.time() + (days * 86400))
    DB.UpdateCT(plate, validUntil, days)

    DB.InsertHistory({
        plate = plate,
        owner_identifier = owner,
        vehicle_model = modelHash,
        vehicle_class = vclass,
        duration_days = days,
        price_paid = price,
        result = 'passed',
        defects = {},
        passed_by_type = 'npc',
        passed_by_identifier = nil
    })

    giveCTPaper(source, plate, validUntil, days, 'Centre CT (NPC)')
    return true
end)


-- ============================================================
-- Callback des informations via l'item du ct paper
-- ============================================================
lib.callback.register('ducratif_ct:getPaperMeta', function(source, slot)
    local item = exports.ox_inventory:GetSlot(source, slot)
    if not item then return {} end
    return item.metadata or {}
end)

-- ============================================================
-- Vehicle info (general)
-- ============================================================
lib.callback.register('ducratif_ct:getVehicleInfo', function(source, plate)
    plate = Utils_NormalizePlate(plate)
    local veh = DB.GetVehicleByPlate(plate)
    if not veh then return nil end

    local owner = veh[Config.DB.ownedVehiclesOwnerCol]
    local ownerName = DB.GetOwnerName(owner)
    local validUntil = veh[Config.DB.ctValidUntilCol]
    local expired, vu, daysOver = getCTStatus(validUntil)

    return {
        plate = plate,
        owner_identifier = owner,
        owner_name = ownerName,
        ct_valid_until = vu,
        ct_is_expired = expired,
        ct_status_label = expired and '❌ Expiré' or '✅ Valide',
        days_overdue = daysOver,
        days_overdue_label = expired and (tostring(daysOver) .. ' jour(s)') or '0 jour'
    }
end)

-- ============================================================
-- Job CT inspection + pass/refuse
-- ============================================================
lib.callback.register('ducratif_ct:jobCT', function(source, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false, 'Joueur introuvable.' end
    if Config.UseNPC then return false, 'Mode métier désactivé.' end
    if not isCTWorker(xPlayer) then return false, 'Accès refusé.' end

    local plate = Utils_NormalizePlate(data.plate)
    local veh = DB.GetVehicleByPlate(plate)
    if not veh then return false, 'Véhicule introuvable en base.' end

    local owner = veh[Config.DB.ownedVehiclesOwnerCol]
    local days = tonumber(data.days) or 7
    local result = data.result or 'passed'
    local defects = data.defects or {}
    local modelHash = tonumber(data.model) or nil
    local vclass = getVehicleClassFromModel(modelHash)
    if vclass < 0 and data.class then vclass = tonumber(data.class) end
    if vclass < 0 then vclass = 0 end

    if result == 'passed' then
        local validUntil = os.date('%Y-%m-%d %H:%M:%S', os.time() + (days * 86400))
        DB.UpdateCT(plate, validUntil, days)
        giveCTPaper(source, plate, validUntil, days, 'Centre CT (Employé)')
    end

    DB.InsertHistory({
        plate = plate,
        owner_identifier = owner,
        vehicle_model = modelHash,
        vehicle_class = vclass,
        duration_days = days,
        price_paid = 0,
        result = result,
        defects = defects,
        passed_by_type = 'job',
        passed_by_identifier = xPlayer.identifier
    })

    return true
end)

-- ============================================================
-- Police Scan / Control
-- ============================================================
lib.callback.register('ducratif_ct:policeScan', function(source, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not isPolice(xPlayer) then return nil end

    plate = Utils_NormalizePlate(plate)
    local veh = DB.GetVehicleByPlate(plate)
    if not veh then return nil end

    local owner = veh[Config.DB.ownedVehiclesOwnerCol]
    local ownerName = DB.GetOwnerName(owner)
    local validUntil = veh[Config.DB.ctValidUntilCol]
    local expired, vu, daysOver = getCTStatus(validUntil)

    local vehicleData = veh[Config.DB.ownedVehiclesVehicleCol]
    local modelHash
    if vehicleData and type(vehicleData) == 'string' then
        local ok, decoded = pcall(json.decode, vehicleData)
        if ok and decoded and decoded.model then modelHash = tonumber(decoded.model) end
    end
    local vclass = getVehicleClassFromModel(modelHash)
    if vclass < 0 then vclass = 0 end

    DB.InsertPoliceLog({
        officer_identifier = xPlayer.identifier,
        officer_job = xPlayer.getJob().name,
        plate = plate,
        owner_identifier = owner,
        action = 'scan',
        scan_type = 'radar',
        fine_amount = 0,
        days_overdue = daysOver,
        vehicle_class = vclass
    })

    return {
        plate = plate,
        owner_identifier = owner,
        owner_name = ownerName,
        ct_valid_until = vu,
        ct_status_label = expired and '❌ Expiré' or '✅ Valide',
        days_overdue = daysOver,
        days_overdue_label = expired and (tostring(daysOver) .. ' jour(s)') or '0 jour',
        vehicle_class = vclass
    }
end)

lib.callback.register('ducratif_ct:policeControlData', function(source, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not isPolice(xPlayer) then return nil end

    plate = Utils_NormalizePlate(plate)
    local veh = DB.GetVehicleByPlate(plate)
    if not veh then return nil end

    local owner = veh[Config.DB.ownedVehiclesOwnerCol]
    local ownerName = DB.GetOwnerName(owner)
    local validUntil = veh[Config.DB.ctValidUntilCol]
    local expired, vu, daysOver = getCTStatus(validUntil)

    local vehicleData = veh[Config.DB.ownedVehiclesVehicleCol]
    local modelHash
    if vehicleData and type(vehicleData) == 'string' then
        local ok, decoded = pcall(json.decode, vehicleData)
        if ok and decoded and decoded.model then modelHash = tonumber(decoded.model) end
    end
    local vclass = getVehicleClassFromModel(modelHash)
    if vclass < 0 then vclass = 0 end

    local fine = expired and calcFine(vclass, math.max(0, daysOver - (Config.Fines.graceDays or 0))) or 0

    DB.InsertPoliceLog({
        officer_identifier = xPlayer.identifier,
        officer_job = xPlayer.getJob().name,
        plate = plate,
        owner_identifier = owner,
        action = 'scan',
        scan_type = 'full_control',
        fine_amount = fine,
        days_overdue = daysOver,
        vehicle_class = vclass
    })

    return {
        plate = plate,
        owner_identifier = owner,
        owner_name = ownerName,
        ct_valid_until = vu,
        ct_is_expired = expired,
        ct_status_label = expired and '❌ Expiré' or '✅ Valide',
        days_overdue = daysOver,
        days_overdue_label = expired and (tostring(daysOver) .. ' jour(s)') or '0 jour',
        vehicle_class = vclass,
        fine_amount = fine,
        model_label = modelHash and tostring(modelHash) or 'N/A'
    }
end)

lib.callback.register('ducratif_ct:issueFine', function(source, plate)
    local officer = ESX.GetPlayerFromId(source)
    if not officer or not isPolice(officer) then return false, 'Accès refusé.' end

    plate = Utils_NormalizePlate(plate)
    local veh = DB.GetVehicleByPlate(plate)
    if not veh then return false, 'Véhicule introuvable.' end

    local owner = veh[Config.DB.ownedVehiclesOwnerCol]
    local validUntil = veh[Config.DB.ctValidUntilCol]
    local expired, vu, daysOver = getCTStatus(validUntil)
    if not expired then return false, 'CT valide.' end

    local grace = Config.Fines.graceDays or 0
    local overdueForFine = math.max(0, daysOver - grace)
    if overdueForFine <= 0 and grace > 0 then
        return false, 'Période de tolérance.'
    end

    -- cooldown par plaque
    local last = DB.GetLastFineAt(plate)
    if last and last.created_at then
        local y,mo,d,h,mi,s = tostring(last.created_at):match('(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)')
        if y then
            local ts = os.time({year=tonumber(y), month=tonumber(mo), day=tonumber(d), hour=tonumber(h), min=tonumber(mi), sec=tonumber(s)})
            local now = os.time()
            local minutes = math.floor((now - ts) / 60)
            if minutes < (Config.Police.fineCooldownMinutes or 15) then
                return false, ('Cooldown amende (%d min restantes).'):format((Config.Police.fineCooldownMinutes or 15) - minutes)
            end
        end
    end

    local vehicleData = veh[Config.DB.ownedVehiclesVehicleCol]
    local modelHash
    if vehicleData and type(vehicleData) == 'string' then
        local ok, decoded = pcall(json.decode, vehicleData)
        if ok and decoded and decoded.model then modelHash = tonumber(decoded.model) end
    end
    local vclass = getVehicleClassFromModel(modelHash)
    if vclass < 0 then vclass = 0 end

    local fine = calcFine(vclass, overdueForFine)

    local ownerOnline = nil
    for _, playerId in ipairs(GetPlayers()) do
        local xp = ESX.GetPlayerFromId(tonumber(playerId))
        if xp and xp.identifier == owner then
            ownerOnline = xp
            break
        end
    end

    if ownerOnline then
        local acc = Config.Police.fineAccount or 'bank'
        ownerOnline.removeAccountMoney(acc, fine)
    else
        if Config.Fines.offlineFineMode == 'store' then
            DB.InsertFine({
                owner_identifier = owner,
                plate = plate,
                fine_amount = fine,
                reason = 'CT expiré',
                status = 'unpaid'
            })
        else
            return false, 'Propriétaire offline (amende ignorée par config).'
        end
    end

    DB.InsertPoliceLog({
        officer_identifier = officer.identifier,
        officer_job = officer.getJob().name,
        plate = plate,
        owner_identifier = owner,
        action = 'fine_issued',
        scan_type = 'full_control',
        fine_amount = fine,
        days_overdue = daysOver,
        vehicle_class = vclass
    })

    return true
end)
