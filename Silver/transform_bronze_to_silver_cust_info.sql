-- =================================================================================================
-- PIPELINE DATA ENGINEERING : TRANSFORMATION BRONZE -> SILVER
-- CIBLE : "Silver"."cust_info"
-- DESCRIPTION : Nettoyage, standardisation et dédoublonnage des données clients brutes.
-- =================================================================================================

-- 1. Nettoyage de l'environnement (Idempotence)
-- Supprime l'ancienne table du schéma Silver si elle existe déjà pour repartir sur une base fraîche
-- et éviter les erreurs de duplication de table ou de modifications de structures (SCD Type 1).
DROP TABLE IF EXISTS "Silver"."cust_info" CASCADE;

-- 2. Création de la table Silver
-- Crée la nouvelle table propre de manière dynamique à partir du résultat de la requête CTE ci-dessous.
CREATE TABLE "Silver"."cust_info" AS 
WITH rownumber AS (
    -- CTE (Common Table Expression) : Permet d'isoler la logique de nettoyage et de préparer le dédoublonnage
    SELECT
        -- Identifiant unique du client (conservé brut pour les jointures)
        cst_id,
        
        -- STANDARDISATION DES FORMATS TEXTE (TRIM)
        -- Supprime les espaces superflus au début et à la fin des chaînes (fréquent dans les imports bruts/CSV)
        TRIM(BOTH ' ' FROM cst_key) AS cst_key,
        TRIM(BOTH ' ' FROM cst_firstname) AS cst_firstname,
        TRIM(BOTH ' ' FROM cst_lastname) AS cst_lastname,
        
        -- NORMALISATION DU STATUT MARITAL (MAPPING LOGIQUE)
        -- Transforme les codes obscurs de la source en valeurs explicites et gère les valeurs manquantes/inconnues
        CASE cst_marital_status
            WHEN 'M' THEN 'Married'
            WHEN 'S' THEN 'Single'
            ELSE 'n/a' -- Assure une intégrité des données sans laisser de chaînes vides ou de NULL instables
        END AS cst_marital_status,
        
        -- NORMALISATION DU GENRE (MAPPING LOGIQUE)
        -- Harmonise les données de genre pour faciliter les futures segmentations ou analyses de la couche Gold
        CASE cst_gndr
            WHEN 'M' THEN 'Male'
            WHEN 'F' THEN 'Female'
            ELSE 'n/a'
        END AS cst_gndr,
        
        -- Date de création (sélectionnée brute dans la CTE pour effectuer le tri chronologique)
        cst_create_date,
        
        -- STRATÉGIE DE DÉDOUBLONNAGE (WINDOW FUNCTION)
        -- Sépare les lignes par identifiant client (PARTITION BY) et les classe de la plus récente à la plus ancienne (ORDER BY DESC).
        -- Attribue un numéro unique (1, 2, 3...) à chaque version du même client. Le '1' sera toujours le profil le plus à jour.
        ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) AS rn
    FROM "Bronze"."cust_info"
)
-- 3. Sélection finale et chargement dans la destination
SELECT 
    cst_id,
    cst_key,
    cst_firstname,
    cst_lastname,
    cst_marital_status,
    cst_gndr,
    -- TRANSTYPAGE ET CONVERSION DE TYPE
    -- Force la colonne de date à adopter le type strict DATE de PostgreSQL (au lieu du VARCHAR de la couche Bronze)
    cst_create_date::DATE
FROM rownumber
-- FILTRE DE DÉDOUBLONNAGE
-- On ne conserve STRICTEMENT que la ligne '1' (la version la plus récente et valide de chaque client)
WHERE rn = 1 AND cst_id IS NOT NULL;