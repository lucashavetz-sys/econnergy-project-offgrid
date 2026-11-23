CREATE DATABASE IF NOT EXISTS scada CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE scada;

CREATE TABLE IF NOT EXISTS measurements_1s (
  ts DATETIME(3) NOT NULL,
  grid_u  FLOAT NULL, grid_i  FLOAT NULL, grid_p  FLOAT NULL,
  pv_u    FLOAT NULL, pv_i    FLOAT NULL, pv_p    FLOAT NULL,
  gen_u   FLOAT NULL, gen_i   FLOAT NULL, gen_p   FLOAT NULL,
  batt_soc FLOAT NULL, batt_u FLOAT NULL, batt_i FLOAT NULL, batt_p FLOAT NULL,
  norm_u  FLOAT NULL, norm_i  FLOAT NULL, norm_p  FLOAT NULL,
  crit_u  FLOAT NULL, crit_i  FLOAT NULL, crit_p  FLOAT NULL,
  PRIMARY KEY (ts),
  INDEX idx_ts (ts)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS scada_latest (
  id TINYINT NOT NULL PRIMARY KEY,
  ts DATETIME(3) NOT NULL,
  grid_u  FLOAT NULL, grid_i  FLOAT NULL, grid_p  FLOAT NULL,
  pv_u    FLOAT NULL, pv_i    FLOAT NULL, pv_p    FLOAT NULL,
  gen_u   FLOAT NULL, gen_i   FLOAT NULL, gen_p   FLOAT NULL,
  batt_soc FLOAT NULL, batt_u FLOAT NULL, batt_i FLOAT NULL, batt_p FLOAT NULL,
  norm_u  FLOAT NULL, norm_i  FLOAT NULL, norm_p  FLOAT NULL,
  crit_u  FLOAT NULL, crit_i  FLOAT NULL, crit_p  FLOAT NULL
) ENGINE=InnoDB;

INSERT IGNORE INTO scada_latest (id, ts) VALUES (1, NOW(3));

CREATE TABLE IF NOT EXISTS counters_daily (
  day DATE NOT NULL PRIMARY KEY,
  ac_load_wh DOUBLE NOT NULL DEFAULT 0,
  ac_in_wh DOUBLE NOT NULL DEFAULT 0,
  solar_wh DOUBLE NOT NULL DEFAULT 0,
  ac_feedback_wh DOUBLE NOT NULL DEFAULT 0,
  total_runtime_s BIGINT NOT NULL DEFAULT 0,
  gen_runtime_s BIGINT NOT NULL DEFAULT 0,
  updated_at DATETIME(3) NOT NULL
) ENGINE=InnoDB;

SELECT *
FROM measurements_1s
ORDER BY ts DESC
LIMIT 120;

SELECT *
FROM (
    SELECT *
    FROM measurements_1s
    ORDER BY ts DESC
    LIMIT 120
) AS last
ORDER BY ts ASC;

SELECT ts, pv_p, grid_p, batt_p, batt_soc
FROM measurements_1s
ORDER BY ts DESC
LIMIT 120;

SELECT
  COUNT(*) AS nb_points,
  MIN(ts) AS start_time,
  MAX(ts) AS end_time
FROM measurements_1s;

SELECT
  TIMESTAMPDIFF(SECOND, MIN(ts), MAX(ts)) AS duration_s,
  COUNT(*) AS rows
FROM measurements_1s;


SELECT *
FROM counters_daily
ORDER BY day DESC;



use scada;
-- 1) sauvegarde l'ancienne
RENAME TABLE scada_settings TO scada_settings_old;

-- 2) nouvelle table "log"
CREATE TABLE scada_settings (
  id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,

  min_soc_pct DOUBLE NOT NULL,
  critical_soc_pct DOUBLE NOT NULL,
  gen_start_delay_s INT NOT NULL,
  grid_enabled TINYINT NOT NULL,
  gen_enabled TINYINT NOT NULL,

  apply_pending TINYINT NOT NULL DEFAULT 1,   -- 1 pending, 2 claimed, 0 done
  last_apply_ok TINYINT NULL,
  last_apply_msg VARCHAR(255) NULL,
  updated_at DATETIME(3) NOT NULL,
  applied_at DATETIME(3) NULL,

  KEY idx_pending (apply_pending, id),
  KEY idx_updated (updated_at)
);

-- 3) copie l'ancien row (si tu avais id=1)
INSERT INTO scada_settings
(min_soc_pct, critical_soc_pct, gen_start_delay_s, grid_enabled, gen_enabled,
 apply_pending, last_apply_ok, last_apply_msg, updated_at, applied_at)
SELECT
  min_soc_pct, critical_soc_pct, gen_start_delay_s, grid_enabled, gen_enabled,
  apply_pending, last_apply_ok, last_apply_msg,
  COALESCE(updated_at, NOW(3)),
  applied_at
FROM scada_settings_old
ORDER BY id DESC
LIMIT 1;

CREATE TABLE IF NOT EXISTS scada_status_1s (
  ts DATETIME(3) NOT NULL PRIMARY KEY,

  inv_l1_1_state SMALLINT NULL,
  inv_l1_1_fault_code INT NULL,
  inv_l1_2_state SMALLINT NULL,
  inv_l1_2_fault_code INT NULL,

  inv_l2_1_state SMALLINT NULL,
  inv_l2_1_fault_code INT NULL,
  inv_l2_2_state SMALLINT NULL,
  inv_l2_2_fault_code INT NULL,

  inv_l3_1_state SMALLINT NULL,
  inv_l3_1_fault_code INT NULL,
  inv_l3_2_state SMALLINT NULL,
  inv_l3_2_fault_code INT NULL,

  gen_running TINYINT NULL,
  grid_available TINYINT NULL
);

CREATE INDEX idx_scada_status_1s_ts ON scada_status_1s (ts);

CREATE TABLE IF NOT EXISTS scada_status_latest (
  id TINYINT NOT NULL PRIMARY KEY,
  ts DATETIME(3) NULL,

  inv_l1_1_state SMALLINT NULL,
  inv_l1_1_fault_code INT NULL,
  inv_l1_2_state SMALLINT NULL,
  inv_l1_2_fault_code INT NULL,

  inv_l2_1_state SMALLINT NULL,
  inv_l2_1_fault_code INT NULL,
  inv_l2_2_state SMALLINT NULL,
  inv_l2_2_fault_code INT NULL,

  inv_l3_1_state SMALLINT NULL,
  inv_l3_1_fault_code INT NULL,
  inv_l3_2_state SMALLINT NULL,
  inv_l3_2_fault_code INT NULL,

  gen_running TINYINT NULL,
  grid_available TINYINT NULL
);

INSERT INTO scada_status_latest (id) VALUES (1)
ON DUPLICATE KEY UPDATE id=id;


CREATE TABLE IF NOT EXISTS scada_alarms (
  id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  plc_slot TINYINT NOT NULL,
  counter BIGINT NOT NULL DEFAULT 0,

  ts DATETIME(3) NOT NULL,
  severity TINYINT NOT NULL,        -- 0 info, 1 warn, 2 crit
  source VARCHAR(64) NOT NULL,
  message VARCHAR(255) NOT NULL,
  fault_code INT NOT NULL DEFAULT 0,

  active TINYINT NOT NULL DEFAULT 1,
  acked TINYINT NOT NULL DEFAULT 0,
  acked_at DATETIME(3) NULL,
  cleared_at DATETIME(3) NULL,

  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

  KEY idx_ts (ts),
  KEY idx_active (active),
  KEY idx_sev (severity),
  KEY idx_slot (plc_slot)
);

CREATE TABLE IF NOT EXISTS scada_alarm_cmd (
  id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  plc_slot TINYINT NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

  apply_pending TINYINT NOT NULL DEFAULT 1,  -- 1 pending, 2 claimed, 0 done
  applied_at DATETIME(3) NULL,
  last_apply_ok TINYINT NULL,
  last_apply_msg VARCHAR(255) NULL
);


