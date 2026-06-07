# Fichier: Silver/Transform.py
import logging
import os
from pathlib import Path
import psycopg2
from psycopg2 import Error

# Configuration des logs
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

DB_CONFIG = {
    "user": "your_username",
    "password": "your_password",
    "host": "your_server",
    "port": "your_port",      
    "database": "your_database_name"
}

# =============================================================================
# ANCRAGE ET CORRECTION DYNAMIQUE DU SOUS-DOSSIER 'Silver'
# =============================================================================
CHEMIN_PARENT = Path(__file__).resolve().parent

# Si le script est exécuté depuis la racine ou qu'il ne trouve pas le fichier SQL directement,
# on le force à pointer vers le sous-dossier "Silver"
if CHEMIN_PARENT.name != "Silver":
    DOSSIER_SILVER = CHEMIN_PARENT / "Silver"
else:
    DOSSIER_SILVER = CHEMIN_PARENT

SQL_PIPELINE = [
    "transform_bronze_to_silver_cust_info.sql",
    "transform_bronze_to_silver_prd_info.sql",
    "transform_bronze_to_silver_sales_details.sql",
    "transform_bronze_to_silver_cust_az12.sql",
    "transform_bronze_to_silver_px_cat_g1v2.sql",
    "transform_bronze_to_silver_loc_a101.sql"
]

def run_silver_pipeline():
    connection = None
    cursor = None
    try:
        logging.info("Connexion à la base de données PostgreSQL...")
        connection = psycopg2.connect(**DB_CONFIG)
        cursor = connection.cursor()

        for nom_fichier_sql in SQL_PIPELINE:
            # On utilise le DOSSIER_SILVER corrigé pour trouver les fichiers SQL
            full_sql_path = (DOSSIER_SILVER / nom_fichier_sql).resolve()
            
            logging.info(f"▶️ Lecture du script SQL : {full_sql_path}")
            
            if not full_sql_path.exists():
                raise FileNotFoundError(f"⚠️ Impossible de trouver le fichier SQL à l'adresse stricte : {full_sql_path}")
            
            with open(full_sql_path, 'r', encoding='utf-8') as file:
                sql_script = file.read()

            logging.info(f"Exécution de la transformation : {nom_fichier_sql}...")
            cursor.execute(sql_script)
            logging.info(f"✅ Succès pour le script : {nom_fichier_sql}")

        logging.info("Validation des changements (Commit) dans PostgreSQL...")
        connection.commit()
        logging.info("🚀 Succès global ! Les tables apparaissent maintenant dans le schéma 'Silver'.")

    except (Exception, Error) as error:
        logging.error(f"🔴 Erreur critique lors de l'exécution du pipeline : {error}")
        if connection:
            logging.info("Rollback activé : annulation de toutes les modifications de ce run.")
            connection.rollback()
        raise error
            
    finally:
        if cursor:
            cursor.close()
        if connection:
            connection.close()
            logging.info("Connexion PostgreSQL fermée.")

if __name__ == "__main__":
    run_silver_pipeline()