-- Schéma gs_jobs (créé automatiquement au démarrage, fichier fourni pour install/rollback manuel).
-- Rollback : DROP TABLE gs_job_audit, gs_bills, gs_societies, gs_job_members;  (après backup !)

CREATE TABLE IF NOT EXISTS `gs_job_members` (
  `citizenid` VARCHAR(50) NOT NULL,
  `job` VARCHAR(50) NOT NULL,
  `grade` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `name` VARCHAR(100) NOT NULL DEFAULT '',
  `hired_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`, `job`),
  KEY `idx_job` (`job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gs_societies` (
  `job` VARCHAR(50) NOT NULL,
  `money` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gs_bills` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `job` VARCHAR(50) NOT NULL,
  `amount` INT UNSIGNED NOT NULL,
  `reason` VARCHAR(100) NOT NULL DEFAULT '',
  `issuer_citizenid` VARCHAR(50) NOT NULL,
  `issuer_name` VARCHAR(100) NOT NULL DEFAULT '',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_citizen` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gs_job_audit` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `action` VARCHAR(32) NOT NULL,
  `job` VARCHAR(50) NULL,
  `actor` VARCHAR(50) NULL,
  `target` VARCHAR(50) NULL,
  `amount` INT NULL,
  `details` VARCHAR(255) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_job_date` (`job`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
