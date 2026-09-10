
-- Il n'est pas utile de conserver l'historique pour cust_info
DROP TABLE IF EXISTS silver.crm_cust_info;
CREATE TABLE silver.crm_cust_info AS
(WITH cust_ranked AS (
    SELECT
        cst_id,
        cst_key,
        TRIM(cst_firstname) AS cst_firstname,
        TRIM(cst_lastname) AS cst_lastname,
        CASE UPPER(TRIM(cst_marital_status))
            WHEN 'M' THEN 'Married'
            WHEN 'S' THEN 'Single'
            ELSE 'n/a'
        END AS cst_marital_status,
        CASE UPPER(TRIM(cst_gndr))
            WHEN 'M' THEN 'Male'
            WHEN 'F' THEN 'Female'
            ELSE 'n/a'
        END AS cst_gndr,
        cst_create_date::date,
        -- Numérote les doublons de chaque client du plus récent au plus ancien
        ROW_NUMBER() OVER (
            PARTITION BY cst_id 
            ORDER BY cst_create_date::date DESC
        ) AS rn
    FROM bronze.crm_cust_info
    WHERE cst_id IS NOT NULL
)
SELECT
    cst_id::text,
    cst_key,
    cst_firstname,
    cst_lastname,
    cst_marital_status,
    cst_gndr,
    cst_create_date
FROM cust_ranked
WHERE rn = 1);


-- On conserve l'historique dans la table prd_info
DROP TABLE IF EXISTS silver.crm_prd_info;
CREATE TABLE silver.crm_prd_info AS(
SELECT
	prd_id::text,
	prd_key,
	REPLACE(SUBSTRING(prd_key FROM 1 FOR 5), '-', '_') AS cat_id,
	prd_nm,
	prd_cost,
	CASE UPPER(TRIM(prd_line))
		WHEN 'M' THEN 'Mountain'
		WHEN 'T' THEN 'Touring'
		WHEN 'R' THEN 'Road'
		WHEN 'S' THEN 'Other Sales'
		ELSE 'n/a'
	END AS prd_line,
	prd_start_dt,
	LEAD(prd_start_dt) OVER(PARTITION BY prd_key) AS prd_end_dt
FROM bronze.crm_prd_info
);




DROP TABLE IF EXISTS silver.crm_sales_details;
CREATE TABLE silver.crm_sales_details AS(
SELECT
	sls_ord_num,
	sls_prd_key,
	sls_cust_id::text,
	CASE
		WHEN sls_order_dt = 0 OR LENGTH(sls_order_dt::text) != 8 THEN NULL
		ELSE TO_DATE(sls_order_dt::text, 'YYYYMMDD')
	END AS sls_order_dt,
	CASE
		WHEN sls_ship_dt = 0 OR LENGTH(sls_ship_dt::text) != 8 THEN NULL
		ELSE TO_DATE(sls_ship_dt::text, 'YYYYMMDD')
	END AS sls_ship_dt,
	CASE
		WHEN sls_due_dt = 0 OR LENGTH(sls_due_dt::text) != 8 THEN NULL
		ELSE TO_DATE(sls_due_dt::text, 'YYYYMMDD')
	END AS sls_due_dt,
	ABS(sls_quantity::numeric) AS sls_quantity,
	CASE
		WHEN sls_sales::numeric = 0 THEN sls_price::numeric
		ELSE ABS(sls_sales::numeric) / ABS(sls_quantity::numeric)
	END AS sls_price,
	CASE
		WHEN sls_sales::numeric = 0 THEN ABS(sls_quantity::numeric) * ABS(sls_price::numeric)
		ELSE ABS(sls_sales::numeric)
	END AS sls_sales
FROM bronze.crm_sales_details
);

DROP TABLE IF EXISTS silver.erp_cust_az12;
CREATE TABLE silver.erp_cust_az12 AS(
SELECT
	"CID" AS cid,
	CASE 
		WHEN "CID" LIKE 'NAS%' THEN SUBSTRING("CID" FROM 4 FOR LENGTH("CID"))
		ELSE "CID"
	END AS cust_key,
	"BDATE"::date AS bdate,
	CASE 
		WHEN UPPER(TRIM("GEN")) = 'M' OR UPPER(TRIM("GEN")) = 'MALE' THEN 'Male'
		WHEN UPPER(TRIM("GEN")) = 'F' OR UPPER(TRIM("GEN")) = 'FEMALE' THEN 'Female'
		ELSE 'n/a'
	END AS gen
FROM bronze.erp_cust_az12);

DROP TABLE IF EXISTS silver.erp_loc_a101;
CREATE TABLE silver.erp_loc_a101 AS(
SELECT
	"CID" AS cid,
	REPLACE("CID", '-', '') AS cust_key,
	TRIM("CNTRY") AS cntry
FROM bronze.erp_loc_a101
);


DROP TABLE IF EXISTS silver.erp_px_cat_g1v2;
CREATE TABLE silver.erp_px_cat_g1v2 AS
(SELECT
	"ID" AS id,
	TRIM("CAT") AS cat,
	TRIM("SUBCAT") AS subcat,
	TRIM("MAINTENANCE") AS maintenance
FROM bronze.erp_px_cat_g1v2
);


