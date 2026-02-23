local ESX = exports['es_extended']:getSharedObject()

local function debugPrint(...)
    if Config.Debug then
        print('^6[ducratif_ct]^7', ...)
    end
end

-- ============================================================
-- Utils: simple camera
-- ============================================================
local function raycastVehicle(maxDistance)
    local ped = cache.ped
    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local dir = (function(rot)
        local z = math.rad(rot.z)
        local x = math.rad(rot.x)
        local num = math.abs(math.cos(x))
        return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
    end)(camRot)

    local dest = camCoords + (dir * maxDistance)
    local ray = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, dest.x, dest.y, dest.z, 10, ped, 0)
    local _, hit, endCoords, _, entity = GetShapeTestResult(ray)

    if hit == 1 and entity and entity ~= 0 and IsEntityAVehicle(entity) then
        return entity, endCoords
    end

    if IsPedInAnyVehicle(ped, false) then
        return GetVehiclePedIsIn(ped, false), GetEntityCoords(ped)
    end

    return nil, nil
end

local function getVehiclePlate(vehicle)
    local plate = GetVehicleNumberPlateText(vehicle)
    return Utils_NormalizePlate(plate)
end

local function getVehicleModel(vehicle)
    return GetEntityModel(vehicle)
end

local function getVehicleClass(vehicle)
    return GetVehicleClass(vehicle)
end

-- ============================================================
-- UI helpers
-- ============================================================
local function showNotify(msg, type)
    lib.notify({
        title = 'CT',
        description = msg,
        type = type or 'inform'
    })
end

local function fmtMoney(amount)
    return (Config.UI.moneySymbol or '$') .. tostring(amount)
end

-- ============================================================
-- NPC / Marker
-- ============================================================
local npcEntity

local function spawnNPC()
    if not Config.UseNPC or not Config.NPC.enabled then return end
    local data = Config.NPC
    local model = joaat(data.model)
    lib.requestModel(model)

    npcEntity = CreatePed(0, model, data.coords.x, data.coords.y, data.coords.z - 1.0, data.coords.w, false, false)
    SetEntityAsMissionEntity(npcEntity, true, true)
    FreezeEntityPosition(npcEntity, true)
    SetBlockingOfNonTemporaryEvents(npcEntity, true)
    SetEntityInvincible(npcEntity, true)
    if data.scenario and data.scenario ~= '' then
        TaskStartScenarioInPlace(npcEntity, data.scenario, 0, true)
    end
end

local function deleteNPC()
    if npcEntity and DoesEntityExist(npcEntity) then
        DeleteEntity(npcEntity)
    end
    npcEntity = nil
end

local function openCTMenuForVehicle(vehicle)
    if not vehicle then
        showNotify("Aucun véhicule détecté.", "error")
        return
    end

    local plate = getVehiclePlate(vehicle)
    local class = getVehicleClass(vehicle)
    local model = getVehicleModel(vehicle)

    local options = {}
    for _, d in ipairs(Config.CTDurations) do
        local base = Config.BasePriceByClass[class] or Config.DefaultBasePrice
        local price = math.floor(base * d.multiplier)
        options[#options+1] = {
            title = ('Passer le CT (%s)'):format(d.label),
            description = ('Prix: %s | Plaque: %s | Classe: %d'):format(fmtMoney(price), plate, class),
            icon = 'clipboard-check',
            onSelect = function()
                local ok, err = lib.callback.await('ducratif_ct:buyCT', false, {
                    plate = plate,
                    model = model,
                    class = class,
                    days = d.days
                })
                if ok then
                    showNotify(('✅ CT validé %s jours pour %s.'):format(d.days, plate), 'success')
                else
                    showNotify(err or "Impossible d'effectuer le CT.", 'error')
                end
            end
        }
    end

    options[#options+1] = {
        title = 'Voir statut CT',
        description = 'Affiche la date de validité du CT en base.',
        icon = 'circle-info',
        onSelect = function()
            local data = lib.callback.await('ducratif_ct:getVehicleInfo', false, plate)
            if not data then
                showNotify("Véhicule introuvable en base.", 'error')
                return
            end
            local desc = ('Plaque: %s\nProprio: %s\nCT: %s\nValide jusqu\'au: %s'):format(
                data.plate, data.owner_name or data.owner_identifier or 'Inconnu',
                data.ct_status_label or 'Inconnu',
                data.ct_valid_until or 'N/A'
            )
            lib.alertDialog({
                header = Config.UI.titleCT,
                content = desc,
                centered = true
            })
        end
    }

    lib.registerContext({
        id = 'ducratif_ct:ctmenu',
        title = Config.UI.titleCT,
        options = options
    })
    lib.showContext('ducratif_ct:ctmenu')
end

local function openCTFromNPC()
    local veh, _ = raycastVehicle(6.0)
    openCTMenuForVehicle(veh)
end

CreateThread(function()
    if Config.UseNPC and Config.NPC.enabled then
        spawnNPC()
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    deleteNPC()
end)

CreateThread(function()
    while true do
        local sleep = 1000
        if Config.UseNPC and Config.NPC.enabled then
            local ped = cache.ped
            local coords = GetEntityCoords(ped)
            local npcPos = vector3(Config.NPC.coords.x, Config.NPC.coords.y, Config.NPC.coords.z)
            local dist = #(coords - npcPos)

            if dist < Config.NPC.drawDistance then
                sleep = 0
                DrawMarker(2, npcPos.x, npcPos.y, npcPos.z + 0.2, 0.0,0.0,0.0, 0.0,0.0,0.0, 0.25,0.25,0.25, 80,200,120, 180, false,false,2,true,nil,nil,false)
                if dist < Config.NPC.interactDistance then
                    lib.showTextUI('[E] Passer le Contrôle Technique')
                    if IsControlJustReleased(0, 38) then
                        openCTFromNPC()
                    end
                else
                    lib.hideTextUI()
                end
            else
                lib.hideTextUI()
            end
        end
        Wait(sleep)
    end
end)

-- ============================================================
-- Job CT (si UseNPC=false)
-- ============================================================
RegisterNetEvent('ducratif_ct:openJobCT', function()
    local veh, _ = raycastVehicle(6.0)
    if not veh then
        showNotify("Aucun véhicule détecté.", "error")
        return
    end

    local plate = getVehiclePlate(veh)
    local class = getVehicleClass(veh)
    local model = getVehicleModel(veh)

    local defects = Config.JobDefects or {
        { id='tires', label='Pneus usés', blocking=false },
        { id='lights', label='Phares défectueux', blocking=true },
        { id='windows', label='Vitres non conformes', blocking=false },
        { id='body', label='Carrosserie dangereuse', blocking=true },
    }

    local defectOptions = {}
    for i, d in ipairs(defects) do
        defectOptions[#defectOptions+1] = {
            type = 'checkbox',
            label = d.label .. (d.blocking and ' (Bloquant)' or ''),
            checked = false
        }
    end

    local input = lib.inputDialog('Inspection CT - ' .. plate, defectOptions)
    if not input then return end

    local selected = {}
    local hasBlocking = false
    for i, checked in ipairs(input) do
        if checked then
            local d = defects[i]
            selected[#selected+1] = { id = d.id, label = d.label, blocking = d.blocking }
            if d.blocking then hasBlocking = true end
        end
    end

    -- Choix durée
    local durOpts = {}
    for _, d in ipairs(Config.CTDurations) do
        durOpts[#durOpts+1] = { label = d.label, value = d.days }
    end

    local days = lib.inputDialog('Durée du CT', {
        { type='select', label='Choisir la durée', options=durOpts, required=true }
    })
    if not days then return end
    local chosenDays = days[1]

    local ok, err = lib.callback.await('ducratif_ct:jobCT', false, {
        plate = plate,
        model = model,
        class = class,
        days = chosenDays,
        defects = selected,
        result = hasBlocking and 'refused' or 'passed'
    })

    if ok then
        if hasBlocking then
            showNotify('❌ CT refusé (défauts bloquants).', 'error')
        else
            showNotify(('✅ CT validé %d jours.'):format(chosenDays), 'success')
        end
    else
        showNotify(err or 'Erreur CT.', 'error')
    end
end)

-- ============================================================
-- ox_inventory item exports
-- ============================================================
exports('ct_paper', function(data, slot)
    local vehicle, _ = raycastVehicle(6.0)
    if not vehicle then
        showNotify("Vise un véhicule (ou monte dedans) pour montrer le CT.", "error")
        return
    end

    local plate = getVehiclePlate(vehicle)
    local info = lib.callback.await('ducratif_ct:getVehicleInfo', false, plate)

    if not info then
        showNotify("Véhicule introuvable en base.", "error")
        return
    end

    local content = ('**Plaque:** %s\n**Proprio:** %s\n**CT:** %s\n**Valide jusqu\'au:** %s'):format(
        info.plate or plate,
        info.owner_name or info.owner_identifier or 'Inconnu',
        info.ct_status_label or 'N/A',
        info.ct_valid_until or 'N/A'
    )

    lib.alertDialog({
        header = 'Papier CT',
        content = content,
        centered = true
    })
end)


exports('ct_scanner', function(data, slot)
    local ped = cache.ped
    local entity, _ = raycastVehicle(Config.Police.scannerRange or 200.0)
    if not entity then
        showNotify("Aucun véhicule ciblé.", "error")
        return
    end

    local plate = getVehiclePlate(entity)
    local res = lib.callback.await('ducratif_ct:policeScan', false, plate)

    if not res then
        showNotify("Véhicule introuvable en base.", "error")
        return
    end

    local content = ('**Plaque:** %s\n**Proprio:** %s\n**Classe:** %s\n**CT:** %s\n**Valide jusqu\'au:** %s\n**Retard:** %s'):format(
        res.plate or plate,
        res.owner_name or res.owner_identifier or 'Inconnu',
        tostring(res.vehicle_class or 'N/A'),
        res.ct_status_label or 'Inconnu',
        res.ct_valid_until or 'N/A',
        res.days_overdue_label or 'N/A'
    )

    lib.alertDialog({
        header = Config.UI.titlePolice,
        content = content,
        centered = true
    })
end)

-- ============================================================
-- Police control command (menu complet)
-- ============================================================
RegisterCommand(Config.Police.controlCommand or 'ctcontrol', function()
    local entity, _ = raycastVehicle(Config.Police.controlRange or 6.0)
    if not entity then
        showNotify("Aucun véhicule visé.", "error")
        return
    end

    local plate = getVehiclePlate(entity)
    local res = lib.callback.await('ducratif_ct:policeControlData', false, plate)
    if not res then
        showNotify("Véhicule introuvable en base.", "error")
        return
    end

    local options = {
        {
            title = 'Informations véhicule',
            icon = 'car',
            description = ('Plaque: %s | Classe: %s | Modèle: %s'):format(res.plate, res.vehicle_class or 'N/A', res.model_label or 'N/A')
        },
        {
            title = 'Propriétaire',
            icon = 'id-card',
            description = (res.owner_name or 'Inconnu') .. ' (' .. (res.owner_identifier or 'N/A') .. ')'
        },
        {
            title = 'CT',
            icon = 'clipboard-check',
            description = ('%s | Valide jusqu\'au: %s | Retard: %s'):format(
                res.ct_status_label or 'N/A',
                res.ct_valid_until or 'N/A',
                res.days_overdue_label or 'N/A'
            )
        }
    }

    if res.ct_is_expired then
        options[#options+1] = {
            title = 'Mettre amende CT (automatique)',
            icon = 'file-invoice-dollar',
            description = ('Montant: %s (auto)'):format(fmtMoney(res.fine_amount or 0)),
            onSelect = function()
                local ok, err = lib.callback.await('ducratif_ct:issueFine', false, plate)
                if ok then
                    showNotify(('✅ Amende appliquée: %s'):format(fmtMoney(res.fine_amount or 0)), 'success')
                else
                    showNotify(err or "Impossible d'appliquer l'amende.", 'error')
                end
            end
        }
    end

    lib.registerContext({
        id = 'ducratif_ct:policecontrol',
        title = Config.UI.titlePolice,
        options = options
    })
    lib.showContext('ducratif_ct:policecontrol')
end, false)


-- ============================================================
-- Marker métier CT (si UseNPC = false)
-- ============================================================
local PlayerJobName = nil
local PlayerJobGrade = 0

local function refreshJob()
    local pd = ESX.GetPlayerData() or {}
    local job = pd.job or {}
    PlayerJobName = job.name
    PlayerJobGrade = job.grade or 0
end

RegisterNetEvent('esx:playerLoaded', function()
    refreshJob()
end)

RegisterNetEvent('esx:setJob', function(job)
    PlayerJobName = job.name
    PlayerJobGrade = job.grade or 0
end)

CreateThread(function()
    Wait(1500)
    refreshJob()

    while true do
        local sleep = 1000

        if not Config.UseNPC and Config.CTJob and Config.CTJob.point then
            local isJob = (PlayerJobName == Config.CTJob.name and (PlayerJobGrade or 0) >= (Config.CTJob.gradeMin or 0))
            if isJob then
                local ped = cache.ped
                local coords = GetEntityCoords(ped)
                local p = Config.CTJob.point
                local pos = vector3(p.x, p.y, p.z)
                local dist = #(coords - pos)

                if dist < (Config.CTJob.drawDistance or 25.0) then
                    sleep = 0

                    -- Marker
                    DrawMarker(
                        2,
                        pos.x, pos.y, pos.z + 0.2,
                        0.0,0.0,0.0,
                        0.0,0.0,0.0,
                        0.25,0.25,0.25,
                        80,200,120, 180,
                        false,false,2,true,nil,nil,false
                    )

                    if dist < (Config.CTJob.interactDistance or 3.0) then
                        lib.showTextUI('[E] Inspection / Passer un CT (Métier)')

                        if IsControlJustReleased(0, 38) then
                            if Config.CTJob.requireInVehicle and not IsPedInAnyVehicle(ped, false) then
                                lib.notify({ title='CT', description='Tu dois être dans un véhicule.', type='error' })
                            else
                                -- ouvre le menu métier existant
                                TriggerEvent('ducratif_ct:openJobCT')
                            end
                        end
                    else
                        lib.hideTextUI()
                    end
                else
                    lib.hideTextUI()
                end
            else
                lib.hideTextUI()
            end
        end

        Wait(sleep)
    end
end)

-- ============================================================
-- Confirmation de donner un nouveau CT_PAPER
-- ============================================================
lib.callback.register('ducratif_ct:confirmNewPaper', function(data)
    local ok = lib.alertDialog({
        header = 'Papier CT',
        content = ('Tu as déjà un papier CT.\n\nVoulez-vous en générer un nouveau ?\n\nPlaque: %s\nValide jusqu\'au: %s'):format(
            data.plate or 'N/A',
            data.valid_until or 'N/A'
        ),
        centered = true,
        cancel = true
    })

    return ok == 'confirm'
end)
