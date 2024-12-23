#!/bin/bash

# -----------------------------------------------------------------------------
# Script de déploiement automatisé pour une seconde instance Odoo 16 avec PostgreSQL 14
# Auteur       : Emac
# Date         : 2024-12-08
# Projet       : Installation d'une seconde instance Odoo 16 avec Docker
# Résumé       : Ce script configure automatiquement une nouvelle instance Docker
#                avec deux conteneurs : PostgreSQL 14 et Odoo 16. Les conteneurs
#                existants d'Odoo 17 et PostgreSQL 15 ne sont pas affectés.
# -----------------------------------------------------------------------------

# Couleurs pour les messages
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Fonction pour afficher un message de validation
success() { echo -e "${GREEN}[SUCCÈS] $1${NC}"; }
error() { echo -e "${RED}[ERREUR] $1${NC}"; exit 1; }

# Validation des entrées utilisateur
validate_input() {
    if [ -z "$1" ]; then
        error "Le champ $2 ne peut pas être vide."
    fi
}

# Collecte des informations utilisateur
read -p "Nom du répertoire projet (ex: odoo16_project) : " PROJECT_DIR
validate_input "$PROJECT_DIR" "Nom du répertoire projet"

read -p "Nom du conteneur PostgreSQL (ex: pg_odoo16) : " PG_CONTAINER_NAME
validate_input "$PG_CONTAINER_NAME" "Nom du conteneur PostgreSQL"

read -p "Port PostgreSQL (ex: 5443) : " PG_PORT
validate_input "$PG_PORT" "Port PostgreSQL"

read -p "Nom utilisateur PostgreSQL : " PG_USER
validate_input "$PG_USER" "Nom utilisateur PostgreSQL"

read -p "Mot de passe utilisateur PostgreSQL : " PG_PASSWORD
validate_input "$PG_PASSWORD" "Mot de passe utilisateur PostgreSQL"

read -p "Nom de la base de données PostgreSQL : " PG_DB_NAME
validate_input "$PG_DB_NAME" "Nom de la base de données"

read -p "Nom du conteneur Odoo (ex: odoo16) : " ODOO_CONTAINER_NAME
validate_input "$ODOO_CONTAINER_NAME" "Nom du conteneur Odoo"

read -p "Port Odoo (ex: 8070) : " ODOO_PORT
validate_input "$ODOO_PORT" "Port Odoo"

# Création du réseau Docker isolé pour cette instance
NETWORK_NAME="odoo16_network"
docker network create $NETWORK_NAME || success "Réseau Docker '$NETWORK_NAME' déjà existant."

# Création des répertoires pour Odoo
PROJECT_DIR=$(realpath "$PROJECT_DIR")
mkdir -p "$PROJECT_DIR/config" "$PROJECT_DIR/data" "$PROJECT_DIR/addons"
success "Répertoires projet créés avec succès."

# Création du fichier odoo.conf
cat > "$PROJECT_DIR/config/odoo.conf" <<EOL
[options]
addons_path = /mnt/extra-addons
data_dir = /var/lib/odoo
admin_passwd = admin
db_host = $PG_CONTAINER_NAME
db_port = $PG_PORT
db_user = $PG_USER
db_password = $PG_PASSWORD
db_name = $PG_DB_NAME
EOL
success "Fichier odoo.conf généré."

# Lancement du conteneur PostgreSQL 14
docker run -d \
  --name $PG_CONTAINER_NAME \
  --network $NETWORK_NAME \
  -e POSTGRES_USER=$PG_USER \
  -e POSTGRES_PASSWORD=$PG_PASSWORD \
  -e POSTGRES_DB=$PG_DB_NAME \
  -p $PG_PORT:5432 \
  postgres:14 || error "Erreur lors du démarrage du conteneur PostgreSQL."
success "Conteneur PostgreSQL ($PG_CONTAINER_NAME) démarré avec succès."

# Délai pour s'assurer que PostgreSQL est opérationnel
sleep 15
echo "Attente de 15 secondes pour permettre à PostgreSQL de démarrer."

# Lancement du conteneur Odoo 16
docker run -d \
  --name $ODOO_CONTAINER_NAME \
  --network $NETWORK_NAME \
  -p $ODOO_PORT:8069 \
  -v "$PROJECT_DIR/config:/etc/odoo" \
  -v "$PROJECT_DIR/data:/var/lib/odoo" \
  -v "$PROJECT_DIR/addons:/mnt/extra-addons" \
  odoo:16.0 || error "Erreur lors du démarrage du conteneur Odoo."
success "Conteneur Odoo ($ODOO_CONTAINER_NAME) démarré avec succès."

# Test de la connexion entre Odoo et PostgreSQL
echo "Vérification de la connexion entre Odoo et PostgreSQL..."
docker exec -it $ODOO_CONTAINER_NAME bash -c "pg_isready -h $PG_CONTAINER_NAME -p $PG_PORT -U $PG_USER" || error "Connexion échouée entre Odoo et PostgreSQL."
success "Connexion réussie entre Odoo et PostgreSQL."

# Initialisation de la base de données avec Odoo
echo "Initialisation de la base de données..."
docker exec -it $ODOO_CONTAINER_NAME bash -c "odoo --init=base --db_host=$PG_CONTAINER_NAME --db_port=5432 --db_user=$PG_USER --db_password=$PG_PASSWORD --db_name=$PG_DB_NAME" || error "Erreur lors de l'initialisation de la base de données."
success "Base de données initialisée avec succès."

# Résumé des informations de configuration
cat <<EOF
-----------------------------------------
Installation terminée avec succès !
Accédez à Odoo via : http://localhost:$ODOO_PORT
Nom utilisateur PostgreSQL : $PG_USER
Nom base de données : $PG_DB_NAME
Répertoire projet : $PROJECT_DIR
Réseau Docker : $NETWORK_NAME
-----------------------------------------
EOF
