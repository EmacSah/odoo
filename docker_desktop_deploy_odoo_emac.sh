#!/bin/bash

#-----------------------------INSTRUCTIONS A SUIVRE------------------------------------------------------

# Instruction script d'installation:
#-Se conncecter sur docker desktop
#-Ouvrir le terminal de commande juste en dessous selon votre version
#-saisir la commande : git clone -b image_odoo_emacsah https://github.com/EmacSah/odoo.git
#-Une fois le depot cloné, deplacez vous dans le depôt cloné : Cd ./odoo
#- Saisir la commande d'attribution des droits : chmod +x docker_desktop_deploy_odoo_emac.sh
#- Ensuite saisir la commande pour lancer le script : ./docker_desktop_deploy_odoo_emac.sh
#- Tu vas renseigner tes différents paramètres au fur et à mésure pour personnaliser ton installation.

#-------------------------------------------------------------------------------------------------------


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

# Variables configurables
IMAGE_NAME="odoo-emac"
POSTGRES_IMAGE="postgres:14"
ODOO_VERSION="16"

# Demande des variables utilisateur
read -p "Entrez le nom de la base de données PostgreSQL (par défaut : odoo): " DB_NAME
DB_NAME=${DB_NAME:-odoo}

read -p "Entrez l'utilisateur de la base de données PostgreSQL (par défaut : odoo): " DB_USER
DB_USER=${DB_USER:-odoo}

read -p "Entrez le mot de passe de la base de données PostgreSQL (par défaut : odoo): " DB_PASSWORD
DB_PASSWORD=${DB_PASSWORD:-odoo}

read -p "Entrez l'hôte de la base de données PostgreSQL (par défaut : pg_db): " DB_HOST
DB_HOST=${DB_HOST:-pg_db}

read -p "Entrez le port de la base de données PostgreSQL (par défaut : 5432): " DB_PORT
DB_PORT=${DB_PORT:-5432}

read -p "Entrez le port pour Odoo (par défaut : 8069): " ODOO_PORT
ODOO_PORT=${ODOO_PORT:-8069}

# Vérification des variables utilisateur
echo "Configuration choisie :"
echo " - Nom de la base de données : $DB_NAME"
echo " - Utilisateur PostgreSQL : $DB_USER"
echo " - Mot de passe PostgreSQL : $DB_PASSWORD"
echo " - Hôte PostgreSQL : $DB_HOST"
echo " - Port PostgreSQL : $DB_PORT"
echo " - Port Odoo : $ODOO_PORT"

# Créer les répertoires nécessaires
mkdir -p config extra-addons data

# Créer le fichier de configuration Odoo
tee config/odoo.conf > /dev/null <<EOL
[options]
addons_path = /mnt/extra-addons
db_host = $DB_HOST
db_port = $DB_PORT
db_user = $DB_USER
db_password = $DB_PASSWORD
db_name = $DB_NAME
xmlrpc_interface = 0.0.0.0
xmlrpc_port = $ODOO_PORT
EOL
success "Fichier odoo.conf créé."

# Créer le fichier Dockerfile
tee Dockerfile > /dev/null <<EOL
# Dockerfile pour Odoo
FROM odoo:$ODOO_VERSION

# Copier les fichiers de configuration
COPY ./config /etc/odoo
COPY ./entrypoint.sh /usr/local/bin/entrypoint.sh

# Rendre le script d'entrée exécutable
USER root
RUN chmod +x /usr/local/bin/entrypoint.sh

# Définir le script d'entrée
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Exposer le port
EXPOSE $ODOO_PORT

# Commande de démarrage
CMD ["odoo", "--xmlrpc-port=$ODOO_PORT"]
EOL
success "Dockerfile créé."

# Créer le script d'entrée pour configurer Odoo avec les variables utilisateur
tee entrypoint.sh > /dev/null <<EOL
#!/bin/bash

# Configuration d'Odoo avec les paramètres utilisateur
sed -i "s/db_name = .*/db_name = $DB_NAME/" /etc/odoo/odoo.conf
sed -i "s/db_user = .*/db_user = $DB_USER/" /etc/odoo/odoo.conf
sed -i "s/db_password = .*/db_password = $DB_PASSWORD/" /etc/odoo/odoo.conf
sed -i "s/db_host = .*/db_host = $DB_HOST/" /etc/odoo/odoo.conf
sed -i "s/db_port = .*/db_port = $DB_PORT/" /etc/odoo/odoo.conf
sed -i "s/xmlrpc_port = .*/xmlrpc_port = $ODOO_PORT/" /etc/odoo/odoo.conf

echo "Configuration d'Odoo mise à jour :"
/bin/cat /etc/odoo/odoo.conf

exec "\$@"
EOL
success "Script d'entrée (entrypoint.sh) créé."

# Construire l'image Docker
docker build -t $IMAGE_NAME .
if [[ $? -ne 0 ]]; then
    error "Erreur lors de la construction de l'image Docker pour Odoo."
else
    success "Image Docker $IMAGE_NAME construite avec succès."
fi

# Démarrer un conteneur PostgreSQL
docker run -d --name pg_db -e POSTGRES_DB=$DB_NAME -e POSTGRES_USER=$DB_USER -e POSTGRES_PASSWORD=$DB_PASSWORD -p 5432:5432 $POSTGRES_IMAGE
if [[ $? -ne 0 ]]; then
    error "Erreur lors du démarrage du conteneur PostgreSQL."
else
    success "Conteneur PostgreSQL démarré avec succès."
fi

# Démarrer un conteneur Odoo
docker run -d --name odoo_web -p $ODOO_PORT:$ODOO_PORT --link pg_db:db $IMAGE_NAME
if [[ $? -ne 0 ]]; then
    error "Erreur lors du démarrage du conteneur Odoo."
else
    success "Conteneur Odoo démarré avec succès."
fi

# Vérifier les conteneurs en cours d'exécution
docker ps

# Afficher l'URL d'accès à l'application Odoo
echo "Lien d'accès à l'application Odoo :"
echo "URL : http://localhost:$ODOO_PORT"
echo "Identifiants par défaut :"
echo "Utilisateur : admin"
echo "Mot de passe : admin"

success "Déploiement complet et fonctionnel !"
