# 🥈 Couche SILVER — Nettoyage, Standardisation & Règles Métiers

La couche **Silver** orchestre la transformation majeure de notre entrepôt de données (*Medallion Architecture*). Son rôle est de centraliser les tables brutes de la couche **Bronze**, d'en purger les anomalies, d'appliquer un typage strict et de redresser les erreurs mathématiques ou logiques. 

C'est l'assurance pour l'entreprise que chaque indicateur final (Chiffre d'Affaires, marge, volume) repose sur des données **100 % saines, auditées et conformes**.

---

## 🎯 Objectifs Stratégiques & Techniques

* **Idempotence Totale :** Tous les scripts intègrent une clause `DROP TABLE IF EXISTS` permettant des réécritures complètes et sécurisées lors des lancements automatisés (Full Refresh).
* **Zéro Soupe de NULLs :** Remplacement systématique des valeurs manquantes, vides ou instables par des valeurs par défaut standardisées (comme `'n/a'`, `0` ou `'1900-01-01'`).
* **Cohérence Mathématique :** Redressement des métriques financières et transactionnelles pour interdire toute aberration (quantités négatives, divisions par zéro).
* **Transtypage Strict (Type Casting) :** Conversion des colonnes textuelles brutes (`VARCHAR`/`TEXT`) issues de la couche Bronze vers leurs formats SQL natifs et optimisés (`DATE`, `NUMERIC`, `INTEGER`).

---

## 🔍 Zoom sur les Règles de Transformation par Fichier

### 👥 1. Référentiel Clients (`cust_info` & `cust_az12`)
Le nettoyage des profils clients s'appuie sur deux sources distinctes pour préparer l'unification décisionnelle :

* **Dédoublonnage par Fenêtrage (`cust_info`) :** Utilisation de la fonction analytique `ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC)` pour isoler les doublons et ne capturer strictement que le profil client le plus récent (`WHERE rn = 1`).
* **Nettoyage chirurgical des Identifiants (Clés Métiers) :** * Dans `cust_az12`, extraction et suppression du préfixe source `'NAS'` via une clause `CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid FROM 4)`.
  * Dans `loc_a101`, nettoyage des caractères parasites par la suppression des tirets (`REPLACE(cid, '-', '')`).
* **Normalisation des Attributs :**
  * Cartographie (Mapping) logique des statuts maritaux (`M` $\rightarrow$ `'Married'`, `S` $\rightarrow$ `'Single'`, sinon `'n/a'`).
  * Harmonisation des genres textuels disparates (`F%`, `M%`, `M`, `F`) en formats stricts et nettoyés (`'Female'`, `'Male'`, sinon `'n/a'`).
* **Sécurisation Temporelle :** Validation de la longueur des chaînes de caractères pour les dates de naissance (10 caractères attendus sous le format `YYYY-MM-DD`) avant conversion, avec application d'une date pivot de sécurité (`1900-01-01`::DATE) en cas de corruption ou de format non conforme.

### 📦 2. Catalogue Produits (`prd_info`)
* **Sécurisation du Coût (Data Quality Rule) :** Élimination des plantages sur chaîne vide grâce à `NULLIF`. Exclusion des coûts aberrants négatifs redressés automatiquement à `0`, et forçage en type monétaire exploitable (`::NUMERIC`).
* **Extraction de la Structure :** Scission de la clé brute `prd_key` pour isoler dynamiquement l'identifiant de catégorie et de sous-catégorie (`cat_id`) en adaptant le format texte (`REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_')`).
* **Normalisation des Lignes de Produits :** Traduction des codes métiers en libellés explicites (`R` $\rightarrow$ `'Road'`, `M` $\rightarrow$ `'Mountain'`, `T` $\rightarrow$ `'Touring'`, `S` $\rightarrow$ `'Other Sales'`).
* **Historisation Temporelle (SCD Type 2) :** Implémentation d'une fonction de fenêtrage `LEAD()` pour calculer dynamiquement la date de fin de validité d'un produit (`prd_end_dt`). Elle récupère la date de début de la version suivante et lui soustrait un jour `+ 1`. Si le produit est la version la plus récente et toujours active, la date infinie par défaut `'9999-12-31'` lui est affectée.

### 🗺️ 3. Cartographie Géographique (`loc_a101`)
* **Dédoublonnage des Synonymes :** Regroupement des saisies utilisateurs variées sous une nomenclature unique et propre pour l'analyse décisionnelle :
  * `('US', 'USA', 'UNITED STATES')` $\rightarrow$ `'United States'`
  * `('DE', 'GERMANY')` $\rightarrow$ `'Germany'`
* **Nettoyage des Caractères Invisibles :** Traitement des chaînes vides et suppression explicite des espaces insécables encodés (`REPLACE(cntry, chr(160), '')`) pour éviter les faux doublons ou les erreurs de jointure invisibles.

### 💰 4. Historique des Transactions (`sales_details`)
C'est le moteur financier de notre infrastructure. Le script applique une triple validation et un redressement en cascade à travers deux sous-étapes (CTE) :
* **Redressement par Valeur Absolue :** Application de la fonction `ABS()` sur les montants de ventes (`sls_sales`), les prix (`sls_price`) et les quantités (`sls_qty`) pour corriger les erreurs humaines de saisies négatives issues des systèmes transactionnels d'origine.
* **Élimination des Zéros :** Forçage des quantités et des prix nuls ou inférieurs à zéro à `1` pour bloquer toute tentative de division par zéro ou de calcul impossible.
* **Alignement Comptable Strict :**
  * *Règle A :* Si le montant de la vente est manquant ou égal à 0, il est recalculé dynamiquement : $\text{sls\_sales} = \text{Quantité Redressée} \times \text{Prix Unitaire}$.
  * *Règle B :* Si le prix unitaire d'origine est manquant ou égal à 0, il est recalculé au centime près : $\text{sls\_price} = \text{Montant Vente} / \text{Quantité}$.

---

## 📁 Architecture des Dossiers

```text
📦 Projet 2 data warehouse
 ┣ 📂 Bronze
 ┣ 📂 Silver
 ┃ ┣ 📜 Transform.py                                   <-- Orchestrateur Python de la couche Silver
 ┃ ┣ 📜 transform_bronze_to_silver_cust_az12.sql       <-- Standardisation de la source CRM secondaire
 ┃ ┣ 📜 transform_bronze_to_silver_cust_info.sql       <-- Nettoyage et dédoublonnage des clients principaux
 ┃ ┣ 📜 transform_bronze_to_silver_loc_a101.sql       <-- Normalisation des géographies et pays
 ┃ ┣ 📜 transform_bronze_to_silver_prd_info.sql       <-- Typage et Historisation Produits (SCD Type 2)
 ┃ ┣ 📜 transform_bronze_to_silver_px_cat_g1v2.sql     <-- Table de référence (Mode Pass-Through)
 ┃ ┗ 📜 transform_bronze_to_silver_sales_details.sql   <-- Alignement mathématique et temporel des ventes
 ┣ 📂 Gold
 ┗ 📜 Orchestrateur.py