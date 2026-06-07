-- ============================================================================
-- NOM DU SCRIPT : Création de la Dimension Client (dim_customer)
-- COUCHE        : Gold (Zone Décisionnelle / Data Warehouse)
-- LOGIQUE SCD   : SCD Type 1 (Écrasement dynamique des données)
-- OBJECTIF      : Nettoyer, standardiser et exposer les données clients pour Power BI
-- ============================================================================

-- 1. NETTOYAGE : On supprime l'ancienne structure physique (si elle existe) pour éviter les conflits
DROP VIEW IF EXISTS "Gold"."dim_customer" CASCADE;

-- 2. MODÉLISATION : On crée la vue décisionnelle Gold
CREATE OR REPLACE VIEW "Gold"."dim_customer" AS
SELECT
    -- CLÉ ARTIFICIELLE : Génère un ID numérique unique (1, 2, 3...) à la volée. 
    -- Utile pour créer des relations optimales et performantes (clés primaires) dans Power BI.
    ROW_NUMBER() OVER() AS customer_id, 
    
    -- IDENTIFIANTS : Mapping des clés d'origine. On renomme pour que ce soit explicite pour le métier.
    a.cst_id AS customer_key,       -- Clé technique interne de la source
    a.cst_key AS customer_number,   -- Numéro de compte / Identifiant business du client
    
    -- ÉTAT CIVIL : Standardisation des formats de noms (Aliasing clair)
    a.cst_firstname AS first_name,
    a.cst_lastname AS last_name,
    
    -- LOGIQUE MÉTIER GENDER : Remplacement des données manquantes ou incohérentes.
    -- On croise la table principale (a) avec la table de secours (b) pour récupérer le genre.
    CASE 
         WHEN a.cst_gndr != 'n/a' THEN a.cst_gndr -- Règle 1 : Si le genre est valide en source, on le garde
         WHEN a.cst_gndr = 'n/a' AND b.gen IS NOT NULL THEN b.gen -- Règle 2 : S'il est manquant ('n/a'), on cherche dans la table secondaire
         WHEN a.cst_gndr = 'n/a' AND b.gen IS NULL THEN 'n/a' -- Règle 3 : Si introuvable partout, on sécurise avec une valeur par défaut 'n/a'
    END AS gender,
    
    a.cst_marital_status AS marital_status, -- Statut marital (Célibataire, Marié, etc.)
    
    -- QUALITÉ DES DONNÉES PAYS : Traitement des valeurs manquantes (NULL)
    -- Si la jointure ne trouve pas de pays pour ce client, COALESCE remplace automatiquement le NULL par 'n/a'
    COALESCE(c.cntry, 'n/a') AS country,
    
    -- DATES : Alignement des axes temporels du client
    b.bdate AS birth_date,           -- Date de naissance
    a.cst_create_date AS create_date -- Date de création du profil dans le système
    
FROM "Silver"."cust_info" AS a

-- JOINTURE 1 : Récupération des informations secondaires (Date de naissance, Genre de secours)
LEFT JOIN "Silver"."cust_az12" AS b
    ON b.cid = a.cst_key

-- JOINTURE 2 : Récupération de la localisation géographique (Pays)
LEFT JOIN "Silver"."loc_a101" AS c
    ON c.cid = a.cst_key;