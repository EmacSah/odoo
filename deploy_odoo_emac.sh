#!/bin/bash
#deployement interactif de Odoo sur DockerDesktop 
#Auteur : Emac Sah
#Versio : 1.0
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

# Variables par défaut
IMAGE_NAME="odoo-custom"
ODOO_VERSION="16"
POSTGRES_VERSION="14"
ODOO_PORT="8069"
POSTGRES_PORT="5432"

# Dialogue interactif pour les variables utilisateur
read -p "Entrez le nom de la base de données PostgreSQL (par défaut : prospection) : " DB_NAME
DB_NAME=${DB_NAME:-prospection}

read -p "Entrez l'utilisateur de la base de données PostgreSQL (par défaut : prospection) : " DB_USER
DB_USER=${DB_USER:-prospection}

read -p "Entrez le mot de passe de la base de données PostgreSQL (par défaut : prospection) : " DB_PASSWORD
DB_PASSWORD=${DB_PASSWORD:-prospection}

read -p "Entrez le nom du conteneur PostgreSQL (par défaut : pg_db) : " POSTGRES_CONTAINER_NAME
POSTGRES_CONTAINER_NAME=${POSTGRES_CONTAINER_NAME:-pg_db}

read -p "Entrez le nom du conteneur Odoo (par défaut : odoo_web) : " ODOO_CONTAINER_NAME
ODOO_CONTAINER_NAME=${ODOO_CONTAINER_NAME:-odoo_web}

# Créer les répertoires nécessaires
mkdir -p config extra-addons data

# Créer le fichier de configuration Odoo
tee config/odoo.conf > /dev/null <<EOL
[options]
addons_path = /mnt/extra-addons
db_host = $POSTGRES_CONTAINER_NAME
db_port = $POSTGRES_PORT
db_user = $DB_USER
db_password = $DB_PASSWORD
db_name = $DB_NAME
xmlrpc_interface = 0.0.0.0
EOL
success "Fichier odoo.conf créé."

# Créer le fichier entrypoint.sh
tee entrypoint.sh > /dev/null <<EOL
#!/bin/bash

# Couleurs pour les messages
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Fonction pour afficher un message de validation
success() {
    echo -e "\${GREEN}[SUCCÈS] \$1\${NC}"
}

# Fonction pour afficher un message d'erreur
error() {
    echo -e "\${RED}[ERREUR] \$1\${NC}"
    exit 1
}

# Configurer Odoo avec les variables utilisateur
sed -i "s/db_name = .*/db_name = \$DB_NAME/" /etc/odoo/odoo.conf
sed -i "s/db_user = .*/db_user = \$DB_USER/" /etc/odoo/odoo.conf
sed -i "s/db_password = .*/db_password = \$DB_PASSWORD/" /etc/odoo/odoo.conf
sed -i "s/db_host = .*/db_host = \$DB_HOST/" /etc/odoo/odoo.conf
sed -i "s/db_port = .*/db_port = \$DB_PORT/" /etc/odoo/odoo.conf

success "Configuration d'Odoo mise à jour avec succès."

# Démarrer Odoo
exec "\$@"
EOL
chmod +x entrypoint.sh
success "Script entrypoint.sh créé."

# Créer le Dockerfile
tee Dockerfile > /dev/null <<EOL
# Dockerfile pour Odoo
FROM odoo:$ODOO_VERSION

# Copier les fichiers de configuration
COPY ./config /etc/odoo
COPY ./entrypoint.sh /usr/local/bin/entrypoint.sh

# Rendre le script d'entrée exécutable
RUN chmod +x /usr/local/bin/entrypoint.sh

# Définir le script d'entrée
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Exposer le port
EXPOSE $ODOO_PORT

# Commande de démarrage
CMD ["odoo", "--xmlrpc-port=$ODOO_PORT", "--db-filter=.*"]
EOL
success "Dockerfile créé."

# Construire l'image Docker
docker build -t $IMAGE_NAME .
success "Image Docker $IMAGE_NAME construite avec succès."

# Démarrer un conteneur PostgreSQL
echo "Démarrage du conteneur PostgreSQL..."
docker run -d --name $POSTGRES_CONTAINER_NAME \
    -e POSTGRES_DB=$DB_NAME \
    -e POSTGRES_USER=$DB_USER \
    -e POSTGRES_PASSWORD=$DB_PASSWORD \
    -p $POSTGRES_PORT:5432 \
    postgres:$POSTGRES_VERSION
if [[ $? -eq 0 ]]; then
    success "Conteneur PostgreSQL démarré avec succès."
else
    error "Erreur lors du démarrage du conteneur PostgreSQL."
fi

# Pause pour s'assurer que PostgreSQL est prêt
echo "Attente de la disponibilité de PostgreSQL..."
sleep 10

# Démarrer un conteneur Odoo
echo "Démarrage du conteneur Odoo..."
docker run -d --name $ODOO_CONTAINER_NAME \
    -p $ODOO_PORT:8069 \
    --link $POSTGRES_CONTAINER_NAME:$POSTGRES_CONTAINER_NAME \
    $IMAGE_NAME
if [[ $? -eq 0 ]]; then
    success "Conteneur Odoo démarré avec succès."
else
    error "Erreur lors du démarrage du conteneur Odoo."
fi

# Vérification des conteneurs en cours d'exécution
docker ps

# Afficher l'URL d'accès à l'application Odoo
echo "Lien d'accès à l'application Odoo :"
echo "URL : http://localhost:$ODOO_PORT"
echo "Identifiants par défaut :"
echo "Utilisateur : admin"
echo "Mot de passe : admin"

success "Déploiement complet et fonctionnel !"
