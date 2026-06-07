# 🟫 Couche BRONZE — Ingestion & Stockage Brut

La couche **Bronze** constitue le point d'entrée unique et immuable de notre architecture moderne de Data Warehouse (méthodologie *Medallion Architecture*). Son rôle principal est d'extraire les données brutes des différents systèmes sources (fichiers plats `CSV`) et de les charger dans notre base de données PostgreSQL sous forme de tables relationnelles brutes.

Cette couche respecte scrupuleusement le paradigme de l'**idempotence** : une exécution répétée ou multiple du script produit exactement le même état final en base de données, sans jamais dupliquer ou corrompre les données.

---

## 🎯 Objectifs de la Couche Bronze

1. **Persistance Historique Stricte :** Conserver l'intégralité des données d'origine sans altération, filtrage ou transformation métier. Aucune règle de gestion ou de nettoyage n'est tolérée à ce stade.
2. **Découplage des Systèmes Sources :** Isoler l'entrepôt de données des fichiers sources volatils. Une fois le script exécuté, les fichiers plats peuvent être archivés, déplacés ou modifiés sans impacter la stabilité du reste du pipeline.
3. **Optimisation des Types pour l'Ingestion :** Forcer temporairement le stockage de toutes les colonnes brutes en type textuel (`VARCHAR`/`TEXT`). Cela garantit qu'aucune ligne ne soit rejetée ou tronquée lors de la phase d'ingestion à cause d'un problème de format (ex: dates mal formatées, caractères spéciaux, ou séparateurs régionaux).

---

## 📁 Architecture des Dossiers

```text
📦 Projet 2 data warehouse
 ┣ 📂 Bronze
 ┃ ┣ 📂 datasets                 <-- Répertoire source contenant les fichiers bruts (.csv)
 ┃ ┃ ┣ 📄 CUST_AZ12.csv
 ┃ ┃ ┣ 📄 cust_info.csv
 ┃ ┃ ┣ 📄 LOC_A101.csv
 ┃ ┃ ┣ 📄 prd_info.csv
 ┃ ┃ ┣ 📄 PX_CAT_G1V2.csv
 ┃ ┃ ┗ 📄 sales_details.csv
 ┃ ┗ 📜 Extract.py               <-- Script Python automatisé d'extraction et d'injection
 ┣ 📂 Silver
 ┣ 📂 Gold
 ┗ 📜 Orchestrateur.py           <-- Point de contrôle global (Master Orchestrator)