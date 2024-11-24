#!/bin/bash
#
# Personnaliser les configurations selon votre installations
#configurer les repertoires, noms de base de données et password, noms des dockers
# utiliser le script suivant pour l'executer depuis githube
#bash <(curl -s https://raw.githubusercontent.com/no_user_github/repository_name/branch_name/file_name)
# Couleurs pour les messages
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

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


# Mise à jour du PATH pour inclure /usr/local/bin
echo "Configuration du PATH pour inclure /usr/local/bin..."

if ! grep -q 'export PATH="/usr/local/bin:$PATH"' ~/.bashrc; then
    echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
    echo "PATH mis à jour pour inclure /usr/local/bin."
else
    echo "PATH déjà configuré pour inclure /usr/local/bin."
fi



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

# Ajout des dépôts officiels Docker
echo "Configuration des dépôts officiels Docker..."
check_command "sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common" \
    "Pré-requis pour Docker installés avec succès." \
    "Erreur lors de l'installation des pré-requis pour Docker."

check_command "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg" \
    "Clé GPG Docker ajoutée avec succès." \
    "Erreur lors de l'ajout de la clé GPG Docker."

check_command "echo 'deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable' | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && sudo apt-get update" \
    "Dépôts Docker configurés avec succès." \
    "Erreur lors de la configuration des dépôts Docker."

# Installation de Docker
check_command "sudo apt-get install -y docker-ce docker-ce-cli containerd.io" \
    "Docker installé avec succès." \
    "Erreur lors de l'installation de Docker."

# Vérification et installation/mise à jour de Docker Compose V2
echo "== Vérification de Docker Compose =="

# Vérifie si Docker Compose est installé
if docker compose version &>/dev/null || docker-compose --version &>/dev/null; then
    # Vérifie si "docker compose" est disponible
    if docker compose version &>/dev/null; then
        INSTALLED_VERSION=$(docker compose version --short)
    else
        # Utilise "docker-compose" si "docker compose" n'est pas disponible
        INSTALLED_VERSION=$(docker-compose --version | awk '{print $3}' | sed 's/,//')
    fi

    REQUIRED_VERSION="2.0.0"

    echo "Docker Compose installé (version : $INSTALLED_VERSION)."
    
    # Compare les versions pour savoir si une mise à jour est nécessaire
    if dpkg --compare-versions "$INSTALLED_VERSION" "ge" "$REQUIRED_VERSION"; then
        success "Docker Compose V2 est à jour."
    else
        echo "La version de Docker Compose est obsolète. Mise à jour en cours..."
        check_command "sudo apt-get install -y docker-compose-plugin" \
            "Docker Compose mis à jour avec succès." \
            "Erreur lors de la mise à jour de Docker Compose."
    fi
else
    echo "Docker Compose n'est pas installé. Installation en cours..."
    check_command "sudo apt-get install -y docker-compose-plugin" \
        "Docker Compose installé avec succès." \
        "Erreur lors de l'installation de Docker Compose."
fi

# Validation finale
if docker compose version &>/dev/null || docker-compose --version &>/dev/null; then
    if docker compose version &>/dev/null; then
        INSTALLED_VERSION=$(docker compose version --short)
    else
        INSTALLED_VERSION=$(docker-compose --version | awk '{print $3}' | sed 's/,//')
    fi
    success "Docker Compose V2 installé et fonctionnel (version : $INSTALLED_VERSION)."
else
    error "Docker Compose V2 non installé correctement. Vérifiez votre configuration."
fi

echo "== Vérification terminée =="


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

# Vérification des droits
echo "Attribution des droits sur les répertoires..."
check_command "chmod -R 755 $BASE_DIR && chown -R $USER:$USER $BASE_DIR" \
    "Droits attribués avec succès." \
    "Erreur lors de l'attribution des droits."

# 6. Création et configuration du fichier odoo.conf
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

# 7. Création et configuration du Dockerfile
echo "Création du Dockerfile..."
tee $BASE_DIR/Dockerfile > /dev/null <<EOL
FROM odoo:16
COPY ./config /etc/odoo
EOL
success "Dockerfile créé."

# 8. Création et configuration du fichier docker-compose.yml
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

# Détection de la commande Docker Compose appropriée
if command -v docker compose &>/dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
elif command -v docker-compose &>/dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
else
    error "Aucune commande Docker Compose valide trouvée. Vérifiez votre installation."
fi


# 9. Positionnement dans le répertoire et démarrage des conteneurs Docker
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
echo "Exécution de la commande : $DOCKER_COMPOSE_CMD down"
if ! $DOCKER_COMPOSE_CMD down; then
    error "Erreur lors de l'exécution de la commande : $DOCKER_COMPOSE_CMD down"
fi

echo "Exécution de la commande : $DOCKER_COMPOSE_CMD up -d"
if ! $DOCKER_COMPOSE_CMD up -d; then
    error "Erreur lors de l'exécution de la commande : $DOCKER_COMPOSE_CMD up -d"
fi

success "Conteneurs démarrés avec succès."



# 10. Initialisation de la base de données dans Odoo
echo "Initialisation de la base de données Odoo..."
check_command "docker exec -it odoo_web odoo -d prospection -i base" \
    "Base de données initialisée avec succès." \
    "Erreur d'initialisation de la base de données Odoo."

# 11. Vérification de l'état des services
echo "Vérification des services..."
docker ps && success "Services Odoo et PostgreSQL actifs."

# 12. Désactivation du pare-feu (si nécessaire)
echo "Désactivation du pare-feu (si nécessaire)..."
sudo ufw disable && success "Pare-feu désactivé."

# 13. Test du port HTTP
echo "Test du port HTTP..."
check_command "curl -s http://127.0.0.1:8069" \
    "Port HTTP testé avec succès. Odoo est accessible." \
    "Erreur lors du test du port HTTP."

# 14. Informations de connexion
echo "Lien d'accès à l'application Odoo :"
echo "URL : http://<IP_PUBLIQUE_VM>:8069"
echo "Identifiants par défaut :"
echo "Utilisateur : admin"
echo "Mot de passe : admin"

success "Installation complète et fonctionnelle !"
