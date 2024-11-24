# odoo
Objectif et Importance de l'Automatisation du Déploiement

Objectif :
L'objectif de ce script est de simplifier et d'automatiser le processus d'installation et de déploiement d'Odoo 16 CE et de PostgreSQL sur une machine Ubuntu en utilisant Docker et Docker Compose. Cela permet de garantir une installation cohérente et reproductible, réduisant ainsi les erreurs humaines et le temps nécessaire pour configurer l'environnement.

Importance :
L'automatisation du déploiement est cruciale pour les environnements de production où la cohérence et la fiabilité sont essentielles. Elle permet également de gagner du temps et de réduire les coûts associés à la maintenance et à la mise à jour des systèmes. De plus, elle facilite la gestion des dépendances et des configurations, assurant que toutes les installations suivent les mêmes standards.

Instructions de Préparation
Vérification et Configuration des DNS

Assurez-vous que votre serveur Ubuntu est configuré pour accepter les connexions externes.
Ajoutez temporairement une autre source DNS si nécessaire :

 echo "Vérification et configuration des DNS..."
if ! grep -q "8.8.8.8" /etc/resolv.conf; then
    echo "Ajout des serveurs DNS temporaires..."
    echo -e "nameserver 8.8.8.8\nnameserver 8.8.4.4" | sudo tee /etc/resolv.conf > /dev/null
    success "Serveurs DNS ajoutés."
else
    success "Serveurs DNS déjà configurés."
fi

Si le problème persiste, désactivez temporairement le DNS :

sudo systemctl disable --now systemd-resolved


1) Cas d'Exécution en Direct

- Exécutez le script directement depuis GitHub :

bash <(curl -s https://raw.githubusercontent.com/krinf15/odoo-setup/main/install_odoo16.sh)


2) Cas de Téléchargement et Exécution depuis Ubuntu

- Téléchargez le script depuis GitHub :

curl -O https://raw.githubusercontent.com/<username>/<repository>/<branch>/install_odoo16.sh
Ajoutez les droits et permissions :

chmod +x install_odoo.sh

Si vous rencontrez des problèmes d'exécution (par exemple, si le fichier a été créé sous Windows), convertissez les sauts de ligne :

sudo apt update
sudo apt install dos2unix
dos2unix install_odoo.sh
Exécutez le script :

sudo ./install_odoo.sh

3) Cas d'Utilisation du Fichier sans Extension

Renommez le fichier et exécutez-le :

mv install_odoo.sh install_odoo
./install_odoo

4) Déplacement du Fichier dans un Autre Répertoire

Déplacez le répertoire et ajustez les permissions :

sudo mv /usr/prospection /opt/prospection
sudo chown -R $USER:$USER /opt/prospection
cd /opt/prospection
Initialisation Manuelle de la Base de Données

5) Connectez-vous au conteneur Odoo et initialisez la base de données :

sudo docker exec -it odoo_web bash
sudo odoo --init=base --database=prospection


