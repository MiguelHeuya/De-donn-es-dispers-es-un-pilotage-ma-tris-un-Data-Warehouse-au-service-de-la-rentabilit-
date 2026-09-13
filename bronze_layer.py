from datetime import datetime
import logging
from urllib.parse import urlparse
import polars as pl
from sqlalchemy import text

from config import (
    BRONZE_SCHEMA,
    DATA_BASE_SOURCE_A_URI,
    DATA_BASE_SOURCE_B_URI,
    SOURCE_SCHEMA,
)

logger = logging.getLogger(__name__)

list_uri = [DATA_BASE_SOURCE_A_URI, DATA_BASE_SOURCE_B_URI]
schema_source = SOURCE_SCHEMA
schema_cible = BRONZE_SCHEMA


def bronze_layer(conn_dw):
    """
    Alimente la couche Bronze du Data Warehouse au sein d'une transaction active.
    
    :param conn_dw: Connexion SQLAlchemy transactionnelle active transmise par l'orchestrateur.
    """
    logger.info("================ Démarrage de l'ingestion Bronze ================")

    # 1. Préparation du schéma dans la transaction en cours (pas de commit isolé)
    conn_dw.execute(text(f"DROP SCHEMA IF EXISTS {schema_cible} CASCADE;"))
    conn_dw.execute(text(f"CREATE SCHEMA IF NOT EXISTS {schema_cible};"))

    logger.debug(f"Schéma '{schema_cible}' recréé et préparé dans la transaction.")

    for uri in list_uri:
        db_name = urlparse(uri).path[1:]
        logger.info(f"Traitement de la base source : {db_name}")

        query = f"""
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = '{schema_source}'
            AND table_type = 'BASE TABLE'
        """

        df_tables = pl.read_database_uri(query=query, uri=uri)
        list_tables = df_tables["table_name"].to_list()

        logger.debug(f"[{db_name}] {len(list_tables)} tables trouvées : {list_tables}")

        for table_name in list_tables:
            query_table = f"SELECT * FROM {schema_source}.{table_name}"

            # 1. Extraction
            df = pl.read_database_uri(query=query_table, uri=uri)

            # 2. Enrichissement
            df = df.with_columns(
                [
                    pl.lit(db_name).alias("_source_db"),
                    pl.lit(datetime.now()).alias("_ingested_at"),
                ]
            )

            # 3. Destination
            target_table_name = f"{db_name}_{table_name}"
            target_table_path = f"{schema_cible}.{target_table_name}"

            # 4. Chargement via la connexion transactionnelle transmise
            df.write_database(
                connection=conn_dw,
                table_name=target_table_path,
                if_table_exists="replace",
            )

            logger.debug(
                f"[{db_name}] Table '{table_name}' -> '{target_table_path}' ({df.height} lignes)."
            )

    logger.info("🚀 Couche Bronze alimentée en mémoire (en attente du commit global).")


if __name__ == "__main__":
    from sqlalchemy import create_engine
    from config import DATA_WAREHOUSE_SQLALCHEMY_URI, LOG_LEVEL

    logging.basicConfig(
        level=getattr(logging, LOG_LEVEL.upper(), logging.INFO),
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    # Exécution autonome avec sa propre transaction locale
    engine_dw = create_engine(DATA_WAREHOUSE_SQLALCHEMY_URI)
    with engine_dw.begin() as conn:
        bronze_layer(conn)