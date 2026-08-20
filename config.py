import os
from urllib.parse import quote_plus
from dotenv import load_dotenv

# Charge les variables d'environnement depuis le fichier .env (même répertoire)
load_dotenv()

def build_db_url(prefix: str, include_driver: bool = False) -> str:
    """
    Construit une URL de connexion réseau à partir des variables .env.
    
    Args:
        prefix (str): Le préfixe de la BDD dans le .env (ex: 'SRC_CRM', 'SRC_ERP', 'DWH')
        include_driver (bool): Si True, ajoute '+psycopg2' pour SQLAlchemy.
                               Si False, génère le format URI standard 'postgresql://'
    """
    db_type = os.getenv(f"{prefix}_TYPE", "postgresql").lower()
    host = os.getenv(f"{prefix}_HOST", "localhost")
    port = os.getenv(f"{prefix}_PORT", "5432")
    name = os.getenv(f"{prefix}_NAME", "")
    user = os.getenv(f"{prefix}_USER", "")
    password = os.getenv(f"{prefix}_PASSWORD", "")

    # quote_plus garantit la sécurité si le mot de passe contient des caractères spéciaux (@, #, /, etc.)
    safe_password = quote_plus(password) if password else ""

    driver_str = "+psycopg2" if include_driver else ""

    # Format de sortie: postgresql://user:password@host:port/dbname
    return f"{db_type}{driver_str}://{user}:{safe_password}@{host}:{port}/{name}"


# ==============================================================================
# CONFIGURATION GÉNÉRALE
# ==============================================================================
APP_ENV = os.getenv("APP_ENV", "development")
APP_NAME = os.getenv("APP_NAME", "DataPipeline")
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")


# ==============================================================================
# SOURCE 1 : CRM
# ==============================================================================
SRC_CRM_SCHEMA = os.getenv("SRC_CRM_SCHEMA", "public")

# URL Standard (pour ConnectorX et psycopg2.connect)
SRC_CRM_URL = build_db_url("SRC_CRM", include_driver=False)

# URL SQLAlchemy (pour create_engine)
SRC_CRM_SQLALCHEMY_URL = build_db_url("SRC_CRM", include_driver=True)


# ==============================================================================
# SOURCE 2 : ERP
# ==============================================================================
SRC_ERP_SCHEMA = os.getenv("SRC_ERP_SCHEMA", "public")

SRC_ERP_URL = build_db_url("SRC_ERP", include_driver=False)
SRC_ERP_SQLALCHEMY_URL = build_db_url("SRC_ERP", include_driver=True)


# ==============================================================================
# DATA WAREHOUSE (DWH)
# ==============================================================================
DWH_SCHEMA_BRONZE = os.getenv("DWH_SCHEMA_BRONZE", "bronze")
DWH_SCHEMA_SILVER = os.getenv("DWH_SCHEMA_SILVER", "silver")
DWH_SCHEMA_GOLD = os.getenv("DWH_SCHEMA_GOLD", "gold")

DWH_URL = build_db_url("DWH", include_driver=False)
DWH_SQLALCHEMY_URL = build_db_url("DWH", include_driver=True)


# ==============================================================================
# PARAMÈTRES PIPELINE (Exécution en Production)
# ==============================================================================

BATCH_SIZE = int(os.getenv("BATCH_SIZE", 10000))
MAX_RETRIES = int(os.getenv("MAX_RETRIES", 3))