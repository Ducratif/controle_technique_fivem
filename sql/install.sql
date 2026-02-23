-- ============================================================
-- ducratif_ct - Installation SQL
-- ============================================================

-- 1) Ajout colonnes CT sur owned_vehicles
ALTER TABLE `owned_vehicles`
  --ADD COLUMN IF NOT EXISTS `ct_valid_until` DATETIME NULL DEFAULT NULL,
  --ADD COLUMN IF NOT EXISTS `ct_last_check` DATETIME NULL DEFAULT NULL,
  --ADD COLUMN IF NOT EXISTS `ct_last_duration` INT NULL DEFAULT NULL;

  ADD COLUMN `ct_valid_until` DATETIME NULL DEFAULT NULL,
  ADD COLUMN `ct_last_check` DATETIME NULL DEFAULT NULL,
  ADD COLUMN `ct_last_duration` INT NULL DEFAULT NULL;

-- 2) Historique des CT
CREATE TABLE IF NOT EXISTS `ct_history` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `plate` VARCHAR(32) NOT NULL,
  `owner_identifier` VARCHAR(80) NULL,
  `vehicle_model` VARCHAR(32) NULL,
  `vehicle_class` INT NULL,
  `duration_days` INT NULL,
  `price_paid` INT NULL,
  `result` VARCHAR(16) NOT NULL DEFAULT 'passed',
  `defects_json` LONGTEXT NULL,
  `passed_by_type` VARCHAR(16) NOT NULL DEFAULT 'npc',
  `passed_by_identifier` VARCHAR(80) NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_ct_history_plate` (`plate`),
  INDEX `idx_ct_history_owner` (`owner_identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 3) Logs police (scan + amendes)
CREATE TABLE IF NOT EXISTS `ct_police_actions` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `officer_identifier` VARCHAR(80) NOT NULL,
  `officer_job` VARCHAR(32) NULL,
  `plate` VARCHAR(32) NOT NULL,
  `owner_identifier` VARCHAR(80) NULL,
  `action` VARCHAR(32) NOT NULL,
  `scan_type` VARCHAR(32) NULL,
  `fine_amount` INT NULL,
  `days_overdue` INT NULL,
  `vehicle_class` INT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_ct_police_plate` (`plate`),
  INDEX `idx_ct_police_officer` (`officer_identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 4) Amendes stockées (si proprio offline)
CREATE TABLE IF NOT EXISTS `ct_fines` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `owner_identifier` VARCHAR(80) NOT NULL,
  `plate` VARCHAR(32) NOT NULL,
  `fine_amount` INT NOT NULL,
  `reason` VARCHAR(64) NOT NULL DEFAULT 'CT expiré',
  `status` VARCHAR(16) NOT NULL DEFAULT 'unpaid',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `paid_at` DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  INDEX `idx_ct_fines_owner` (`owner_identifier`),
  INDEX `idx_ct_fines_plate` (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
