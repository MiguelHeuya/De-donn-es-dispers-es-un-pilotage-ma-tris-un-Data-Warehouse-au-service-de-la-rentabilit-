-- ==================================================================================================
-- PIPELINE : BRONZE -> SILVER (Mode Pass-Through / Transfert Direct)
-- SCRIPT   : Re-modélisation de la table des catégories ("Silver"."px_cat_g1v2")
-- OBJECTIF : Intégrer les données de référence telles quelles, sans transformation, dans le schéma Silver
-- ==================================================================================================

-- 1. NETTOYAGE DU SCHEMA (IDEMPOTENCE)
-- Supprime la table Silver existante pour garantir un rafraîchissement complet (Full Refresh)
-- et éviter les erreurs de doublons lors de la ré-exécution du pipeline.
DROP TABLE IF EXISTS "Silver"."px_cat_g1v2" CASCADE; 

-- 2. DUPLICATION ET STRUCTURATION EN COUCHE SILVER
-- Crée la table Silver physique. Bien qu'aucune transformation textuelle ou numérique 
-- ne soit requise ici, cette étape est cruciale pour centraliser toutes les tables au même niveau 
-- de disponibilité pour la couche Gold.
CREATE TABLE "Silver"."px_cat_g1v2" AS
(
    SELECT
        id,          -- Identifiant unique de la catégorie
        cat,         -- Libellé de la catégorie principale
        subcat,      -- Libellé de la sous-catégorie
        maintenance  -- Indicateur ou statut lié à la maintenance
    FROM "Bronze"."px_cat_g1v2"
);