import logging
from pathlib import Path
import polars as pl
from sqlalchemy import create_engine, text
import config

# Configuration des logs
logging.basicConfig(
    level=getattr(logging, config.LOG_LEVEL.upper(), logging.INFO),
    format="%(asctime)s [%(levelname)s] %(message)s"
)
logger = logging.getLogger(config.APP_NAME)


def ensure_schema_exists(engine, schema_name: str):
    """Crée le schéma dans la base de données s'il n'existe pas encore."""
    with engine.connect() as conn:
        conn.execute(text(f"CREATE SCHEMA IF NOT EXISTS {schema_name};"))
        conn.commit()


def process_directory(dir_path: Path, db_sqlalchemy_url: str, schema_name: str):
    """Lit les fichiers CSV d'un dossier et les charge dans la base cible."""
    if not dir_path.exists():
        logger.warning(f"Dossier introuvable : '{dir_path}'. Étape ignorée.")
        return

    csv_files = list(dir_path.glob("*.csv"))
    if not csv_files:
        logger.info(f"Aucun fichier CSV dans '{dir_path}'.")
        return

    # Connexion et préparation du schéma
    engine = create_engine(db_sqlalchemy_url)
    ensure_schema_exists(engine, schema_name)

    logger.info(f"--- Ingestion '{dir_path.name}' -> schéma '{schema_name}' ({len(csv_files)} fichier(s)) ---")

    for csv_file in csv_files:
        table_name = csv_file.stem.lower()
        logger.info(f"Traitement : '{csv_file.name}' -> '{schema_name}.{table_name}'...")

        try:
            df = pl.read_csv(csv_file)
            if df.is_empty():
                logger.warning(f"Fichier vide ignoré : '{csv_file.name}'")
                continue

            # Écriture dans PostgreSQL
            df.write_database(
                table_name=f"{schema_name}.{table_name}",
                connection=db_sqlalchemy_url,
                engine="sqlalchemy",
                if_table_exists="replace"
            )
            logger.info(f"Succès : {df.height} lignes insérées dans '{schema_name}.{table_name}'.")

        except Exception as e:
            logger.error(f"Erreur sur '{csv_file.name}': {e}")


def main():
    base_dir = Path(__file__).resolve().parent
    data_dir = base_dir / "data"

    # 1. Ingestion CRM
    process_directory(
        dir_path=data_dir / "crm",
        db_sqlalchemy_url=config.SRC_CRM_SQLALCHEMY_URL,
        schema_name=config.SRC_CRM_SCHEMA
    )

    # 2. Ingestion ERP
    process_directory(
        dir_path=data_dir / "erp",
        db_sqlalchemy_url=config.SRC_ERP_SQLALCHEMY_URL,
        schema_name=config.SRC_ERP_SCHEMA
    )

    logger.info("🎉 Ingestion terminée !")


if __name__ == "__main__":
    main()