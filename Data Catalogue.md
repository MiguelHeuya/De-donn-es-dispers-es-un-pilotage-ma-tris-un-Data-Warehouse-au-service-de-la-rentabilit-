

# 📖 DATA CATALOGUE — DATA PRODUCT : DECISIONAL SALES & CRM

**Version :** 1.0.0

**Statut :** Production (Ready for BI / Power BI)

**Domaine Métier :** Performance Commerciale & Client

**Architecture :** Modèle en Étoile (Kimball - SCD Type 1)

**Moteur de Données :** PostgreSQL (Schéma `"Gold"`)

---

## 🗺️ Schéma Conceptuel du Data Product

Le catalogue repose sur un modèle en étoile composé de deux tables de dimensions et d'une table de faits centrale :

* **`dim_customer`** (Axe Client) $\rightarrow$ Relation (1 à Plusieurs) $\rightarrow$ **`fact_sales`**
* **`dim_product`** (Axe Produit) $\rightarrow$ Relation (1 à Plusieurs) $\rightarrow$ **`fact_sales`**

---

## 👥 1. TABLE : `Gold.dim_customer`

* **Description :** Référentiel sémantique unique des clients de l'entreprise. Cette table unifie les données d'état civil, le profilage comportemental et les données géographiques à travers une réconciliation multi-sources (Silver `cust_info`, `cust_az12` et `loc_a101`).
* **Type d'Objet :** `VIEW` (SCD Type 1 - Écrasement dynamique pour afficher la dernière vérité connue).
* **Granularité :** Une ligne par client unique.

### 📋 Dictionnaire des Attributs (`dim_customer`)

| Nom du Champ (BI) | Type SQL | Clé / Contrainte | Source Amont (Silver) | Description & Règles Métier |
| --- | --- | --- | --- | --- |
| **`customer_id`** | `BIGINT` | **PK** (Clé Artificielle) | *Généré à la volée* | **Surrogate Key :** Identifiant numérique séquentiel unique généré par `ROW_NUMBER() OVER()`. Assure l'intégrité 1-N dans Power BI. |
| **`customer_key`** | `VARCHAR` | Clé Naturelle | `cust_info.cst_id` | Identifiant technique brut interne issu du système source principal. |
| **`customer_number`** | `VARCHAR` | Métrique Métier | `cust_info.cst_key` | Numéro de compte business officiel du client (nettoyé des espaces via `TRIM`). |
| **`first_name`** | `VARCHAR` | Attribut | `cust_info.cst_firstname` | Prénom du client (nettoyé des espaces via `TRIM`). |
| **`last_name`** | `VARCHAR` | Attribut | `cust_info.cst_lastname` | Nom de famille du client (nettoyé des espaces via `TRIM`). |
| **`gender`** | `VARCHAR` | Attribut / Filtre | `cust_info.cst_gndr` & `cust_az12.gen` | **Cross-Source Fallback Logic :** Harmonisé en `'Male'` / `'Female'`. Si absent de la source principale (`'n/a'`), récupération automatique depuis le CRM secondaire. Valeur par défaut `'n/a'` en cas d'absence totale. |
| **`marital_status`** | `VARCHAR` | Attribut / Filtre | `cust_info.cst_marital_status` | Statut marital normalisé (ex: Marié, Célibataire). Sécurisé contre les chaînes vides. |
| **`country`** | `VARCHAR` | Géographie / Axe | `loc_a101.cntry` | Pays de résidence du client. **Règle de Data Quality :** Harmonisation des synonymes (`'USA'`, `'US'` $\rightarrow$ `'United States'`). Forçage à `'n/a'` si la correspondance géographique est introuvable. |
| **`birth_date`** | `DATE` | Temporel | `cust_az12.bdate` | Date de naissance du client issue de la source secondaire. Sécurisée à `'1900-01-01'` si le format d'origine était corrompu ou incomplet. |
| **`create_date`** | `DATE` | Temporel | `cust_info.cst_create_date` | Date de création du profil client dans le système source d'origine. |

---

## 📦 2. TABLE : `Gold.dim_product`

* **Description :** Catalogue centralisé des produits commercialisés par l'entreprise, enrichi de sa hiérarchie de catégorisation (catégories et sous-catégories) et de ses métadonnées financières.
* **Type d'Objet :** `VIEW` (SCD Type 1 - Mise à jour dynamique).
* **Granularité :** Une ligne par produit unique.

### 📋 Dictionnaire des Attributs (`dim_product`)

| Nom du Champ (BI) | Type SQL | Clé / Contrainte | Source Amont (Silver) | Description & Règles Métier |
| --- | --- | --- | --- | --- |
| **`product_key`** | `BIGINT` | **PK** (Clé Artificielle) | *Généré à la volée* | **Surrogate Key :** Identifiant numérique séquentiel unique généré par `ROW_NUMBER() OVER()`. Clé de jointure primaire pour le modèle en étoile. |
| **`product_id`** | `INTEGER` | Clé Naturelle | `prd_info.prd_id` | Identifiant technique brut interne de la table produit d'origine. |
| **`product_number`** | `VARCHAR` | Clé Métier | `prd_info.prd_key` | Référence unique / Code SKU business du produit (extrait par troncature des préfixes techniques). |
| **`product_name`** | `VARCHAR` | Attribut | `prd_info.prd_nm` | Libellé commercial complet du produit. |
| **`categorie_id`** | `VARCHAR` | Clé Étrangère | `prd_info.cat_id` | Code de liaison extrait de la clé produit pour mapper la table de référence des catégories. |
| **`cat`** | `VARCHAR` | Hiérarchie / Filtre | `px_cat_g1v2.cat` | Libellé de la catégorie principale du produit (ex: Components, Accessories). Sécurisé par `COALESCE` à `'n/a'`. |
| **`subcat`** | `VARCHAR` | Hiérarchie / Filtre | `px_cat_g1v2.subcat` | Libellé de la sous-catégorie du produit. Sécurisé par `COALESCE` à `'n/a'`. |
| **`maintenance`** | `VARCHAR` | Attribut | `px_cat_g1v2.maintenance` | Indicateur technique ou statut lié à la maintenance du produit. Sécurisé à `'n/a'`. |
| **`cost`** | `NUMERIC` | Métrique | `prd_info.prd_cost` | Coût unitaire de production ou d'achat du produit. Les valeurs négatives ou manquantes ont été nettoyées et redressées à `0` en amont. |
| **`product_line`** | `VARCHAR` | Attribut / Filtre | `prd_info.prd_line` | Traduction sémantique explicite de la gamme de produit (`'R'` $\rightarrow$ `'Road'`, `'M'` $\rightarrow$ `'Mountain'`, etc.). |
| **`start_date`** | `DATE` | Temporel | `prd_info.prd_start_dt` | Date d'introduction officielle du produit sur le marché ou début de validité du prix. |

---

## 💰 3. TABLE DE FAITS : `Gold.fact_sales`

* **Description :** Table centrale accumulant l'ensemble des transactions de ventes et indicateurs commerciaux de l'entreprise. Elle effectue le raccordement analytique vers les dimensions Gold pour exposer les clés de substitution.
* **Type d'Objet :** `VIEW` (Moteur transactionnel du modèle en étoile).
* **Granularité :** Une ligne par ligne d'article commandé dans un bon de commande.

### 📋 Dictionnaire des Attributs (`fact_sales`)

| Nom du Champ (BI) | Type SQL | Clé / Contrainte | Dimension Raccordée | Description & Règles Métier |
| --- | --- | --- | --- | --- |
| **`sale_id`** | `VARCHAR` | Clé Transactionnelle | *Aucune* | Numéro de commande unique (Bon de commande / Facture). Nettoyé des espaces. |
| **`product_key`** | `BIGINT` | **FK** | `Gold.dim_product` | Jointure gauche effectuée sur la clé naturelle `product_number`. Récupère la clé artificielle de la dimension Produit. |
| **`customer_key`** | `BIGINT` | **FK** | `Gold.dim_customer` | Jointure gauche effectuée sur la clé naturelle `customer_key`. Récupère la clé artificielle de la dimension Client. |
| **`order_date`** | `DATE` | Axe Temporel | *Dimension Temps* | Date exacte à laquelle la commande a été enregistrée par le client. Convertie au format DATE strict. |
| **`ship_date`** | `DATE` | Axe Temporel | *Dimension Temps* | Date d'expédition réelle de la marchandise depuis l'entrepôt. |
| **`due_date`** | `DATE` | Axe Temporel | *Dimension Temps* | Date d'échéance attendue pour le règlement de la facture ou la livraison. |
| **`sale_amount`** | `NUMERIC` | Métrique (Somme/Moy) | *Aucune* | **Chiffre d'Affaires :** Montant financier net de la ligne de transaction. **Règle métier stricte :** Si la valeur était manquante ou nulle en source, elle est automatiquement recalculée par la formule : $\text{Quantity} \times \text{Price}$. |
| **`quantity`** | `NUMERIC` | Métrique (Somme) | *Aucune* | Nombre d'unités vendues pour cet article. Redressé par la fonction `ABS()` pour interdire les volumes négatifs. |
| **`price`** | `NUMERIC` | Métrique (Moy/Min/Max) | *Aucune* | Prix unitaire facturé au client. Nettoyé des valeurs négatives et aberrantes. |

---

## 🔐 Règles de Gouvernance, Sécurité & Qualité (Data Quality Standards)

Pour garantir une exploitation saine de ce Data Product dans **Power BI**, les règles de gouvernance de données suivantes sont appliquées lors de sa génération :

1. **Zéro propagation de valeurs `NULL` :** Toutes les dimensions interdisent la propagation de la valeur système `NULL` dans les colonnes de filtrage ou de regroupement. La fonction `COALESCE()` remplace systématiquement les vides par la chaîne standardisée `'n/a'`. Cela évite l'apparition de lignes blanches ou de catégories "vides" non filtrables dans les visuels des tableaux de bord.
2. **Performance des relations (Modèle en Étoile pur) :** Les liaisons entre `fact_sales` et ses dimensions se font exclusivement via des clés de substitution numériques (`product_key` et `customer_key`) de type `BIGINT`. Ce choix technique garantit une vitesse de calcul maximale des agrégations de DAX et minimise l'empreinte mémoire dans le moteur VertiPaq de Power BI.
3. **Idempotence et Robustesse :** Le Data Product est régénéré par un script orchestrateur Python (`Gold/Load.py`) qui supprime (`DROP VIEW IF EXISTS ... CASCADE`) puis recrée proprement les structures à chaque run. Aucune altération ou corruption de modèle n'est possible en cas de relancement.
4. **Principe Fail-Fast :** Le chargement respecte l'arbre de dépendance technique. Si la vue `dim_customer` ou `dim_product` rencontre une anomalie de compilation, l'exécution s'interrompt instantanément via une exception `RuntimeError` pour empêcher la table de faits `fact_sales` de pointer vers des axes d'analyses corrompus.