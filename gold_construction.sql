
DROP TABLE IF EXISTS gold.dim_customers;
CREATE TABLE gold.dim_customers AS(
	WITH A AS(
		SELECT
			a.cst_id,
			a.cst_key,
			a.cst_firstname,
			a.cst_lastname,
			a.cst_marital_status,
			a.cst_gndr,
			a.cst_create_date,
			b.bdate,
			b.gen,
			c.cntry
		FROM silver.crm_cust_info AS a
		LEFT JOIN silver.erp_cust_az12 AS b
			ON a.cst_key = b.cust_key
		LEFT JOIN silver.erp_loc_a101 AS c
			ON a.cst_key = c.cust_key
	)
	SELECT
		(ROW_NUMBER() OVER())::text AS customer_id,
		cst_id AS customer_key,
		cst_key AS customer_number,
		cst_firstname AS customer_first_name,
		cst_lastname AS customer_last_name,
		cst_marital_status AS customer_marital_status,
		cst_gndr AS customer_gender,
		CASE 
			WHEN cntry IS NULL THEN 'n/a'
			ELSE cntry
		END AS customer_country,
		bdate AS customer_birth_date,
		cst_create_date AS customer_create_date
	FROM A);


DROP TABLE IF EXISTS gold.dim_products;
CREATE TABLE gold.dim_products AS(
	WITH A AS
		(SELECT
			a.prd_id,
			a.prd_key,
			a.cat_id,
			a.prd_nm,
			a.prd_cost,
			a.prd_line,
			a.prd_start_dt,
			a.prd_end_dt,
			b.subcat,
			b.maintenance
		FROM silver.crm_prd_info AS a
		LEFT JOIN silver.erp_px_cat_g1v2 AS b
			ON a.cat_id = b.id)
	SELECT
		(ROW_NUMBER() OVER())::text AS product_id,
		prd_id AS product_key,
		prd_key AS product_number,
		cat_id AS category_id,
		prd_nm AS product_name,
		COALESCE(subcat, 'n/a') AS subcategorie_name,
		COALESCE(maintenance, 'n/a') AS maintenance_type,
		prd_line AS product_line,
		prd_cost AS product_cost,
		CASE
			WHEN prd_end_dt = '9999-12-31'::date THEN 'is_current'
			ELSE 'expired'
		END AS product_validity,
		prd_start_dt AS product_start_date,
		prd_end_dt AS product_end_date
	FROM A);


DROP TABLE IF EXISTS gold.fact_sales;
CREATE TABLE gold.fact_sales AS (
    SELECT
        a.sls_ord_num AS sale_id,
        b.customer_id AS customer_id,
        c.product_id AS product_id,
        a.sls_order_dt AS sale_order_date,
        a.sls_ship_dt AS sale_ship_date,
        a.sls_due_dt AS sale_due_date,
        a.sls_quantity AS sale_quantity,
        a.sls_price AS sale_price,
        a.sls_sales AS sale_amount
    FROM silver.crm_sales_details AS a
    LEFT JOIN gold.dim_customers AS b
        ON a.sls_cust_id = b.customer_key
    LEFT JOIN gold.dim_products AS c
        ON c.product_number = a.sls_prd_key
        AND a.sls_order_dt >= c.product_start_date
        AND a.sls_order_dt < c.product_end_date
);


-- ============================================================================
-- 1. INDEX SUR LES TABLES EN COUCHE SILVER (Accélération du chargement Gold)
-- ============================================================================

-- Optimisation des jointures d'ingestion vers Gold
CREATE INDEX IF NOT EXISTS idx_crm_cust_info_cst_key ON silver.crm_cust_info (cst_key);
CREATE INDEX IF NOT EXISTS idx_erp_cust_az12_cust_key ON silver.erp_cust_az12 (cid);
CREATE INDEX IF NOT EXISTS idx_erp_loc_a101_cust_key ON silver.erp_loc_a101 (cid);

CREATE INDEX IF NOT EXISTS idx_crm_prd_info_cat_id ON silver.crm_prd_info (prd_key);
CREATE INDEX IF NOT EXISTS idx_erp_px_cat_g1v2_id ON silver.erp_px_cat_g1v2 (id);

-- Optimisation de la jointure SCD2 et Lookups
CREATE INDEX IF NOT EXISTS idx_crm_sales_cust_prd ON silver.crm_sales_details (sls_cust_id, sls_prd_key, sls_order_dt);


-- ============================================================================
-- 2. INDEX SUR LA TABLE GOLD.DIM_CUSTOMERS
-- ============================================================================

-- Clé de substitution pour les jointures rapides avec fact_sales
CREATE INDEX IF NOT EXISTS idx_gold_dim_cust_id ON gold.dim_customers (customer_id);

-- Clé naturelle pour le lookup lors de l'ETL
CREATE INDEX IF NOT EXISTS idx_gold_dim_cust_key ON gold.dim_customers (customer_key);

-- Index d'analyse décisionnelle (recherches/filtres fréquents)
CREATE INDEX IF NOT EXISTS idx_gold_dim_cust_country ON gold.dim_customers (customer_country);


-- ============================================================================
-- 3. INDEX SUR LA TABLE GOLD.DIM_PRODUCTS
-- ============================================================================

-- Clé de substitution pour les jointures avec fact_sales
CREATE INDEX IF NOT EXISTS idx_gold_dim_prd_id ON gold.dim_products (product_id);

-- Index composite critique pour la jointure SCD Type 2
CREATE INDEX IF NOT EXISTS idx_gold_dim_prd_scd2 
ON gold.dim_products (product_number, product_start_date, product_end_date);

-- Index d'analyse décisionnelle
CREATE INDEX IF NOT EXISTS idx_gold_dim_prd_subcat ON gold.dim_products (subcategorie_name);


-- ============================================================================
-- 4. INDEX SUR LA TABLE GOLD.FACT_SALES
-- ============================================================================

-- Clés étrangères de jointure vers les dimensions (SANS Primary Key)
CREATE INDEX IF NOT EXISTS idx_gold_fact_sales_cust_id ON gold.fact_sales (customer_id);
CREATE INDEX IF NOT EXISTS idx_gold_fact_sales_prd_id ON gold.fact_sales (product_id);

-- Index sur les dates pour les agrégations temporelles (ventes mensuelles/annuelles)
CREATE INDEX IF NOT EXISTS idx_gold_fact_sales_order_dt ON gold.fact_sales (sale_order_date);

-- Index de recouvrement pour les analyses financières (évite de lire la table entière)
CREATE INDEX IF NOT EXISTS idx_gold_fact_sales_analytics 
ON gold.fact_sales (sale_order_date, product_id, sale_amount, sale_quantity);



SELECT
	*
FROM gold.dim_products

AC-HE-HL-U509-B

SELECT
	*
FROM gold.fact_sales
WHERE product_id IS NULL

SELECT
	*
FROM gold.dim_products

SELECT
	*
FROM silver.crm_sales_details

