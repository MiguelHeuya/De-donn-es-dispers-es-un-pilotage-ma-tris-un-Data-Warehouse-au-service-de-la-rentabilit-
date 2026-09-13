from pathlib import Path
from sqlalchemy import create_engine, text
from config import (
    DATA_BASE_SOURCE_A_URI, 
    DATA_BASE_SOURCE_B_URI, 
    SOURCE_SCHEMA,
    DATA_BASE_SOURCE_A_SQLALCHEMY_URI, 
    DATA_BASE_SOURCE_B_SQLALCHEMY_URI
)
import polars as pl

dossier_data = Path(__file__).resolve().parent / "data"

# 1. Initialisation des moteurs applicatifs
engine_erp = create_engine(DATA_BASE_SOURCE_A_SQLALCHEMY_URI)
engine_crm = create_engine(DATA_BASE_SOURCE_B_SQLALCHEMY_URI)

schema_name = SOURCE_SCHEMA

# 🔒 DÉBUT DE LA TRANSACTION GLOBALE : On ouvre une transaction sur CHAQUE base de données
with engine_erp.begin() as conn_erp, engine_crm.begin() as conn_crm:
    
    # 2. Création des schémas dans leurs transactions respectives
    conn_erp.execute(text(f"CREATE SCHEMA IF NOT EXISTS {schema_name};"))
    conn_crm.execute(text(f"CREATE SCHEMA IF NOT EXISTS {schema_name};"))
    
    # 3. Traitement de l'ensemble des dossiers
    for dossier in dossier_data.iterdir():
        if dossier.is_dir():
            nom_dossier = dossier.name.lower()
            
            # Sélection de la connexion appropriée
            if nom_dossier == "erp":
                conn_active = conn_erp
                data_base_name = "erp"
            elif nom_dossier == "crm":
                conn_active = conn_crm
                data_base_name = "crm"
            else:
                continue  # Ignore les dossiers non gérés

            print(f"Traitement du dossier : {dossier.name}") # Message qui ne s'affichera pas dans les logs de la production

            # Insertion des tables
            for file in dossier.iterdir():
                if file.is_file() and file.suffix.lower() == ".csv":
                    table_name = file.stem.lower().replace(" ", "_")  # Normalisation du nom de la table
                    
                    df = pl.read_csv(file)
                    target_table = f"{schema_name}.{table_name}"
                    
                    # L'insertion se fait au sein de la transaction active du dossier
                    df.write_database(
                        connection=conn_active,
                        table_name=target_table,
                        if_table_exists="replace"
                    )

                    print(f"         Table '{table_name}' préparée dans la transaction de '{data_base_name}'.") # Message qui ne s'affichera pas dans les logs de la production

# 🔓 FIN DE LA TRANSACTION GLOBALE : 
# Si le code arrive ici sans erreur, SQLAlchemy valide (COMMIT) simultanément 'erp' et 'crm'.
# En cas d'erreur (ex: CSV corrompu), TOUT est annulé (ROLLBACK) sur TOUTES les bases de données.
print("[SUCCESS] Ingestion terminée avec succès sur l'ensemble des bases de données !")