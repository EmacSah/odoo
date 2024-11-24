#!/bin/bash

#Emac Sah Configuration et installation odoo on Docker
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

echo "== Début de l'installation automatisée d'Odoo 16 CE =="


# 2. Vérification et configuration des permissions du script
echo "Vérification des permissions du fichier install_odoo.sh..."
check_command "ls -l install_odoo.sh" \
    "Permissions actuelles vérifiées." \
    "Erreur lors de la vérification des permissions."

echo "Changement du propriétaire et des droits si nécessaire..."
sudo chown $USER:$USER install_odoo.sh && chmod +x install_odoo.sh && success "Propriétaire et permissions configurés." || error "Erreur lors de la configuration des permissions."

# 3. Conversion des terminaisons de ligne si nécessaire
echo "Conversion des terminaisons de ligne du script (si nécessaire)..."
check_command "sudo apt update && sudo apt install -y dos2unix" \
    "Outil dos2unix installé." \
    "Erreur lors de l'installation de dos2unix."

check_command "dos2unix install_odoo.sh" \
    "Terminaisons de ligne converties au format Unix (LF)." \
    "Erreur lors de la conversion des terminaisons de ligne."


# 4.Configuration & Activation de l'exécution sans sudo
echo "Configuration de l'exécution sans sudo..."
if ! groups | grep -q "docker"; then
    check_command "sudo usermod -aG docker $USER" \
        "Utilisateur ajouté au groupe Docker." \
        "Erreur lors de l'ajout de l'utilisateur au groupe Docker."

    echo -e "${RED}[NOTE] Un redémarrage est nécessaire pour appliquer les modifications de groupe.${NC}"
    echo -e "${GREEN}[INFO] Le système redémarrera automatiquement dans 10 secondes.${NC}"
    sleep 10
    sudo reboot
    exit 0
else
    success "Aucune modification nécessaire. Vous êtes déjà dans le groupe Docker."
fi


# 5. Mise à jour des paquets système
echo "Mise à jour des paquets système..."
check_command "sudo apt update && sudo apt upgrade -y" \
    "Mise à jour terminée." \
    "Erreur lors de la mise à jour des paquets."

# 6. Installation de Docker et Docker Compose
echo "Installation de Docker..."
check_command "sudo apt install -y docker.io" \
    "Docker installé avec succès." \
    "Erreur lors de l'installation de Docker."

echo "Installation de Docker Compose..."
check_command "sudo apt install -y docker-compose" \
    "Docker Compose installé avec succès." \
    "Erreur lors de l'installation de Docker Compose."

echo "Version de Docker Compose :"
docker-compose --version || error "Docker Compose non installé correctement."

# 7. Activation du lancement automatique de Docker au démarrage
echo "Activation de Docker au démarrage..."
check_command "sudo systemctl enable docker" \
    "Docker configuré pour démarrer automatiquement." \
    "Erreur lors de la configuration de Docker."

# 8. Création de la structure du projet
echo "Création de la structure du projet..."
PROJECT_DIR="/usr/prospection"
check_command "sudo mkdir -p $PROJECT_DIR/{config,extra-addons,data}" \
    "Répertoires créés avec succès." \
    "Erreur lors de la création des répertoires."

# 9. Attribution des droits sur les répertoires
echo "Attribution des droits sur les répertoires..."
check_command "sudo chmod -R 755 $PROJECT_DIR" \
    "Droits attribués avec succès." \
    "Erreur lors de l'attribution des droits."

# 10. Création et configuration du fichier odoo.conf
echo "Création du fichier odoo.conf..."
sudo tee $PROJECT_DIR/config/odoo.conf > /dev/null <<EOL
[options]
addons_path = /mnt/extra-addons
db_host = pg_db
db_port = 5432
db_user = prospection
db_password = prospection
db_name = prospection
admin_passwd = admin
xmlrpc_interface = 0.0.0.0
log_level = info
proxy_mode = True
EOL
success "Fichier odoo.conf créé."

# 11. Création et configuration du Dockerfile
echo "Création du Dockerfile..."
sudo tee $PROJECT_DIR/Dockerfile > /dev/null <<EOL
FROM odoo:16
COPY ./config /etc/odoo
EOL
success "Dockerfile créé."

# 12. Création et configuration du fichier docker-compose.yml
echo "Création du fichier docker-compose.yml..."
sudo tee $PROJECT_DIR/docker-compose.yml > /dev/null <<EOL
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

volumes:
  postgres_data:
EOL
success "Fichier docker-compose.yml créé."

# 13. Démarrage des conteneurs Docker
echo "Démarrage des conteneurs..."
cd $PROJECT_DIR
check_command "docker-compose up -d" \
    "Conteneurs démarrés avec succès." \
    "Erreur lors du démarrage des conteneurs."

# 14. Initialisation de la base de données PostgreSQL
echo "Initialisation de la base de données PostgreSQL..."
check_command "docker exec -it pg_db psql -U prospection -c 'CREATE DATABASE prospection;'" \
    "Base de données PostgreSQL initialisée." \
    "Erreur lors de l'initialisation de la base de données PostgreSQL."

# 15. Initialisation de la base de données dans Odoo
echo "Initialisation de la base de données Odoo..."
check_command "docker exec -it odoo_web odoo -d prospection -i base" \
    "Base de données Odoo initialisée avec succès." \
    "Erreur d'initialisation de la base de données Odoo."

# 15-1. Vérification de la connexion à la base de données
echo "Vérification de la connexion à la base de données PostgreSQL..."
check_command "sudo docker exec -it pg_db psql -U prospection -c '\l'" \
    "Connexion à PostgreSQL réussie." \
    "Erreur de connexion à PostgreSQL."

# 16. Désactivation du pare-feu
echo "Désactivation du pare-feu (si nécessaire)..."
check_command "sudo ufw disable" \
    "Pare-feu désactivé." \
    "Erreur lors de la désactivation du pare-feu."

# 17. Test du port HTTP
echo "Test du port HTTP..."
check_command "curl -s http://127.0.0.1:8069" \
    "Port HTTP testé avec succès. Odoo est accessible." \
    "Erreur lors du test du port HTTP."

# 18. Informations de connexion
IP_PUBLIQUE=$(curl -s ifconfig.me)
echo "Lien d'accès à l'application Odoo :"
echo "URL : http://$IP_PUBLIQUE:8069"
echo "Identifiants par défaut :"
echo "Utilisateur : admin"
echo "Mot de passe : admin"

success "Installation complète et fonctionnelle !"
