#!/bin/bash

# Couleurs pour les messages
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Variables configurables
PROJECT_NAME="new_odoo_instance"
BASE_DIR="/home/$USER/$PROJECT_NAME"
ODOO_CONTAINER="new_odoo_web"
POSTGRES_CONTAINER="new_pg_db"
DB_NAME="new_odoo_db"
DB_USER="new_odoo_user"
DB_PASSWORD="new_odoo_password"
NETWORK_NAME="odoo-network"
ODOO_VERSION="16"  # Vous pouvez changer cette variable pour une autre version d'Odoo

# Fonction pour afficher un message de validation
success() {
    echo -e "${GREEN}[SUCCÈS] $1${NC}"
}

# Fonction pour afficher un message d'erreur
error() {
    echo -e "${RED}[ERREUR] $1${NC}"
    exit 1
}

# Fonction pour vérifier une commande et afficher un message personnalisé
check_command() {
    if eval "$1"; then
        success "$2"
    else
        error "$3"
    fi
}

echo "== Début du déploiement d'une nouvelle instance d'Odoo =="

# 1. Création de la structure du projet
echo "Création de la structure du projet..."
check_command "mkdir -p $BASE_DIR/{config,extra-addons,data}" \
    "Répertoires créés avec succès." \
    "Erreur lors de la création des répertoires."

# Vérification des droits
echo "Attribution des droits sur les répertoires..."
check_command "chmod -R 755 $BASE_DIR && chown -R $USER:$USER $BASE_DIR" \
    "Droits attribués avec succès." \
    "Erreur lors de l'attribution des droits."

# 2. Création et configuration du fichier odoo.conf
tee $BASE_DIR/config/odoo.conf > /dev/null <<EOL
[options]
addons_path = /mnt/extra-addons
db_host = $POSTGRES_CONTAINER
db_port = 5432
db_user = $DB_USER
db_password = $DB_PASSWORD
db_name = $DB_NAME
xmlrpc_interface = 0.0.0.0
EOL
success "Fichier odoo.conf créé."

# 3. Création et configuration du Dockerfile
tee $BASE_DIR/Dockerfile > /dev/null <<EOL
FROM odoo:$ODOO_VERSION
COPY ./config /etc/odoo
EOL
success "Dockerfile créé."

# 4. Création et configuration du fichier docker-compose.yml
tee $BASE_DIR/docker-compose.yml > /dev/null <<EOL
version: '3.7'

services:
  $POSTGRES_CONTAINER:
    image: postgres:14
    container_name: $POSTGRES_CONTAINER
    environment:
      POSTGRES_DB: $DB_NAME
      POSTGRES_USER: $DB_USER
      POSTGRES_PASSWORD: $DB_PASSWORD
    volumes:
      - ./data:/var/lib/postgresql/data
    networks:
      - $NETWORK_NAME

  $ODOO_CONTAINER:
    build: .
    container_name: $ODOO_CONTAINER
    ports:
      - "8070:8069"  # Utilisez un port différent pour éviter les conflits
    volumes:
      - ./config:/etc/odoo
      - ./extra-addons:/mnt/extra-addons
    depends_on:
      - $POSTGRES_CONTAINER
    networks:
      - $NETWORK_NAME

networks:
  $NETWORK_NAME:
    driver: bridge
EOL
success "Fichier docker-compose.yml créé."

# 5. Positionnement dans le répertoire et démarrage des conteneurs Docker
echo "Démarrage des conteneurs..."
cd $BASE_DIR

# Vérifiez si le répertoire existe
if [ ! -d "$BASE_DIR" ]; then
    error "Le répertoire $BASE_DIR n'existe pas."
fi

# Vérifiez les permissions
if [ ! -w "$BASE_DIR" ]; then
    error "Permissions insuffisantes pour écrire dans le répertoire $BASE_DIR."
fi

# Vérifiez les fichiers de configuration
if [ ! -f "$BASE_DIR/docker-compose.yml" ]; then
    error "Le fichier docker-compose.yml n'existe pas dans $BASE_DIR."
fi

if [ ! -f "$BASE_DIR/Dockerfile" ]; then
    error "Le fichier Dockerfile n'existe pas dans $BASE_DIR."
fi

# Exécutez les commandes Docker Compose avec des messages de débogage
echo "Exécution de la commande : docker compose down"
if ! docker compose down; then
    error "Erreur lors de l'exécution de la commande : docker compose down"
fi

echo "Exécution de la commande : docker compose up -d"
if ! docker compose up -d; then
    error "Erreur lors de l'exécution de la commande : docker compose up -d"
fi

success "Conteneurs démarrés avec succès."

# 6. Initialisation de la base de données dans Odoo
echo "Validation de l'existence de la base de données PostgreSQL..."

# Vérifier si la base de données existe
DB_EXISTS=$(docker exec -it $POSTGRES_CONTAINER psql -U $DB_USER -tc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME';" | tr -d '[:space:]')

if [[ "$DB_EXISTS" == "1" ]]; then
    success "La base de données '$DB_NAME' existe déjà."
else
    echo "La base de données '$DB_NAME' n'existe pas. Création en cours..."
    docker exec -it $POSTGRES_CONTAINER psql -U $DB_USER -c "CREATE DATABASE $DB_NAME;"
    if [[ $? -eq 0 ]]; then
        success "Base de données '$DB_NAME' créée avec succès."
        echo "Attribution des privilèges à l'utilisateur '$DB_USER'..."
        docker exec -it $POSTGRES_CONTAINER psql -U $DB_USER -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
        if [[ $? -eq 0 ]]; then
            success "Privilèges attribués avec succès à l'utilisateur '$DB_USER'."
        else
            error "Erreur lors de l'attribution des privilèges à l'utilisateur '$DB_USER'."
        fi
    else
        error "Erreur lors de la création de la base de données '$DB_NAME'."
    fi
fi

# Lister les bases de données pour confirmation
echo "Liste des bases de données existantes :"
docker exec -it $POSTGRES_CONTAINER psql -U $DB_USER -c "\l"

success "Validation et gestion de la base de données terminées."

init_database() {
    echo "Tentative d'initialisation de la base de données avec Odoo..."

    # Première tentative d'initialisation
    docker exec -it "$ODOO_CONTAINER" odoo --db_host="$POSTGRES_CONTAINER" --db_user="$DB_USER" --db_password="$DB_PASSWORD" -d "$DB_NAME" -i base &>/dev/null
    if [ $? -eq 0 ]; then
        success "Initialisation de la base de données réussie."
        return 0
    fi

    # Si la première tentative échoue, on tente manuellement
    echo "Échec de la première tentative. Tentative d'initialisation manuelle..."
    docker exec -it "$ODOO_CONTAINER" bash -c "odoo --init=base --database=$DB_NAME" &>/dev/null
    if [ $? -eq 0 ]; then
        success "Initialisation manuelle de la base de données réussie."
        return 0
    fi

    # Si tout échoue, on retourne une erreur
    error "Échec de l'initialisation de la base de données. Veuillez vérifier les journaux et la configuration."
}

# Vérification de la connexion à PostgreSQL
check_pg_connection() {
    echo "Vérification de la connexion à PostgreSQL..."
    docker exec -it "$POSTGRES_CONTAINER" psql -U "$DB_USER" -c '\l' &>/dev/null
    if [ $? -eq 0 ]; then
        success "Connexion à PostgreSQL réussie."
        init_database
    else
        error "Connexion à PostgreSQL échouée. Vérifiez que le service est en cours d'exécution et que les paramètres sont corrects."
    fi
}

# Étape : Vérifie que PostgreSQL est actif avant de tenter l'initialisation
check_pg_connection

# Si tout est bon, continuer le script
success "La base de données est prête. Continuité du script."

# 7. Vérification de l'état des services
echo "Vérification des services..."
docker ps && success "Services Odoo et PostgreSQL actifs."

# 8. Test du port HTTP
echo "Test du port HTTP..."
check_command "curl -s http://127.0.0.1:8070" \
    "Port HTTP testé avec succès. Odoo est accessible." \
    "Erreur lors du test du port HTTP."

# 9. Informations de connexion
echo "Lien d'accès à l'application Odoo :"
echo "URL : http://<IP_PUBLIQUE_VM>:8070"
echo "Identifiants par défaut :"
echo "Utilisateur : admin"
echo "Mot de passe : admin"

success "Installation complète et fonctionnelle !"
