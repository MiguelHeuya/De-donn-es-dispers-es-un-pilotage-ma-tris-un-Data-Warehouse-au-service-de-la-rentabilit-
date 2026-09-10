import time
import logging
from datetime import datetime
from pathlib import Path
import polars as pl
from sqlalchemy import create_engine, text
import config

# ------------------------------------------------------------------------------
# CONFIGURATION DES LOGS ESTHÉTIQUES
# ------------------------------------------------------------------------------
LOG_DIR = Path(__file__).resolve().parent / "logs"
LOG_DIR.mkdir(exist_ok=True)

timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
log_filename = LOG_DIR / f"ingest_bronze_{timestamp}.log"

# Format épuré et aligné
log_format = logging.Formatter(
    fmt="%(asctime)s | %(levelname)-7s | %(message)s",
    datefmt="%H:%M:%S"
)

console_handler = logging.StreamHandler()
console_handler.setFormatter(log_format)

file_handler = logging.FileHandler(log_filename, encoding="utf-8")
file_handler.setFormatter(log_format)

logger = logging.getLogger(config.APP_NAME)
logger.setLevel(getattr(logging, config.LOG_LEVEL.upper(), logging.INFO))
logger.addHandler(console_handler)
logger.addHandler(file_handler)


def ensure_schema_exists(engine, schema_name: str):
    """S'assure que le schéma destination existe dans le DWH."""
    with engine.connect() as conn:
        conn.execute(text(f"CREATE SCHEMA IF NOT EXISTS {schema_name};"))
        conn.commit()


def get_table_names(sqlalchemy_url: str, schema_name: str) -> list[str]:
    """Récupère la liste des tables d'un schéma source."""
    query = text("""
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = :schema AND table_type = 'BASE TABLE';
    """)
    engine = create_engine(sqlalchemy_url)
    with engine.connect() as conn:
        result = conn.execute(query, {"schema": schema_name})
        return [row[0] for row in result.fetchall()]


def ingest_source_to_bronze(source_name: str, src_url: str, src_sqlalchemy_url: str, src_schema: str):
    """Extrait les tables d'une source vers Bronze avec logs animés."""
    start_source = time.perf_counter()
    
    logger.info("┌" + "─" * 60 + "┐")
    logger.info(f"│ 🔌 SOURCE : {source_name.upper():<48} │")
    logger.info("└" + "─" * 60 + "┘")

    tables = get_table_names(src_sqlalchemy_url, src_schema)
    if not tables:
        logger.warning(f"⚠️  Aucune table trouvée dans '{source_name}'. Étape ignorée.")
        return

    logger.info(f"📋 Tables détectées ({len(tables)}) : {', '.join(tables)}")

    dwh_engine = create_engine(config.DWH_SQLALCHEMY_URL)
    ensure_schema_exists(dwh_engine, config.DWH_SCHEMA_BRONZE)

    total_rows = 0

    for table in tables:
        target_table_name = f"{source_name}_{table}".lower()
        full_target = f"{config.DWH_SCHEMA_BRONZE}.{target_table_name}"
        
        logger.info(f"⚡ Ingestion : {src_schema}.{table}  ➔  {full_target}")
        start_table = time.perf_counter()

        try:
            # 1. Extraction (Read)
            t_read = time.perf_counter()
            df = pl.read_database_uri(query=f"SELECT * FROM {src_schema}.{table}", uri=src_url, engine="connectorx")
            read_duration = time.perf_counter() - t_read

            if df.is_empty():
                logger.warning(f"  └── 📭 Table vide (0 ligne). Ignorée.")
                continue

            num_rows = df.height
            total_rows += num_rows

            # 2. Écriture DWH (Write)
            t_write = time.perf_counter()
            df.write_database(
                table_name=full_target,
                connection=config.DWH_SQLALCHEMY_URL,
                engine="sqlalchemy",
                if_table_exists="replace"
            )
            write_duration = time.perf_counter() - t_write
            total_duration = time.perf_counter() - start_table
            
            throughput = num_rows / total_duration if total_duration > 0 else 0

            # Log de succès détaillé et stylisé
            logger.info(
                f"  └── ✅ Succès ! {num_rows:,} lignes ({df.width} cols) "
                f"| 📥 Lit: {read_duration:.2f}s | 📤 Écrit: {write_duration:.2f}s "
                f"| 🚀 Débit: {throughput:,.0f} l/s"
            )

        except Exception as e:
            logger.error(f"  └── ❌ ÉCHEC sur '{table}' : {e}")

    source_duration = time.perf_counter() - start_source
    logger.info(f"✨ Bilan {source_name.upper()} : {total_rows:,} lignes chargées en {source_duration:.2f}s\n")


def main():
    pipeline_start = time.perf_counter()

    logger.info("=" * 62)
    logger.info(f"🚀 DÉMARRAGE DU PIPELINE BRONZE [{config.APP_NAME}]")
    logger.info(f"📅 Date : {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    logger.info(f"📂 Log  : {log_filename.name}")
    logger.info("=" * 62 + "\n")

    # 1. CRM -> Bronze
    ingest_source_to_bronze(
        source_name="crm",
        src_url=config.SRC_CRM_URL,
        src_sqlalchemy_url=config.SRC_CRM_SQLALCHEMY_URL,
        src_schema=config.SRC_CRM_SCHEMA
    )

    # 2. ERP -> Bronze
    ingest_source_to_bronze(
        source_name="erp",
        src_url=config.SRC_ERP_URL,
        src_sqlalchemy_url=config.SRC_ERP_SQLALCHEMY_URL,
        src_schema=config.SRC_ERP_SCHEMA
    )

    duration = time.perf_counter() - pipeline_start
    logger.info("=" * 62)
    logger.info(f"🎉 PIPELINE BRONZE TERMINÉ AVEC SUCCÈS (Temps total : {duration:.2f}s)")
    logger.info("=" * 62)


if __name__ == "__main__":
    main()