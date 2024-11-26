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
DEFAULT_ODOO_VERSION="16"
DEFAULT_POSTGRES_VERSION="14"
ODOO_CONTAINER_NAME=${ODOO_CONTAINER_NAME:-odoo_web}
POSTGRES_CONTAINER_NAME=${POSTGRES_CONTAINER_NAME:-pg_db}
IMAGE_NAME="odoo-$DEFAULT_ODOO_VERSION"

# Demande des variables utilisateur
read -p "Entrez la version d'Odoo à installer (par défaut : $DEFAULT_ODOO_VERSION): " ODOO_VERSION
ODOO_VERSION=${ODOO_VERSION:-$DEFAULT_ODOO_VERSION}

read -p "Entrez la version de PostgreSQL à installer (par défaut : $DEFAULT_POSTGRES_VERSION): " POSTGRES_VERSION
POSTGRES_VERSION=${POSTGRES_VERSION:-$DEFAULT_POSTGRES_VERSION}

read -p "Entrez le nom de la base de données PostgreSQL (par défaut : odoo): " DB_NAME
DB_NAME=${DB_NAME:-odoo}

read -p "Entrez l'utilisateur de la base de données PostgreSQL (par défaut : odoo): " DB_USER
DB_USER=${DB_USER:-odoo}

read -p "Entrez le mot de passe de la base de données PostgreSQL (par défaut : odoo): " DB_PASSWORD
DB_PASSWORD=${DB_PASSWORD:-odoo}

read -p "Entrez l'hôte de la base de données PostgreSQL (par défaut : $POSTGRES_CONTAINER_NAME): " DB_HOST
DB_HOST=${DB_HOST:-$POSTGRES_CONTAINER_NAME}

# Vérification si DB_HOST correspond bien au nom du conteneur PostgreSQL
if [[ "$DB_HOST" != "$POSTGRES_CONTAINER_NAME" ]]; then
    echo "Mise à jour de DB_HOST pour correspondre au conteneur PostgreSQL : $POSTGRES_CONTAINER_NAME"
    DB_HOST=$POSTGRES_CONTAINER_NAME
fi
success "DB_HOST configuré comme : $DB_HOST"

read -p "Entrez le port de la base de données PostgreSQL (par défaut : 5432): " DB_PORT
DB_PORT=${DB_PORT:-5432}

read -p "Entrez le port pour Odoo (par défaut : 8069): " ODOO_PORT
ODOO_PORT=${ODOO_PORT:-8069}


# Vérification des variables utilisateur
echo "Configuration choisie :"
echo " - Version d'Odoo : $ODOO_VERSION"
echo " - Version de PostgreSQL : $POSTGRES_VERSION"
echo " - Nom de la base de données : $DB_NAME"
echo " - Utilisateur PostgreSQL : $DB_USER"
echo " - Mot de passe PostgreSQL : $DB_PASSWORD"
echo " - Hôte PostgreSQL : $DB_HOST"
echo " - Port PostgreSQL : $DB_PORT"
echo " - Port Odoo : $ODOO_PORT"


# Fonction pour vérifier l'existence des conteneurs
check_existing_container() {
    local container_name=$1
    if docker ps -a --format '{{.Names}}' | grep -Eq "^${container_name}\$"; then
        error "Un conteneur avec le nom '${container_name}' existe déjà. Modifiez les variables et relancez le script."
    fi
}
# Vérifier les conteneurs existants
check_existing_container "$POSTGRES_CONTAINER_NAME"
check_existing_container "$ODOO_CONTAINER_NAME"


# Validation stricte des entrées utilisateur
if [[ -z "$ODOO_VERSION" || -z "$POSTGRES_VERSION" || -z "$DB_NAME" || -z "$DB_USER" || -z "$DB_PASSWORD" || -z "$DB_HOST" || -z "$DB_PORT" || -z "$ODOO_PORT" ]]; then
    error "Toutes les variables doivent être renseignées. Relancez le script."
else
    success "Configuration validée avec les valeurs fournies."
fi


#Affichages des informations enregistrées
echo "Configuration choisie :"
echo " - Conteneur PostgreSQL : $POSTGRES_CONTAINER_NAME"
echo " - Conteneur Odoo : $ODOO_CONTAINER_NAME"


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
fi
success "Image Docker $IMAGE_NAME construite avec succès."


# Démarrer un conteneur PostgreSQL
docker run -d --name $POSTGRES_CONTAINER_NAME -e POSTGRES_DB=$DB_NAME -e POSTGRES_USER=$DB_USER -e POSTGRES_PASSWORD=$DB_PASSWORD -p $DB_PORT:5432 postgres:$POSTGRES_VERSION
if [[ $? -ne 0 ]]; then
    error "Erreur lors du démarrage du conteneur PostgreSQL."
else
    success "Conteneur PostgreSQL démarré avec succès."
fi

# Démarrer un conteneur PostgreSQL
docker run -d --name $ODOO_CONTAINER_NAME -p $ODOO_PORT:$ODOO_PORT --link $POSTGRES_CONTAINER_NAME:db $IMAGE_NAME
if [[ $? -ne 0 ]]; then
    error "Erreur lors du démarrage du conteneur PostgreSQL."
fi
success "Conteneur PostgreSQL démarré avec succès."



# Vérification et configuration du réseau
echo "Vérification du réseau partagé entre les conteneurs Odoo et PostgreSQL..."
docker network inspect bridge &>/dev/null || docker network create odoo_network
docker network connect odoo_network $POSTGRES_CONTAINER_NAME
docker network connect odoo_network $ODOO_CONTAINER_NAME
success "Les conteneurs partagent le réseau odoo_network."


# Test de connectivité entre Odoo et PostgreSQL
echo "Test de connectivité entre Odoo et PostgreSQL..."
docker exec -it $POSTGRES_CONTAINER_NAME psql -U $DB_USER -c "\l" &>/dev/null
if [[ $? -ne 0 ]]; then
    error "Échec de la connectivité réseau entre Odoo et PostgreSQL. Vérifiez la configuration réseau."
fi
success "Connectivité réseau validée."


# Initialisation de la base de données Odoo
echo "Vérification de permissions sur odoo.conf..."
docker exec -it $ODOO_CONTAINER_NAME ls -l /etc/odoo/odoo.conf


# Initialisation de la base de données Odoo
echo "Vérification de l'existance de la base de données Odoo..."
docker exec -it $POSTGRES_CONTAINER_NAME psql -U $DB_USER -c "\l"


# Initialisation de la base de données Odoo
docker exec -it $ODOO_CONTAINER_NAME odoo --db_host=$DB_HOST --db_user=$DB_USER --db_password=$DB_PASSWORD -d $DB_NAME -i base
if [[ $? -ne 0 ]]; then
    error "Erreur lors de l'initialisation de la base de données Odoo. Vérifiez les logs."
fi
success "Base de données Odoo initialisée avec succès."




# Vérifier les conteneurs en cours d'exécution
docker ps

# Afficher l'URL d'accès à l'application Odoo
echo "Lien d'accès à l'application Odoo :"
echo "URL : http://localhost:$ODOO_PORT"
echo "Identifiants par défaut :"
echo "Utilisateur : admin"
echo "Mot de passe : admin"


success "Déploiement complet et fonctionnel !"
