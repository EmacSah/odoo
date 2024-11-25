# Dockerfile pour Odoo
FROM odoo:16

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
