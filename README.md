

---
# 🏛️ Enterprise Data Warehouse — Architecture Médaillon (PostgreSQL & Python)

Ce projet implémente un **Entrepôt de Données (Data Warehouse) de bout en bout** basé sur l'**Architecture Médaillon** (*Bronze*, *Silver*, *Gold*). L'objectif est d'ingérer des fichiers transactionnels et des référentiels bruts (fichiers CSV), d'appliquer des règles strictes de nettoyage et de validation de données (*Data Quality*), et de structurer un **Modèle en Étoile** (*Star Schema*) hautement performant, prêt pour l'analyse décisionnelle et la connexion à des outils de Business Intelligence comme **Power BI**.

---

## 🗺️ Vue d'Ensemble de l'Architecture

L'infrastructure segmente les responsabilités en trois schémas de base de données distincts au sein de PostgreSQL :

```text
  📥 [Sources CSV] 
         │
         ▼
 🥉 Couche BRONZE   ──► Ingestion brute "As-Is" (Tables d'atterrissage typées en VARCHAR)
         │
         ▼
 🥈 Couche SILVER   ──► Nettoyage, standardisation, SCD Type 2 & Alignement mathématique
         │
         ▼
 🥇 Couche GOLD     ──► Modèle en étoile (Vues décisionnelles : Dimensions & Table de Faits)
         │
         ▼
 📊 [Power BI / BI] ──► Modélisation sémantique, rapports et analyses ROI
```

---

## 📁 Architecture Complète du Répertoire

```plaintext
📦 Projet 2 data warehouse
 ┣ 📂 Bronze
 ┃ ┣ 📂 datasets                                       <-- Répertoire contenant les fichiers CSV sources
 ┃ ┗ 📜 Extract.py                                     <-- Ingestion automatisée (Pandas & SQLAlchemy)
 ┣ 📂 Silver
 ┃ ┣ 📜 Transform.py                                   <-- Orchestrateur des transformations SQL Silver
 ┃ ┣ 📜 transform_bronze_to_silver_cust_az12.sql       <-- Standardisation du CRM secondaire
 ┃ ┣ 📜 transform_bronze_to_silver_cust_info.sql       <-- Nettoyage et dédoublonnage des clients principaux
 ┃ ┣ 📜 transform_bronze_to_silver_loc_a101.sql        <-- Normalisation géographique et traitement du pays
 ┃ ┣ 📜 transform_bronze_to_silver_prd_info.sql        <-- Typage et Historisation Produits (SCD Type 2)
 ┃ ┣ 📜 transform_bronze_to_silver_px_cat_g1v2.sql     <-- Table de référence (Mode Pass-Through)
 ┃ ┗ 📜 transform_bronze_to_silver_sales_details.sql   <-- Alignement financier strict des transactions
 ┣ 📂 Gold
 ┃ ┣ 📜 Load.py                                        <-- Compilation du modèle décisionnel
 ┃ ┣ 📜 dim_customer.sql                               <-- Vue Dimension Clients (Unification multi-source)
 ┃ ┣ 📜 dim_product.sql                                <-- Vue Dimension Produits (Hiérarchies enrichies)
 ┃ ┗ 📜 fact_sales.sql                                 <-- Vue Table de Faits centrale des Ventes
 ┗ 📜 Orchestrateur.py                                 <-- Pilote général de l'ensemble du Data Warehouse
```

---

## 🔄 Détail des Couches et Séquence de Traitement

### 🥉 1. Couche BRONZE — Zone d'Atterrissage & Ingestion

**Rôle :** Absorber l'ensemble des fichiers plats du dossier datasets de manière brute, sans altérer la donnée d'origine, afin de conserver un historique technique auditable.

**Logique Python (Bronze/Extract.py) :**

* Détecte et ancre intelligemment le dossier racine à l'aide de pathlib.Path pour éviter les chemins écrits en dur.
* Force la lecture de toutes les colonnes en type texte (dtype=str via Pandas) pour éliminer les risques de perte de précision ou de plantages sur les types natifs lors du chargement initial.
* Nettoie et standardise les entêtes de colonnes (retrait des espaces, passage en minuscules, remplacement des espaces par des tirets bas _).
* Injecte les structures dans PostgreSQL dans le schéma "Bronze" avec l'option if_exists='replace' pour assurer l'idempotence totale du pipeline.

---

### 🥈 2. Couche SILVER — Nettoyage, Qualité & Standardisation

**Rôle :** Assainir la donnée brute, valider les règles métiers, forcer un typage SQL strict (DATE, NUMERIC, INTEGER) et gérer les exclusions.

**Logique Python (Silver/Transform.py) :**

* Exécute une suite ordonnée de scripts SQL au sein d'une transaction unique gérée par psycopg2.
* Mécanisme de Rollback intégré : Si un script SQL de la chaîne échoue, la transaction applique instantanément un connection.rollback(), évitant la présence de données partielles ou asymétriques en base de données.

**Règles SQL appliquées par fichier :**

* transform_bronze_to_silver_cust_info.sql :
  Suppression des espaces parasites (TRIM), harmonisation du genre (M → 'Male', F → 'Female') et dédoublonnage strict via ROW_NUMBER().

* transform_bronze_to_silver_cust_az12.sql :
  Nettoyage du préfixe 'NAS' et sécurisation des dates de naissance corrompues.

* transform_bronze_to_silver_prd_info.sql :
  SCD Type 2 via LEAD(), gestion des coûts manquants, historisation des produits.

* transform_bronze_to_silver_loc_a101.sql :
  Normalisation géographique et traitement des synonymes de pays.

* transform_bronze_to_silver_px_cat_g1v2.sql :
  Mode Pass-Through pour les catégories.

* transform_bronze_to_silver_sales_details.sql :
  Alignement financier, ABS(), recalcul des ventes.

---

### 🥇 3. Couche GOLD — Zone Décisionnelle (Modèle en Étoile)

**Rôle :** Présenter les données sous forme de structures sémantiques claires, optimisées pour le requêtage décisionnel.

**Logique Python (Gold/Load.py) :**

* Exécution orchestrée avec SQLAlchemy
* Stratégie Fail-Fast
* Respect des dépendances

**Modélisation :**

* dim_customer : unification multi-source + fallback
* dim_product : enrichissement catégories
* fact_sales : table centrale des indicateurs

---

## 🔒 Principes de Robustesse et d'Ingénierie Logicielle

* Ancrage absolu des chemins
* Idempotence
* Zéro propagation de NULL
* Automatisation complète

---

## 🚀 Guide d'Utilisation et Déploiement

### 1. Prérequis

```bash
pip install pandas sqlalchemy psycopg2-binary
```

---

### 2. Configuration

```bash
# Windows
$env:DATABASE_URL="postgresql://utilisateur:mot_de_passe@localhost:5432/nom_base"

# Linux / macOS
export DATABASE_URL="postgresql://utilisateur:mot_de_passe@localhost:5432/nom_base"
```

---

### 3. Exécution

```bash
python Orchestrateur.py
```

---

## 📈 Exemple de logs

```plaintext
=============================================================================
 ⚡ DEBUT DE L'ORCHESTRATION DU DATA WAREHOUSE (END-TO-END)
=============================================================================

[ETAPE 1/3] Ingestion des fichiers plats dans la couche BRONZE...
...

[ETAPE 2/3] Transformation SILVER...
...

[ETAPE 3/3] Génération du modèle GOLD...
...

=============================================================================
 🎉 EXECUTION REUSSIE : Le Data Warehouse est prêt !
=============================================================================
```

---


