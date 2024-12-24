#!/bin/bash

#-----------------------------INSTRUCTIONS A SUIVRE------------------------------------------------------

# Instruction script d'installation:
#-Se conncecter sur docker desktop
#-Ouvrir le terminal de commande juste en dessous selon votre version
#-saisir la commande : git clone -b image_odoo_emacsah https://github.com/EmacSah/odoo.git
#git clone --branch Final_install --single-branch https://github.com/EmacSah/odoo.git
#-Une fois le depot cloné, deplacez vous dans le depôt cloné : Cd ./odoo
#- Saisir la commande d'attribution des droits : chmod +x docker_desktop_deploy_odoo_emac.sh
#- Ensuite saisir la commande pour lancer le script : ./odoo_bot.sh
#- Tu vas renseigner tes différents paramètres au fur et à mésure pour personnaliser ton installation.

#--------------------------- Gestion erreur d'installation ----------------------------------------------------
# - Erreur de connectivité entre le conteneur Odoo et Postgresql : verifier les configuration réseau
# - exécuter la commande : docker network inspect bridge :
# - vérifier dans la section container si les conatiner existent et si les noms des containers correspondent
# a ceux que vous aviez configurez dans vos variables.
#-------------------------------------------------------------------------------------------------------




# Couleurs pour les messages
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Fonctions pour les messages
success() {
    echo -e "${GREEN}[SUCCÈS] $1${NC}"
}

error() {
    echo -e "${RED}[ERREUR] $1${NC}"
    exit 1
}

# Variables par défaut
DEFAULT_PROJECT_DIR="odoo_project"
DEFAULT_ODOO_VERSION="16.0"
DEFAULT_POSTGRES_VERSION="14"
DEFAULT_DB_NAME="odoo_db16"
DEFAULT_DB_USER="odoo_user"
DEFAULT_DB_PASSWORD="odoo_pass"
DEFAULT_ODOO_PORT="8079"
DEFAULT_POSTGRES_PORT="5434"

# Demande des variables utilisateur
echo "=== Configuration des variables ==="
read -p "Entrez le répertoire du projet (par défaut : $DEFAULT_PROJECT_DIR): " PROJECT_DIR
PROJECT_DIR=${PROJECT_DIR:-$DEFAULT_PROJECT_DIR}

read -p "Entrez la version d'Odoo à installer (par défaut : $DEFAULT_ODOO_VERSION): " ODOO_VERSION
ODOO_VERSION=${ODOO_VERSION:-$DEFAULT_ODOO_VERSION}

read -p "Entrez la version de PostgreSQL à installer (par défaut : $DEFAULT_POSTGRES_VERSION): " POSTGRES_VERSION
POSTGRES_VERSION=${POSTGRES_VERSION:-$DEFAULT_POSTGRES_VERSION}

read -p "Entrez le nom de la base de données PostgreSQL (par défaut : $DEFAULT_DB_NAME): " DB_NAME
DB_NAME=${DB_NAME:-$DEFAULT_DB_NAME}

read -p "Entrez l'utilisateur de la base de données PostgreSQL (par défaut : $DEFAULT_DB_USER): " DB_USER
DB_USER=${DB_USER:-$DEFAULT_DB_USER}

read -p "Entrez le mot de passe de la base de données PostgreSQL (par défaut : $DEFAULT_DB_PASSWORD): " DB_PASSWORD
DB_PASSWORD=${DB_PASSWORD:-$DEFAULT_DB_PASSWORD}

read -p "Entrez le port pour Odoo (par défaut : $DEFAULT_ODOO_PORT): " ODOO_PORT
ODOO_PORT=${ODOO_PORT:-$DEFAULT_ODOO_PORT}

read -p "Entrez le port pour PostgreSQL (par défaut : $DEFAULT_POSTGRES_PORT): " POSTGRES_PORT
POSTGRES_PORT=${POSTGRES_PORT:-$DEFAULT_POSTGRES_PORT}

# Vérification des ports
if netstat -tuln | grep -q ":$ODOO_PORT\|:$POSTGRES_PORT"; then
    error "Les ports $ODOO_PORT ou $POSTGRES_PORT sont déjà utilisés. Modifiez les ports et relancez le script."
fi
success "Les ports $ODOO_PORT et $POSTGRES_PORT sont disponibles."

# Création du répertoire projet
mkdir -p $PROJECT_DIR/{config,extra-addons}
cd $PROJECT_DIR || error "Impossible de créer ou accéder au répertoire projet : $PROJECT_DIR"

# Gestion des droits d'accès sur le répertoire projet
chmod -R 755 $PROJECT_DIR
success "Répertoire projet créé avec succès : $PROJECT_DIR"

# Création du fichier de configuration d'Odoo
cat > config/odoo.conf <<EOL
[options]
addons_path = /mnt/extra-addons
db_host = postgres
db_port = 5432
db_user = $DB_USER
db_password = $DB_PASSWORD
db_name = $DB_NAME
xmlrpc_interface = 0.0.0.0
xmlrpc_port = 8069
EOL
chmod 644 config/odoo.conf
success "Fichier de configuration Odoo créé : config/odoo.conf"

# Création du fichier docker-compose.yml
cat > docker-compose.yml <<EOL
version: '3.8'

services:
  postgres:
    image: postgres:$POSTGRES_VERSION
    container_name: postgres_$POSTGRES_VERSION
    environment:
      POSTGRES_DB: $DB_NAME
      POSTGRES_USER: $DB_USER
      POSTGRES_PASSWORD: $DB_PASSWORD
    ports:
      - "$POSTGRES_PORT:5432"
    volumes:
      - pg_data:/var/lib/postgresql/data
    networks:
      - odoo_network

  odoo:
    image: odoo:$ODOO_VERSION
    container_name: odoo_$ODOO_VERSION
    depends_on:
      - postgres
    ports:
      - "$ODOO_PORT:8069"
    volumes:
      - ./config:/etc/odoo
      - ./extra-addons:/mnt/extra-addons
    environment:
      HOST: postgres
      USER: $DB_USER
      PASSWORD: $DB_PASSWORD
      DATABASE: $DB_NAME
    networks:
      - odoo_network

volumes:
  pg_data:
  odoo_data:

networks:
  odoo_network:
EOL
chmod 644 docker-compose.yml
success "Fichier docker-compose.yml créé."

# Démarrage des conteneurs avec Docker Compose
docker-compose up -d
if [[ $? -ne 0 ]]; then
    error "Échec du démarrage des conteneurs. Vérifiez votre configuration."
fi
success "Conteneurs Odoo et PostgreSQL démarrés avec succès."

# Test de connectivité entre Odoo et PostgreSQL
docker exec postgres_$POSTGRES_VERSION psql -U $DB_USER -c "\l" &>/dev/null
if [[ $? -ne 0 ]]; then
    error "Échec de la connectivité réseau entre Odoo et PostgreSQL. Vérifiez les logs des conteneurs."
fi
success "Connectivité entre Odoo et PostgreSQL validée."

# Initialisation de la base de données Odoo
docker exec odoo_$ODOO_VERSION odoo --db_host=postgres --db_user=$DB_USER --db_password=$DB_PASSWORD -d $DB_NAME -i base
if [[ $? -ne 0 ]]; then
    error "Échec de l'initialisation de la base de données Odoo."
fi
success "Base de données Odoo initialisée avec succès."

# Affichage des informations de connexion
echo -e "${GREEN}Déploiement terminé avec succès !${NC}"
echo -e "URL Odoo : http://localhost:$ODOO_PORT"
echo -e "Identifiants par défaut : admin / admin"
