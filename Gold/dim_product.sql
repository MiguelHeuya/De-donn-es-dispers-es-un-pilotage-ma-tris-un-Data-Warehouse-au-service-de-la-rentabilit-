-- ============================================================================
-- NOM DU SCRIPT : Création de la Dimension Produit (dim_product)
-- COUCHE        : Gold (Zone Décisionnelle / Data Warehouse)
-- LOGIQUE SCD   : SCD Type 1 (Mise à jour dynamique via Vue)
-- OBJECTIF      : Consolider, nettoyer et exposer le catalogue produits pour Power BI
-- ============================================================================

-- 1. NETTOYAGE DE L'INFRASTRUCTURE
-- Supprime la vue existante pour éviter les erreurs de conflit de structure ou de types lors de la recréation.
DROP VIEW IF EXISTS "Gold"."dim_product" CASCADE;

-- 2. MODÉLISATION DE LA DIMENSION GOLD
-- Création de la vue décisionnelle qui servira de source unique de vérité pour les rapports.
CREATE VIEW "Gold"."dim_product" AS (
SELECT
    -- CLÉ ARTIFICIELLE (Surrogate Key) : 
    -- Génère un identifiant numérique unique et séquentiel (1, 2, 3...) à la volée.
    -- Indispensable pour créer des relations "1 à Plusieurs" sines et performantes dans le modèle en étoile de Power BI.
    ROW_NUMBER() OVER() AS product_key,
    
    -- IDENTIFIANTS TECHNIQUES ET MÉTIERS : 
    -- Renommer les colonnes sources pour masquer la complexité technique et adopter une nomenclature claire.
    a.prd_id AS product_id,       -- Clé primaire technique issue du système source
    a.prd_key AS product_number,   -- Référence / Code SKU métier du produit
    a.prd_nm AS product_name,     -- Libellé complet du produit
    a.cat_id AS categorie_id,     -- Clé étrangère de catégorisation (utile pour vérification ou jointures futures)   
    
    -- QUALITÉ DES DONNÉES (Data Cleansing via COALESCE) :
    -- Sécurisation du modèle. Si la jointure LEFT JOIN ne trouve pas de correspondance (valeur NULL),
    -- COALESCE remplace immédiatement le vide par la mention standardisée 'n/a' (Not Applicable).
    COALESCE(b.cat, 'n/a') AS category,                  -- Catégorie principale du produit
    COALESCE(b.subcat, 'n/a') AS sub_category,            -- Sous-catégorie du produit
    COALESCE(b.maintenance, 'n/a') AS maintenance,  -- Statut ou type de maintenance associé
    
    -- ATTRIBUTS FINANCIERS ET OPÉRATIONNELS :
    a.prd_cost AS cost,            -- Coût unitaire de production / d'achat
    a.prd_line AS product_line,    -- Gamme / Ligne de produit (ex: Standard, Premium, etc.)
    
    -- AXE TEMPOREL :
    a.prd_start_dt AS start_date   -- Date d'introduction ou de début de validité du produit
    
FROM "Silver"."prd_info" AS a

-- ENRICHISSEMENT DES DONNÉES (Data Enrichment) :
-- Utilisation d'un LEFT JOIN pour préserver l'intégralité du catalogue produit (table a),
-- même si certaines références n'ont pas encore de catégorie associée dans la table de correspondance (table b).
LEFT JOIN "Silver"."px_cat_g1v2" AS b
    ON b.id = a.cat_id
);