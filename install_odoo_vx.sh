#!/bin/bash

# Couleurs pour les messages
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color


# Fichier de log
LOG_FILE="/var/log/install_odoo16.log"
exec > >(tee -a $LOG_FILE) 2>&1


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

# Variables
PROJECT_DIR="prospection"
BASE_DIR="/home/$USER/$PROJECT_DIR"

echo "== Début de l'installation automatisée d'Odoo 16 CE =="

# 1. Mise à jour des paquets système
echo "Mise à jour des paquets système..."
check_command "sudo apt update && sudo apt upgrade -y" \
    "Mise à jour terminée." \
    "Erreur lors de la mise à jour des paquets."

# 2. Installation de Docker et Docker Compose
echo "Installation de Docker..."
check_command "sudo apt install -y docker.io" \
    "Docker installé avec succès." \
    "Erreur lors de l'installation de Docker."

# Vérification et installation de Docker Compose V2
if ! docker compose version &>/dev/null; then
    echo "Docker Compose V2 n'est pas installé. Installation..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    success "Docker Compose V2 installé dans /usr/local/bin."
else
    success "Docker Compose V2 déjà présent."
fi

# Vérification de la version de Docker Compose
echo "Vérification de la version de Docker Compose..."
docker compose version || error "Docker Compose V2 non installé correctement."


# 3. Activation du lancement automatique de Docker au démarrage
echo "Activation de Docker au démarrage..."
check_command "sudo systemctl enable docker" \
    "Docker configuré pour démarrer automatiquement." \
    "Erreur lors de la configuration de Docker."

# 4. Ajout de l'utilisateur au groupe Docker
echo "Ajout de l'utilisateur au groupe Docker..."
check_command "sudo usermod -aG docker $USER" \
    "Utilisateur ajouté au groupe Docker." \
    "Erreur lors de l'ajout de l'utilisateur au groupe Docker."

# 5. Création de la structure du projet
echo "Création de la structure du projet..."
check_command "mkdir -p $BASE_DIR/{config,extra-addons,data}" \
    "Répertoires créés avec succès." \
    "Erreur lors de la création des répertoires."

# 6. Attribution des droits sur les répertoires
echo "Attribution des droits sur les répertoires..."
check_command "chmod -R 755 $BASE_DIR && chown -R $USER:$USER $BASE_DIR" \
    "Droits attribués avec succès." \
    "Erreur lors de l'attribution des droits."

# 7. Création et configuration du fichier odoo.conf
echo "Création du fichier odoo.conf..."
tee $BASE_DIR/config/odoo.conf > /dev/null <<EOL
[options]
addons_path = /mnt/extra-addons
db_host = pg_db
db_port = 5432
db_user = prospection
db_password = prospection
db_name = prospection
xmlrpc_interface = 0.0.0.0
EOL
success "Fichier odoo.conf créé."

# 8. Création et configuration du Dockerfile
echo "Création du Dockerfile..."
tee $BASE_DIR/Dockerfile > /dev/null <<EOL
FROM odoo:16
COPY ./config /etc/odoo
EOL
success "Dockerfile créé."

# 9. Création et configuration du fichier docker-compose.yml
echo "Création du fichier docker-compose.yml..."
tee $BASE_DIR/docker-compose.yml > /dev/null <<EOL
version: '3.7'

services:
  pg_db:
    image: postgres:14
    container_name: pg_db
    environment:
      POSTGRES_DB: prospection
      POSTGRES_USER: prospection
      POSTGRES_PASSWORD: prospection
    volumes:
      - ./data:/var/lib/postgresql/data

  odoo_web:
    build: .
    container_name: odoo_web
    ports:
      - "8069:8069"
    volumes:
      - ./config:/etc/odoo
      - ./extra-addons:/mnt/extra-addons
    depends_on:
      - pg_db

EOL
success "Fichier docker-compose.yml créé."

# 10. Positionnement dans le répertoire et démarrage des conteneurs Docker
echo "Démarrage des conteneurs..."
cd $BASE_DIR
check_command "docker-compose down && docker-compose up -d" \
    "Conteneurs démarrés avec succès." \
    "Erreur lors du démarrage des conteneurs."

# 11. Initialisation de la base de données dans Odoo
echo "Initialisation de la base de données Odoo..."
check_command "docker exec -it odoo_web odoo -d prospection -i base" \
    "Base de données initialisée avec succès." \
    "Erreur d'initialisation de la base de données Odoo."

# 12. Vérification de l'état des services
echo "Vérification des services..."
docker ps && success "Services Odoo et PostgreSQL actifs."

# 13. Désactivation du pare-feu (si nécessaire)
echo "Désactivation du pare-feu (si nécessaire)..."
sudo ufw disable && success "Pare-feu désactivé."

# 14. Test du port HTTP
echo "Test du port HTTP..."
check_command "curl -s http://127.0.0.1:8069" \
    "Port HTTP testé avec succès. Odoo est accessible." \
    "Erreur lors du test du port HTTP."

# 15. Informations de connexion
echo "Lien d'accès à l'application Odoo :"
echo "URL : http://<IP_PUBLIQUE_VM>:8069"
echo "Identifiants par défaut :"
echo "Utilisateur : admin"
echo "Mot de passe : admin"

success "Installation complète et fonctionnelle !"
