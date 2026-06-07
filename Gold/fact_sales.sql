
-- ============================================================================
-- NOM DU PROGRAMME : Création de la Table Centrale des Ventes (fact_sales)
-- OBJECTIF         : Rassembler toutes les transactions commerciales (ventes)
--                    en les connectant automatiquement aux fiches des produits
--                    et des clients pour permettre l'analyse des résultats.
-- ============================================================================

-- ÉTAPE 1 : NETTOYAGE
-- Si une ancienne version de ce tableau de bord existe, on la supprime pour mettre la nouvelle à jour.
DROP VIEW IF EXISTS "Gold"."fact_sales" CASCADE;

-- ÉTAPE 2 : CRÉATION DU TABLEAU CENTRAL DES VENTES
CREATE VIEW "Gold"."fact_sales" AS (
SELECT
    -- 1. IDENTIFIANT DE LA VENTE
    a.sls_ord_num AS sale_id,       -- Le numéro unique du bon de commande
    
    -- 2. LES PASSERELLES (Clés de liaison vers les autres fichiers)
    -- Ces codes permettent d'associer chaque vente à sa fiche produit ou sa fiche client.
    b.product_key AS product_key,   -- Lien direct vers la fiche du produit vendu (Nom, catégorie, coût...)
    c.customer_id AS customer_key,   -- Lien direct vers la fiche du client qui a acheté (Nom, ville, pays...)
    
    -- 3. LE CALENDRIER (Les dates clés de l'opération)
    a.sls_order_dt AS order_date,   -- La date à laquelle le client a passé la commande
    a.sls_ship_dt AS ship_date,     -- La date à laquelle le colis a été expédié
    a.sls_due_dt AS due_date,       -- La date limite attendue pour le paiement ou la livraison
    
    -- 4. LES CHIFFRES CLÉS (Les indicateurs financiers pour le calcul de la marge)
    a.sls_sales AS sale_amount,     -- Le montant total généré par cette vente (Chiffre d'Affaires)
    a.sls_quantity AS quantity,     -- Le nombre de produits achetés
    a.sls_price AS price            -- Le prix unitaire facturé au client

-- ÉTAPE 3 : RACCORDEMENT DES FICHIERS (Les Jointures)
FROM "Silver"."sales_details" a

-- Raccordement A : On va chercher automatiquement les informations du produit concerné
LEFT JOIN "Gold"."dim_product" b
    ON a.sls_prd_key = b.product_number

-- Raccordement B : On va chercher automatiquement les informations du client concerné
LEFT JOIN "Gold"."dim_customer" c -- Note : Assure-toi que ton schéma s'appelle bien "Gold" ou "Silver" selon ton organisation
    ON a.sls_cust_id = c.customer_key
);
