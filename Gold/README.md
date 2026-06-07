# 🥇 Couche GOLD — Zone Décisionnelle & Modèle en Étoile

La couche **Gold** représente la destination finale et la vitrine analytique de notre Data Warehouse (*Medallion Architecture*). Son rôle est de consommer les données nettoyées et standardisées de la couche **Silver** pour les structurer en un **modèle en étoile** (*Star Schema*). 

Cette zone est optimisée pour les performances d'agrégation, la modélisation sémantique et l'exposition directe vers des outils de Business Intelligence comme **Power BI**.

---

## 🎯 Objectifs Stratégiques & Techniques

* **Modélisation de Kimball :** Séparation stricte entre les axes d'analyse (tables de **Dimensions**) et les indicateurs quantitatifs mesurables (table de **Faits**).
* **Nomenclature Métier (Business-Ready) :** Masquage complet des préfixes techniques (`cst_`, `prd_`, `sls_`) au profit d'un aliasing clair et explicite en français/anglais pour les analystes métiers.
* **Génération de Clés Artificielles (*Surrogate Keys*) :** Utilisation de `ROW_NUMBER() OVER()` pour créer des clés numériques uniques et séquentielles, assurant des jointures stables et ultra-performantes.
* **Résilience Decisionnelle :** Utilisation intensive de la fonction `COALESCE()` pour interdire la propagation de valeurs `NULL` dans les rapports, remplacées par la mention standardisée `'n/a'`.

---

## 🔍 Zoom sur la Logique Métier & Modélisation des Vues

Pour garantir une agilité maximale et éliminer la redondance de stockage, la couche Gold est implémentée sous forme de **Vues SQL** dynamiques basées sur la logique du **SCD Type 1** (Source Unique de Vérité à jour).

### 👥 1. Dimension Clients (`dim_customer`)
Cette dimension unifie l'état civil, le profilage et la géographie des clients en effectuant une réconciliation multi-sources :
* **Unification du Genre (*Cross-Source Logic*) :** Application d'une règle de cascade métier complexe :
  1. Si le genre est valide dans la table principale `cust_info`, il est conservé.
  2. S'il est manquant (`'n/a'`), le script applique un *Fallback* automatique en allant chercher la valeur dans le profil secondaire `cust_az12`.
  3. Si l'information est absente des deux sources, elle est sécurisée avec la valeur `'n/a'`.
* **Raccordement Géographique :** Récupération dynamique du pays nettoyé (`cntry`) depuis `loc_a101` via un `LEFT JOIN`. Tout client sans correspondance géographique est automatiquement assigné à la région `'n/a'` via `COALESCE`.

### 📦 2. Dimension Produits (`dim_product`)
Cette dimension présente le catalogue de produits enrichi de ses métadonnées de classification :
* **Enrichissement Sémantique :** Jointure gauche (`LEFT JOIN`) entre la table `prd_info` et le référentiel des catégories `px_cat_g1v2` sur la clé de catégorie reconstruite (`cat_id = id`).
* **Sécurisation des Hiérarchies :** Application de `COALESCE` sur les colonnes de regroupement (`cat`, `subcat`, `maintenance`) pour garantir la parfaite intégrité des axes de drill-down dans Power BI.

### 💰 3. Table de Faits des Ventes (`fact_sales`)
C'est le cœur transactionnel et le moteur de calcul du chiffre d'affaires du modèle en étoile.
* **Raccordement des Clés Artificielles :** La table de faits se connecte aux dimensions `dim_product` et `dim_customer` en utilisant des jointures gauches sur les clés métiers naturelles (`sls_prd_key = product_number` et `sls_cust_id = customer_key`). Elle expose ainsi les clés artificielles (`product_key`, `customer_key`) indispensables aux relations 1-à-plusieurs.
* **Centralisation des Métriques :** Exposition des axes temporels (`order_date`, `ship_date`, `due_date`) et alignement des indicateurs financiers clés : montant du chiffre d'affaires (`sale_amount`), volumes vendus (`quantity`) et prix unitaire facturé (`price`).

---

## 📁 Architecture des Dossiers

```text
📦 Projet 2 data warehouse
 ┣ 📂 Bronze
 ┣ 📂 Silver
 ┣ 📂 Gold
 ┃ ┣ 📜 Load.py               <-- Orchestrateur Python de la couche Gold (Moteur SQLAlchemy)
 ┃ ┣ 📜 dim_customer.sql      <-- Vue SQL de la dimension Clients (Unification & Fallback)
 ┃ ┣ 📜 dim_product.sql       <-- Vue SQL de la dimension Produits (Enrichissement Catégories)
 ┃ ┗ 📜 fact_sales.sql        <-- Vue SQL de la table de faits centrale des Ventes
 ┗ 📜 Orchestrateur.py