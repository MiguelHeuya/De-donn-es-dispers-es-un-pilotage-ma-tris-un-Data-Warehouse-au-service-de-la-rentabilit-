-- ==================================================================================================
-- PIPELINE : BRONZE -> SILVER
-- SCRIPT   : Nettoyage, Standardisation et Alignement des Ventes ("Silver"."sales_details")
-- OBJECTIF : Assurer la qualité des transactions (zéro négatif, zéro NULL, cohérence mathématique stricte)
-- ==================================================================================================

-- 1. NETTOYAGE DU SCHEMA (IDEMPOTENCE)
-- Supprime la table existante pour garantir un rafraîchissement complet à chaque exécution du script Python.
DROP TABLE IF EXISTS "Silver"."sales_details" CASCADE;

-- 2. TRANSFORMATION ET RE-MODELISATION
-- Crée la table Silver physique contenant les données nettoyées, utilisable pour les agrégations de la couche Gold.
CREATE TABLE "Silver"."sales_details" AS

-- --------------------------------------------------------------------------------------------------
-- ÉTAPE 1 (CTE) : Nettoyage initial, Isolation des dates et Application de la Valeur Absolue (VA)
-- --------------------------------------------------------------------------------------------------
WITH step1_abs AS (
    SELECT 
        -- Standardisation des clés d'identification (suppression des espaces et conversion des vides en NULL)
        NULLIF(TRIM(sls_ord_num), '') AS sls_ord_num,
        NULLIF(TRIM(sls_prd_key), '') AS sls_prd_key,
        NULLIF(TRIM(sls_cust_id), '') AS sls_cust_id,
        
        -- Mise en quarantaine temporaire des chaînes textuelles de dates pour traitement ultérieur
        NULLIF(TRIM(sls_order_dt), '') AS sls_order_dt_raw,
        NULLIF(TRIM(sls_ship_dt), '') AS sls_ship_dt_raw,
        NULLIF(TRIM(sls_due_dt), '') AS sls_due_dt_raw,
        
        -- TRAITEMENT DES ANOMALIES NUMÉRIQUES :
        -- Pour chaque indicateur, on supprime les espaces, convertit en NUMERIC, applique la Valeur Absolue (ABS)
        -- pour redresser les négatifs, et sécurise les NULLs/vides en les forçant temporairement à 0 via COALESCE.
        COALESCE(ABS(NULLIF(TRIM(sls_sales), '')::NUMERIC), 0) AS s_raw,
        COALESCE(ABS(NULLIF(TRIM(sls_quantity), '')::NUMERIC), 0) AS q_raw,
        COALESCE(ABS(NULLIF(TRIM(sls_price), '')::NUMERIC), 0) AS p_raw
    FROM "Bronze"."sales_details"
),

-- --------------------------------------------------------------------------------------------------
-- ÉTAPE 2 (CTE) : Neutralisation des Zéros et application des règles minimales métiers
-- --------------------------------------------------------------------------------------------------
step2_clean_defaults AS (
    SELECT 
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,
        sls_order_dt_raw,
        sls_ship_dt_raw,
        sls_due_dt_raw,
        s_raw,
        
        -- REGLE METIER MINIMALE : Pour éviter les divisions par zéro lors du calcul du prix unitaire
        -- et éliminer la valeur 0, toute quantité ou prix égal à 0 est redressé à la valeur minimale de 1.
        CASE WHEN q_raw = 0 THEN 1 ELSE q_raw END AS q_base,
        CASE WHEN p_raw = 0 THEN 1 ELSE p_raw END AS p_base
    FROM step1_abs
)

-- --------------------------------------------------------------------------------------------------
-- ÉTAPE 3 : Alignement final des métriques financières et typage des dates au format ISO
-- --------------------------------------------------------------------------------------------------
SELECT 
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,
    
    -- PARSAGE SECURISE DES DATES :
    -- Si la chaîne brute ne respecte pas strictement le format compact attendu de 8 caractères (YYYYMMDD),
    -- on applique un NULL de sécurité pour éviter de faire planter le composant TO_DATE.
    CASE
         WHEN LENGTH(sls_order_dt_raw) != 8 THEN NULL
         ELSE TO_DATE(sls_order_dt_raw, 'YYYYMMDD')
    END AS sls_order_dt,
    
    CASE
         WHEN LENGTH(sls_ship_dt_raw) != 8 THEN NULL
         ELSE TO_DATE(sls_ship_dt_raw, 'YYYYMMDD')
    END AS sls_ship_dt,
    
    CASE
         WHEN LENGTH(sls_due_dt_raw) != 8 THEN NULL
         ELSE TO_DATE(sls_due_dt_raw, 'YYYYMMDD')
    END AS sls_due_dt,
    
    -- GARANTIE DE COHERENCE ET RECALCUL (Sales = Quantity * Price) :
    -- Règle A : Si le montant des ventes d'origine était manquant ou égal à 0, on le calcule : Quantité * Prix.
    CASE 
        WHEN s_raw = 0 THEN (q_base * p_base)
        ELSE s_raw 
    END AS sls_sales,
    
    -- La quantité redressée à l'étape 2 (jamais nulle, jamais négative) devient notre référence fixe.
    q_base AS sls_quantity,
    
    -- Règle B : Si les ventes d'origine étaient nulles, on applique le prix de base unitaire.
    -- Règle C (Ajustement strict) : Si les ventes existaient, on recalcule dynamiquement le prix (Ventes / Quantité)
    -- pour s'assurer que l'équation mathématique soit 100% exacte, au centime près, sur chaque enregistrement.
    CASE 
        WHEN s_raw = 0 THEN p_base
        ELSE (s_raw / q_base)
    END AS sls_price

FROM step2_clean_defaults;