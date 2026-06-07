# Fichier: Orchestrateur.py (à la racine)
import sys
import time
from pathlib import Path

# Racine du projet
BASE_DIR = Path(__file__).resolve().parent

# Rattachement des sous-dossiers au moteur d'importation Python
for sous_dossier in ["Bronze", "Silver", "Gold"]:
    chemin_dossier = BASE_DIR / sous_dossier
    if chemin_dossier.exists():
        sys.path.append(str(chemin_dossier))
    else:
        print(f"❌ Dossier d'architecture manquant : {sous_dossier}")
        sys.exit(1)

# Importation sécurisée des modules enfants
try:
    from Extract import pipeline_vers_bronze
    from Transform import run_silver_pipeline
    from Load import executer_generation_gold
except ImportError as e:
    print(f"❌ Erreur d'importation des modules : {e}")
    sys.exit(1)


def executer_pipeline_global():
    print("=============================================================================")
    print(" ⚡️ MASTER ORCHESTRATOR : PIPELINE GLOBAL DU DATA WAREHOUSE INTEGRÉ        ")
    print("=============================================================================")
    
    debut_global = time.time()
    
    # 1. COUCHE BRONZE
    print("\n[COUCHE 1/3] 🟫 Ingestion brute vers la couche BRONZE...")
    try:
        pipeline_vers_bronze()
    except Exception as e:
        print(f"🛑 Échec critique Bronze : {e}")
        return

    # 2. COUCHE SILVER
    print("\n[COUCHE 2/3] 🥈 Transformation vers la couche SILVER...")
    try:
        run_silver_pipeline()
    except Exception as e:
        print(f"🛑 Échec critique Silver : {e}")
        return

    # 3. COUCHE GOLD
    print("\n[COUCHE 3/3] 🥇 Modélisation finale vers la couche GOLD...")
    try:
        executer_generation_gold()
    except Exception as e:
        print(f"🛑 Échec critique Gold : {e}")
        return

    fin_global = time.time()
    print("\n=============================================================================")
    print(f" 🎉 SUCCÈS GLOBAL ! L'entrepôt de données a été entièrement construit ou reconstruit. ")
    print(f" ⏱️ Temps d'exécution total de bout en bout : {round(fin_global - debut_global, 2)} secondes.")
    print("=============================================================================")


if __name__ == "__main__":
    executer_pipeline_global()