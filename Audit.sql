-- Création du schéma d'audit s'il n'existe pas encore
CREATE SCHEMA IF NOT EXISTS "Audit";

-- Création de la table de logs ultra-détaillée
CREATE TABLE IF NOT EXISTS "Audit"."pipeline_logs" (
    log_id SERIAL PRIMARY KEY,
    -- 1. INFORMATIONS SUR L'ENVIRONNEMENT ET LE PIPELINE
    pipeline_name VARCHAR(100) NOT NULL,       -- Nom du projet global (ex: 'Sales_Intelligence_Pipeline')
    script_name VARCHAR(100) NOT NULL,         -- Fichier exact qui a tourné (ex: 'stg_loc_a101.sql')
    source_layer VARCHAR(50) NOT NULL,         -- Couche de départ (ex: 'Bronze')
    target_layer VARCHAR(50) NOT NULL,         -- Couche d'arrivée (ex: 'Silver')
    target_table VARCHAR(100) NOT NULL,        -- Table finale modifiée (ex: 'loc_a101')
    load_type VARCHAR(20) NOT NULL,            -- Stratégie : 'FULL REFRESH' ou 'INCREMENTAL'
    
    -- 2. METRIQUES TEMPORELLES (Pour analyser la performance dans PowerBI)
    execution_start_time TIMESTAMP NOT NULL,   -- Date/Heure précise du début du script
    execution_end_time TIMESTAMP,              -- Date/Heure précise de la fin du script
    duration_seconds NUMERIC(10, 2),           -- Calcul automatique de la durée en secondes
    
    -- 3. METRIQUES DE DONNÉES (Pour les graphiques de volumétrie)
    rows_inserted INT DEFAULT 0,               -- Nombre de nouvelles lignes créées
    rows_updated INT DEFAULT 0,                -- Nombre de lignes mises à jour (si incrémental)
    rows_deleted INT DEFAULT 0,                -- Nombre de lignes supprimées (si purge)
    
    -- 4. STATUT ET DIAGNOSTIC
    status VARCHAR(20) NOT NULL,               -- État : 'SUCCESS', 'FAILED', 'RUNNING'
    error_message TEXT,                        -- Le message d'erreur SQL complet si crash
    executed_by VARCHAR(100) NOT NULL          -- Qui a lancé le script ? (ex: 'python_job', 'airflow', 'manual_admin')
);
