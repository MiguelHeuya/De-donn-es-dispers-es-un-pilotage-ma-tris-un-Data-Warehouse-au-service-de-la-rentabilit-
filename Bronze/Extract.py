##### Import des bibliothèques
import os
from pathlib import Path
import pandas as pd
from sqlalchemy import create_engine

# =============================================================================
# DETECTION ET ANCRAGE INTELLIGENT DU DOSSIER BRONZE
# =============================================================================
# __file__ donne l'emplacement du script. On s'assure de cibler le dossier Bronze.
CHEMIN_PARENT = Path(__file__).resolve().parent
if CHEMIN_PARENT.name != "Bronze":
    DOSSIER_BRONZE = CHEMIN_PARENT / "Bronze"
else:
    DOSSIER_BRONZE = CHEMIN_PARENT

# Le dossier datasets est toujours à l'intérieur du dossier Bronze
DOSSIER_DATASETS = DOSSIER_BRONZE / "datasets"

# Connexion à la base de données
CONNEXION_DB = os.getenv(
    "DATABASE_URL", 
    "postgresql://your_username:your_password@your_server:your_port/your_database_name"
)
engine = create_engine(CONNEXION_DB)


def nettoyer_noms_colonnes(df):
    """Adapte le nom des colonnes pour faciliter les requêtes SQL."""
    df.columns = df.columns.str.strip().str.lower().str.replace(' ', '_')
    return df


def pipeline_vers_bronze():
    """Effectue une ingestion automatisée des fichiers CSV vers la couche Bronze."""
    print("=============================================================================")
    print(" == Début de l'ingestion des données dans la couche Bronze          =====")
    print("=============================================================================")
    print(f"[INFO] Répertoire Bronze détecté : {DOSSIER_BRONZE}")
    print(f"[INFO] Recherche des fichiers dans : {DOSSIER_DATASETS}")
    
    if not DOSSIER_DATASETS.exists():
        print(f"❌ Erreur critique : Le dossier des datasets n'existe pas ici : {DOSSIER_DATASETS}")
        return

    fichiers_csv = list(DOSSIER_DATASETS.glob("*.csv"))
    if not fichiers_csv:
        print("⚠️ Aucun fichier CSV trouvé dans le dossier datasets.")
        return

    for chemin_fichier in fichiers_csv:
        nom_table = chemin_fichier.stem.lower()
        print("\n-------------------------------------->>>>>>>>>>>>>>>>>>>>>>")
        print(f"Traitement du fichier : {chemin_fichier.name} -> Table : {nom_table}")
        print(" -------------------------------------->>>>>>>>>>>>>>>>>>>>>>")
        try:
            df = pd.read_csv(chemin_fichier, dtype=str)
            df = nettoyer_noms_colonnes(df)
            df.to_sql(name=nom_table, con=engine, schema='Bronze', if_exists='replace', index=False)
            print(f"✅ Succès : '{len(df)}' lignes insérées avec succès dans 'Bronze'.'{nom_table}'")
        except Exception as e:
            print(f"❌ Erreur critique lors du traitement du fichier '{chemin_fichier.name}' : {e}")
            raise e

    print("\n=============================================================================")
    print("== Fin de l'ingestion des données dans la couche Bronze               =====")
    print("=============================================================================")


if __name__ == "__main__":
    pipeline_vers_bronze()