Config = {}

-- ============================================================
-- Général
-- ============================================================
Config.Locale = 'fr'
Config.Debug = false

Config.ResourceName = GetCurrentResourceName()

-- ============================================================
-- Mode CT : NPC ou Métier
-- true  = NPC / Marker (tout le monde peut acheter un CT)
-- false = Métier (seuls les employés CT peuvent faire passer le CT)
-- ============================================================
Config.UseNPC = false --Si NPC false, métier = true

-- NPC / Marker
Config.NPC = {
    enabled = false, -- si UseNPC=true, active l'affichage NPC
    model = 's_m_m_autoshop_01',
    scenario = 'WORLD_HUMAN_CLIPBOARD',
    coords = vec4(-337.63, -134.12, 38.99, 64.05), -- exemple (LS Customs)
    drawDistance = 25.0,
    interactDistance = 2.0
}

-- Métier CT (si UseNPC=false)
Config.CTJob = {
    name = 'controletech', -- Ajouter le sql du job depuis /sql/job.sql
    gradeMin = 0, -- Par défaut j'ai fait un seul grade donc le 0
    interactDistance = 3.0,

    -- Point d'accès métier CT (marker)
    point = vec4(-328.6439, -121.5518, 38.9912, 239.8044),
    drawDistance = 25.0,
    requireInVehicle = false -- true = doit être dans un véhicule pour ouvrir le menu
}

-- ============================================================
-- Police
-- ============================================================
Config.Police = {
    jobs = { 'police', 'sheriff' }, -- jobs autorisés
    scannerItem = 'ct_scanner',
    scannerRange = 200.0,
    controlCommand = 'ctcontrol',   -- commande menu contrôle complet (en visée)
    controlRange = 6.0,
    fineCooldownMinutes = 15,       -- évite le spam sur la même plaque
    fineAccount = 'money'            -- 'bank' recommandé (ESX)
    -- money (pour le liquide sur sois.)
}

-- ============================================================
-- Items ox_inventory
-- IMPORTANT: les items doivent exister dans ox_inventory/data/items.lua
-- Ajoute ces 2 items:
--   - ct_paper   (papier CT)
--   - ct_scanner (scanner police)
-- Le script fournit une section prête à copier dans docs.
-- ============================================================
Config.Items = {
    ctPaper = 'ct_paper',
    scanner = 'ct_scanner'
}

Config.CTPaper = {
    askIfAlreadyHas = true,   -- demande si déjà un ct_paper
    maxOwned = 1              -- nb max de ct_paper que le joueur peut garder
}

-- ============================================================
-- Durées & prix du CT
-- ============================================================
-- Durées disponibles (jours) + multiplicateur prix
Config.CTDurations = {
    { days = 7,  multiplier = 1.0, label = '7 jours'  },
    { days = 14, multiplier = 1.7, label = '14 jours' },
    { days = 30, multiplier = 3.0, label = '30 jours' }
}

-- Prix de base par classe GTA (0-21). 0 = Compacts, 1 = Sedans, ...
-- Mets les prix que tu veux. Le prix final = base * multiplier durée
Config.BasePriceByClass = {
    [0]=450, [1]=500, [2]=650, [3]=700, [4]=750, [5]=900,
    [6]=850, [7]=900, [8]=350, [9]=550, [10]=800, [11]=700,
    [12]=600, [13]=200, [14]=900, [15]=1200, [16]=1500, [17]=650,
    [18]=800, [19]=1100, [20]=1250, [21]=1000
}
Config.DefaultBasePrice = 650

-- ============================================================
-- Amendes CT (automatiques, non modifiables par la police)
-- ============================================================
Config.Fines = {
    graceDays = 0,                 -- tolérance après expiration
    minFine = 250,
    maxFine = 5000,                 -- SI aucune CT a était passer, l'expiration sera de 999 donc le prix max pour l'amande !
    baseFineByClass = {            -- base par classe
        [0]=250,[1]=300,[2]=350,[3]=400,[4]=450,[5]=550,
        [6]=500,[7]=550,[8]=200,[9]=320,[10]=500,[11]=400,
        [12]=350,[13]=150,[14]=600,[15]=900,[16]=1200,[17]=400,
        [18]=500,[19]=800,[20]=900,[21]=650
    },
    defaultBase = 400,
    perDay = 35,                   -- +X par jour de retard
    perDayByClassMultiplier = {    -- optionnel: multiplier par classe (sinon 1.0)
        -- [15]=1.3, [16]=1.5
    },
    offlineFineMode = 'store',     -- 'store' = stocke en DB si propriétaire offline, 'skip' = ne rien faire
}

-- ============================================================
-- MultiChar / lookup identité
-- ============================================================
-- normal  : users.identifier correspond directement à owned_vehicles.owner
-- multichar: idem, mais supporte charX:...
Config.IdentifierMode = 'multichar' --ou normal

-- Si ton users.identifier ne contient PAS "charX:" mais owned_vehicles.owner SI,
-- active ceci pour lookup
Config.StripCharPrefixForUsersLookup = false

-- ============================================================
-- SQL / Tables
-- ============================================================
Config.DB = {
    ownedVehiclesTable = 'owned_vehicles',
    ownedVehiclesOwnerCol = 'owner',
    ownedVehiclesPlateCol = 'plate',
    ownedVehiclesVehicleCol = 'vehicle',

    -- Colonnes CT ajoutées par le script (voir sql/install.sql)
    ctValidUntilCol = 'ct_valid_until',
    ctLastCheckCol  = 'ct_last_check',
    ctLastDurationCol = 'ct_last_duration',

    usersTable = 'users',
    usersIdentifierCol = 'identifier',
    usersFirstnameCol = 'firstname',
    usersLastnameCol = 'lastname',

    historyTable = 'ct_history',
    policeLogTable = 'ct_police_actions',
    finesTable = 'ct_fines'
}

-- ============================================================
-- Texte / UI
-- ============================================================
Config.UI = {
    titleCT = 'Contrôle Technique',
    titlePolice = 'Contrôle CT',
    moneySymbol = '$'
}--OUBLIE PAS: d'ajouter le sql du job depuis sql/job.sql
