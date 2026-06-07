-- ==================================================================================================
-- PIPELINE : BRONZE -> SILVER
-- SCRIPT   : Chargement et Normalisation de la table de localisation ("Silver"."loc_a101")
-- OBJECTIF : Nettoyer les identifiants clients et standardiser les noms de pays (Data Quality)
-- ==================================================================================================

-- 1. NETTOYAGE DU SCHEMA (IDEMPOTENCE)
-- Supprime la table Silver si elle existe déjà pour éviter les conflits et permettre un Full Refresh clean
DROP TABLE IF EXISTS "Silver"."loc_a101"CASCADE;

-- 2. CREATION ET INSERTION DANS LA TABLE SILVER
CREATE TABLE "Silver"."loc_a101" AS (
    SELECT
        -- Suppression des tirets dans l'identifiant client
        REPLACE(cid, '-', '') AS cid,
        
        -- Normalisation de la colonne des pays
        CASE 
            -- Regroupement des synonymes pour les États-Unis
            WHEN UPPER(TRIM(cntry)) IN ('US', 'USA', 'UNITED STATES') THEN 'United States'
            
            -- Regroupement des synonymes pour l'Allemagne
            WHEN UPPER(TRIM(cntry)) IN ('DE', 'GERMANY') THEN 'Germany'
            
            -- Gestion des chaînes vides, des NULL et des espaces insécables (chr 160)
            WHEN cntry IS NULL 
                 OR TRIM(REPLACE(cntry, chr(160), '')) = '' THEN 'n/a'
            
            -- Pour les pays déjà propres (Australia, Canada, France, United Kingdom)
            ELSE TRIM(cntry)
        END AS cntry
    FROM "Bronze"."loc_a101"
);
