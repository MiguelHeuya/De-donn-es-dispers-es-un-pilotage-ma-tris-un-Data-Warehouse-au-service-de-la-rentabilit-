import os
from urllib.parse import quote_plus
from dotenv import load_dotenv

# Charger les variables du fichier .env situe dans le meme dossier
load_dotenv()

def build_db_url(prefix: str, include_driver: bool = False) -> str:
    """
    Construit une URL de connexion PostgreSQL.
    - include_driver=False : Format 'postgresql://' (ConnectorX, psycopg2 brut)
    - include_driver=True  : Format 'postgresql+psycopg2://' (SQLAlchemy)
    """
    db_type = os.getenv(f"{prefix}_TYPE", "postgresql").lower()
    host = os.getenv(f"{prefix}_HOST", "localhost")
    port = os.getenv(f"{prefix}_PORT", "5432")
    name = os.getenv(f"{prefix}_NAME", "")
    user = os.getenv(f"{prefix}_USER", "")
    password = os.getenv(f"{prefix}_PASSWORD", "")

    # Encodage du mot de passe pour eviter les erreurs si caracteres speciaux
    safe_password = quote_plus(password) if password else ""
    driver_str = "+psycopg2" if include_driver else ""

    # Ajout du paramètre SSL pour les serveurs distants/cloud (Neon, AWS, etc.)
    is_cloud_host = any(cloud_keyword in host for cloud_keyword in ["neon.tech", "aws", "rds", "render", "azure"])
    ssl_param = "?sslmode=require" if is_cloud_host else ""

    return f"{db_type}{driver_str}://{user}:{safe_password}@{host}:{port}/{name}{ssl_param}"


# ==============================================================================
# CONFIGURATION GENERALE
# ==============================================================================
APP_ENV = os.getenv("APP_ENV", "development")
APP_NAME = os.getenv("APP_NAME", "DataPipeline")
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")


# ==============================================================================
# 1. SOURCE CRM
# ==============================================================================
SRC_CRM_SCHEMA = os.getenv("SRC_CRM_SCHEMA", "oltp")

# Compatible avec ConnectorX et psycopg2.connect()
SRC_CRM_URL = build_db_url("SRC_CRM", include_driver=False)

# Compatible avec SQLAlchemy create_engine()
SRC_CRM_SQLALCHEMY_URL = build_db_url("SRC_CRM", include_driver=True)


# ==============================================================================
# 2. SOURCE ERP
# ==============================================================================
SRC_ERP_SCHEMA = os.getenv("SRC_ERP_SCHEMA", "oltp")

SRC_ERP_URL = build_db_url("SRC_ERP", include_driver=False)
SRC_ERP_SQLALCHEMY_URL = build_db_url("SRC_ERP", include_driver=True)


# ==============================================================================
# 3. DATA WAREHOUSE (DWH)
# ==============================================================================
DWH_SCHEMA_BRONZE = os.getenv("DWH_SCHEMA_BRONZE", "bronze")
DWH_SCHEMA_SILVER = os.getenv("DWH_SCHEMA_SILVER", "silver")
DWH_SCHEMA_GOLD = os.getenv("DWH_SCHEMA_GOLD", "gold")

DWH_URL = build_db_url("DWH", include_driver=False)
DWH_SQLALCHEMY_URL = build_db_url("DWH", include_driver=True)


# ==============================================================================
# PARAMETRES PIPELINE
# ==============================================================================
BATCH_SIZE = int(os.getenv("BATCH_SIZE", 10000))
MAX_RETRIES = int(os.getenv("MAX_RETRIES", 3))