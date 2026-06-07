"""
============================================================================
NOM DU SCRIPT : Gold/Load.py
COUCHE        : Gold (Zone Décisionnelle / Modèle en Étoile)
============================================================================
"""

import os
import time
from pathlib import Path
from sqlalchemy import create_engine, text

CONNEXION_DB = os.getenv(
    "DATABASE_URL", 
    "postgresql://votre_utilisateur:votre_mot_de_passe@localhost:5432/votre_base_de_donnees"
)
engine = create_engine(CONNEXION_DB)

# =============================================================================
# DETECTION ET ANCRAGE INTELLIGENT DU DOSSIER GOLD
# =============================================================================
CHEMIN_PARENT = Path(__file__).resolve().parent
if CHEMIN_PARENT.name != "Gold":
    DOSSIER_GOLD = CHEMIN_PARENT / "Gold"
else:
    DOSSIER_GOLD = CHEMIN_PARENT

SCRIPTS_GOLD = [
    "dim_customer.sql",
    "dim_product.sql",
    "fact_sales.sql"
]


def executer_script_sql(nom_fichier):
    # On force la recherche à l'intérieur du dossier Gold calculé dynamiquement
    chemin_complet_sql = DOSSIER_GOLD / nom_fichier
    
    if not chemin_complet_sql.exists():
        print(f"❌ Erreur : Le fichier '{nom_fichier}' est introuvable à l'adresse : {chemin_complet_sql}")
        return False
        
    try:
        with open(chemin_complet_sql, 'r', encoding='utf-8') as f:
            requete_sql = f.read()
        
        with engine.begin() as connexion:
            connexion.execute(text(requete_sql))
        return True
        
    except Exception as e:
        print(f"💥 Erreur critique lors de l'exécution de '{nom_fichier}' : {e}")
        return False


def executer_generation_gold():
    print("=============================================================================")
    print(" 🚀 LANCEMENT DE L'ORCHESTRATION DE LA COUCHE GOLD (MODELE EN ETOILE)     ")
    print("=============================================================================")
    
    temps_debut = time.time()
    
    for index, script in enumerate(SCRIPTS_GOLD, start=1):
        print(f"\n⏳ [Action {index}/{len(SCRIPTS_GOLD)}] Exécution de : {script}...")
        reussite = executer_script_sql(script)
        
        if not reussite:
            print(f"\n🛑 Pipeline interrompu prématurément suite à un échec sur : {script}")
            raise RuntimeError(f"Erreur d'exécution du script Gold : {script}")

    temps_fin = time.time()
    duree_totale = round(temps_fin - temps_debut, 2)
    
    print("\n=============================================================================")
    print(f" 🎉 COUCHE GOLD DISPONIBLE ! Modèle en étoile généré en {duree_totale} secondes. ")
    print("=============================================================================")


if __name__ == "__main__":
    executer_generation_gold()