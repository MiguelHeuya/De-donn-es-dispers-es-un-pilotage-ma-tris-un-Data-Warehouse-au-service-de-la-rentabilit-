-- ==================================================================================================
-- PIPELINE : BRONZE -> SILVER
-- SCRIPT   : Nettoyage et Historisation des Produits ("Silver"."prd_info")
-- OBJECTIF : Purger les anomalies, typer les données brutes et générer l'historique des prix (SCD Type 2)
-- ==================================================================================================

-- 1. NETTOYAGE DU SCHEMA : Approche Idempotente
-- Supprime l'ancienne table si elle existe pour permettre au script Python de recréer une table fraîche à chaque exécution.
DROP TABLE IF EXISTS "Silver"."prd_info" CASCADE;

-- 2. TRANSFORMATION ET CHARGEMENT
-- Crée la nouvelle table Silver physique à partir des données nettoyées de la couche Bronze.
CREATE TABLE "Silver"."prd_info" AS (
	    SELECT
		*
		FROM (SELECT 
	        -- Clé technique conservée en l'état
	        prd_id,
	        
	        -- TRONCATURE : Supprime les 6 premiers caractères (ex: 'PROD_ID_123' devient '123')
			REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
	        SUBSTRING(prd_key FROM 7) AS prd_key,
	        
	        -- Nom du produit conservé pour la couche Silver
	        prd_nm,
	        -- GESTION DU COÛT (DATA QUALITY CONSTRAINT) :
	        -- Évite les plantages sur chaîne vide, corrige les aberrations (coûts négatifs) et remplace les NULLs par 0.
	        CASE
	             WHEN NULLIF(TRIM(prd_cost), '')::NUMERIC < 0 THEN 0   -- Si le coût est négatif, redressement à 0
	             WHEN NULLIF(TRIM(prd_cost), '')::NUMERIC = 0 THEN 0   -- Si le coût est égal à 0, reste à 0
	             WHEN NULLIF(TRIM(prd_cost), '')::NUMERIC IS NULL THEN 0 -- Si le coût est manquant/vide, valeur par défaut à 0
	             ELSE NULLIF(TRIM(prd_cost), '')::NUMERIC              -- Sinon, on garde le coût numérique propre
	        END AS prd_cost,
	        -- NORMALISATION DES CATEGORIES : 
	        -- Nettoie les espaces, force la majuscule (UPPER) et traduit les codes métiers en libellés explicites.
	        CASE UPPER(TRIM(prd_line))
	             WHEN 'R' THEN 'Road'
	             WHEN 'S' THEN 'Other Sales'
	             WHEN 'M' THEN 'Mountain'
	             WHEN 'T' THEN 'Touring'
	             ELSE 'n/a' -- Gestion des valeurs inconnues ou manquantes
	        END AS prd_line,
	        
	        -- TYPAGE : Conversion explicite de la date de début du format texte (Bronze) vers le format DATE (Silver)
	        prd_start_dt::DATE AS prd_start_dt,
	        
	        -- HISTORISATION (SCD TYPE 2 via Window Function) :
	        -- Détermine la date de fin de validité du produit en allant chercher la date de début de la version suivante.
			LEAD((NULLIF(prd_start_dt, '')::DATE) + 1, 1, '9999-12-31'::DATE) OVER(
			    PARTITION BY prd_key       -- Isole le calcul par produit (clé métier)
			    ORDER BY prd_start_dt ASC   -- Trie chronologiquement pour identifier précisément la version "suivante"
			) AS prd_end_dt -- Si c'est la version active (dernière ligne), applique la date par défaut '9999-12-31'
	    FROM 
	    "Bronze"."prd_info"
		)
		WHERE prd_end_dt = '9999-12-31');

SELECT
*
FROM "Silver"."prd_info"