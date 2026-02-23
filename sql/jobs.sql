-- ============================================================
-- ducratif_ct - JOB controletech - Installation SQL
-- ============================================================

-- 1) Ajouter le job dans jobs
INSERT IGNORE INTO jobs (name, label) VALUES
('controletech', 'Contrôle Technique');

-- 2) Ajouter 1 grade dans job_grades
INSERT IGNORE INTO job_grades (job_name, grade, name, label, salary) VALUES
('controletech', 0, 'employe', 'Employé CT', 0);