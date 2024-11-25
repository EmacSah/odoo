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
sed -i "s/db_name = .*/db_name = $DB_NAME/" /etc/odoo/odoo.conf
sed -i "s/db_user = .*/db_user = $DB_USER/" /etc/odoo/odoo.conf
sed -i "s/db_password = .*/db_password = $DB_PASSWORD/" /etc/odoo/odoo.conf
sed -i "s/db_host = .*/db_host = $DB_HOST/" /etc/odoo/odoo.conf
sed -i "s/db_port = .*/db_port = $DB_PORT/" /etc/odoo/odoo.conf

success "Configuration d'Odoo mise à jour avec succès."

# Démarrer Odoo
exec "$@"
