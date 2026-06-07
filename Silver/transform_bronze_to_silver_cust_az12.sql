

DROP TABLE IF EXISTS "Silver"."cust_az12" CASCADE;

CREATE TABLE "Silver"."cust_az12" AS
(SELECT
    -- 1. Nettoyage de l'identifiant client
    CASE
         WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid FROM 4)
         ELSE cid
    END AS cid,
    
    -- 2. CONVERSION SECURISEE DE LA DATE (Longueur 10 attendue, ex: 'YYYY-MM-DD')
    CASE
         -- Si la date est NULL, vide ou n'a pas exactement 10 caractères
         WHEN bdate IS NULL OR TRIM(bdate) = '' OR LENGTH(TRIM(bdate)) != 10 THEN '1900-01-01'::DATE
         
         -- Sinon, la valeur est jugée conforme et on la convertit en DATE
         ELSE TRIM(bdate)::DATE
    END AS bdate,
    
    -- 3. Standardisation du genre
    CASE
         WHEN UPPER(TRIM(gen)) LIKE 'F%' THEN 'Female'
		 WHEN UPPER(TRIM(gen)) LIKE 'M%' THEN 'Male'
         ELSE 'n/a'
    END AS gen
FROM "Bronze"."cust_az12");