#!/bin/bash

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
IMAGE_NAME="odoo-custom"
ODOO_VERSION="16"

# Créer le répertoire de construction
mkdir -p odoo-docker
cd odoo-docker

# Créer le fichier de configuration Odoo
mkdir -p config
tee config/odoo.conf > /dev/null <<EOL
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
EXPOSE 8069

# Commande de démarrage
CMD ["odoo", "--xmlrpc-port=8069", "--db-filter=.*"]
EOL
success "Dockerfile créé."

# Créer le script d'entrée
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

# Demander les paramètres de configuration à l'utilisateur
read -p "Entrez le nom de la base de données PostgreSQL : " DB_NAME
read -p "Entrez l'utilisateur de la base de données PostgreSQL : " DB_USER
read -p "Entrez le mot de passe de la base de données PostgreSQL : " DB_PASSWORD
read -p "Entrez l'hôte de la base de données PostgreSQL (par exemple, pg_db) : " DB_HOST
read -p "Entrez le port de la base de données PostgreSQL (par défaut 5432) : " DB_PORT

# Exporter les variables d'environnement
export DB_NAME
export DB_USER
export DB_PASSWORD
export DB_HOST
export DB_PORT

# Configurer Odoo avec les paramètres fournis
sed -i "s/db_name = .*/db_name = \$DB_NAME/" /etc/odoo/odoo.conf
sed -i "s/db_user = .*/db_user = \$DB_USER/" /etc/odoo/odoo.conf
sed -i "s/db_password = .*/db_password = \$DB_PASSWORD/" /etc/odoo/odoo.conf
sed -i "s/db_host = .*/db_host = \$DB_HOST/" /etc/odoo/odoo.conf
sed -i "s/db_port = .*/db_port = \$DB_PORT/" /etc/odoo/odoo.conf

success "Configuration d'Odoo mise à jour avec succès."

# Démarrer Odoo
exec "\$@"
EOL
success "Script d'entrée créé."

# Construire l'image Docker
docker build -t $IMAGE_NAME .
success "Image Docker $IMAGE_NAME construite avec succès."
