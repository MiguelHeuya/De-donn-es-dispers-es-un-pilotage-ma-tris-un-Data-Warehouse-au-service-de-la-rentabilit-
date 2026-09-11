import os
from dotenv import load_dotenv

load_dotenv()

# Charger les variables d'environnement depuis le fichier .env

# Configuration de la base de données source A

DATA_BASE_SOURCE_A_NAME = os.getenv("DATA_BASE_SOURCE_A_NAME")
DATA_BASE_SOURCE_A_USER = os.getenv("DATA_BASE_SOURCE_A_USER")
DATA_BASE_SOURCE_A_PASSWORD = os.getenv("DATA_BASE_SOURCE_A_PASSWORD")
DATA_BASE_SOURCE_A_HOST = os.getenv("DATA_BASE_SOURCE_A_HOST", "localhost")
DATA_BASE_SOURCE_A_PORT = int(os.getenv("DATA_BASE_SOURCE_A_PORT", 5432))


# Configuration de la base de données source B

DATA_BASE_SOURCE_B_NAME = os.getenv("DATA_BASE_SOURCE_B_NAME")
DATA_BASE_SOURCE_B_USER = os.getenv("DATA_BASE_SOURCE_B_USER")
DATA_BASE_SOURCE_B_PASSWORD = os.getenv("DATA_BASE_SOURCE_B_PASSWORD")
DATA_BASE_SOURCE_B_HOST = os.getenv("DATA_BASE_SOURCE_B_HOST", "localhost")
DATA_BASE_SOURCE_B_PORT = int(os.getenv("DATA_BASE_SOURCE_B_PORT", 5432))

# Configuration de la base de données cible

DATA_WAREHOUSE_NAME = os.getenv("DATA_WAREHOUSE_NAME")
DATA_WAREHOUSE_USER = os.getenv("DATA_WAREHOUSE_USER")
DATA_WAREHOUSE_PASSWORD = os.getenv("DATA_WAREHOUSE_PASSWORD")
DATA_WAREHOUSE_HOST = os.getenv("DATA_WAREHOUSE_HOST", "localhost")
DATA_WAREHOUSE_PORT = int(os.getenv("DATA_WAREHOUSE_PORT", 5432))



# Création des éléments de connexion, chaine de connexion et autres paramètres de connexion pour les bases de données source A, source B et la base de données cible


DATA_WAREHOUSE_CONNEXION_DIC = {
    "dbname": DATA_WAREHOUSE_NAME,
    "user": DATA_WAREHOUSE_USER, 
    "password": DATA_WAREHOUSE_PASSWORD,
    "host": DATA_WAREHOUSE_HOST,
    "port": DATA_WAREHOUSE_PORT
}

DATA_BASE_SOURCE_A_CONNEXION_DIC = {
    "dbname": DATA_BASE_SOURCE_A_NAME,
    "user": DATA_BASE_SOURCE_A_USER, 
    "password": DATA_BASE_SOURCE_A_PASSWORD,
    "host": DATA_BASE_SOURCE_A_HOST,
    "port": DATA_BASE_SOURCE_A_PORT
}

DATA_BASE_SOURCE_B_CONNEXION_DIC = {
    "dbname": DATA_BASE_SOURCE_B_NAME,
    "user": DATA_BASE_SOURCE_B_USER, 
    "password": DATA_BASE_SOURCE_B_PASSWORD,
    "host": DATA_BASE_SOURCE_B_HOST,
    "port": DATA_BASE_SOURCE_B_PORT
}

# Créátion des chaines de connexion URI pour les bases de données source A, source B et la base de données cible

# --- Format Standard URI (Polars, psycopg, ConnectorX) ---

DATA_WAREHOUSE_URI = f"postgresql://{DATA_WAREHOUSE_USER}:{DATA_WAREHOUSE_PASSWORD}@{DATA_WAREHOUSE_HOST}:{DATA_WAREHOUSE_PORT}/{DATA_WAREHOUSE_NAME}"

DATA_BASE_SOURCE_A_URI = f"postgresql://{DATA_BASE_SOURCE_A_USER}:{DATA_BASE_SOURCE_A_PASSWORD}@{DATA_BASE_SOURCE_A_HOST}:{DATA_BASE_SOURCE_A_PORT}/{DATA_BASE_SOURCE_A_NAME}"

DATA_BASE_SOURCE_B_URI = f"postgresql://{DATA_BASE_SOURCE_B_USER}:{DATA_BASE_SOURCE_B_PASSWORD}@{DATA_BASE_SOURCE_B_HOST}:{DATA_BASE_SOURCE_B_PORT}/{DATA_BASE_SOURCE_B_NAME}"


# --- Format SQLAlchemy URI (avec driver psycopg2) ---

DATA_WAREHOUSE_SQLALCHEMY_URI = f"postgresql+psycopg2://{DATA_WAREHOUSE_USER}:{DATA_WAREHOUSE_PASSWORD}@{DATA_WAREHOUSE_HOST}:{DATA_WAREHOUSE_PORT}/{DATA_WAREHOUSE_NAME}"

DATA_BASE_SOURCE_A_SQLALCHEMY_URI = f"postgresql+psycopg2://{DATA_BASE_SOURCE_A_USER}:{DATA_BASE_SOURCE_A_PASSWORD}@{DATA_BASE_SOURCE_A_HOST}:{DATA_BASE_SOURCE_A_PORT}/{DATA_BASE_SOURCE_A_NAME}"

DATA_BASE_SOURCE_B_SQLALCHEMY_URI = f"postgresql+psycopg2://{DATA_BASE_SOURCE_B_USER}:{DATA_BASE_SOURCE_B_PASSWORD}@{DATA_BASE_SOURCE_B_HOST}:{DATA_BASE_SOURCE_B_PORT}/{DATA_BASE_SOURCE_B_NAME}"

# --- Configurations des Schémas (Architecture Medallion) ---
SOURCE_SCHEMA = os.getenv("SOURCE_SCHEMA", "oltp")
BRONZE_SCHEMA = os.getenv("BRONZE_SCHEMA", "bronze")
SILVER_SCHEMA = os.getenv("SILVER_SCHEMA", "silver")
GOLD_SCHEMA = os.getenv("GOLD_SCHEMA", "gold")

# --- Environment & Logging ---
NODE_ENV = os.getenv("NODE_ENV", "development")
LOG_LEVEL = os.getenv("LOG_LEVEL", "info").upper()