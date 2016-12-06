# SDPTDD
Système distribué pour traitement de données.

# Utilisation des tâches Rake

```bash
# Installation de Bundler (once)
gem install bundler

# Installation de Rake + SSHKit (once)
# En cas d'incompatibilité avec Gemfile.lock sur le dépôt : bundle update
bundle

# Listing des tâches Rake avec leur description
rake -T

# Connexion SSH
rake ssh server-1

# Déploiement et provisioning
rake deploy

# Uniquement sur deux serveurs (définis dans hosts.yml)
rake deploy[server-2;server-3]

# Démarrage des services
rake services:start

# Statut des services
rake services:status

# Arrêt des services
rake services:stop

# Kill des services
rake services:kill

# Activation au démarrage (enable)
rake services:enable
```