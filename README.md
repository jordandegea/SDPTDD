      _____     _____     _______    _____  
     / ____|   |  __  \  |__   __|  |  __ \ 
    | (___     | |  | |     | |     | |  | |
     \___ \    | |  | |     | |     | |  | |
     ____) |   | |__| |     | |     | |__| |
    |_____/    |______/     |_|     |_____/ 

Système distribué pour traitement de données.

# [TODO](TODO.md)

# Sujet - "Twitter & Humeur"

L'objectif de ce projet est d'estimer l'**humeur** des gens dans différentes régions. Nous récupérons des flux twitters sur différentes régions. Sur chaque tweet, nous attribuons une appréciation. Puis nous stockons chaque tweet traité et son appreciation dans la base. 

# Equipe

    ABOUBACAR Salim     DE GEA Jordan           DUCLOT William      
    HEINISCH Pierre     PEREZ Joseph            RACHDI Imane    
    STOFFEL Mathieu     TAVERNIER Vincent       THIOLLIERE Guillaume


# [Composants](./misc/COMPONENTS.md)

# [Architecture](./misc/ARCHITECTURE.md)

# [Comportement](./misc/BEHAVIOR.md)

# Configurations et Aides

## [Flink en tant que Producer](./misc/FLINK_PRODUCER.md)

## [Kafka](./misc/KAFKA.md)

## [Flink en tant que Traitement](./misc/FLINK_PROCESS.md)

## [HBase](./misc/HBASE.md)

## [Zeppelin](./misc/ZEPPELIN.md)

# Informations

Environnement de déploiement : **Vagrant**

Outil de deploiement : **Rake**

# Pour commencer

## Lancer en developpement local

```bash
export RAKE_ENV=development
rake vagrant:up
./deploy.sh
```

## Lancer en production

Le document hosts.yml contient les informations de connexion aux machines de production. 

```bash
export RAKE_ENV=production
./deploy.sh
```


# Utilisation de Rake pour les tâches de maintenance

## Installation

```bash
# Installation de Bundler (once)
gem install bundler

# Installation des dépendances
# En cas d'incompatibilité avec Gemfile.lock sur le dépôt : bundle update
bundle
```

## Environnement

```bash
# Utilisation de l'environnement de développement
export RAKE_ENV=development
# Ne pas oublier de démarrer les machines virtuelles pour l'environnement de développement
rake vagrant:up

# Utilisation de l'environnement de production
export RAKE_ENV=production
```

## Affichage de l'aide

```bash
# Listing des tâches Rake avec leur description
rake -T
```

## Deploiement

```bash
# Déploiement et provisioning
rake deploy

# Uniquement sur deux serveurs (définis dans hosts.yml)
rake deploy[server-2;server-3]

# Connexion SSH
rake ssh server-1
```

## Services

En l'absence de services spécifiés pour ces commandes, l'ensemble de services
concerné est celui défini dans la section *services* du fichier de configuration
courant. Ces commandes (à l'exception de `services:watcher`) correspondent
à l'appel de `systemctl` sur les machines cibles.

```bash
# Démarrage des services
rake services:start

# Statut des services
rake services:status

# Arrêt des services
rake services:stop

# Kill des services
rake services:kill

# Kill tous les services de <server1> et <server2>
rake services:kill[<server1>;<server2>]

# Kill les services <service1> et <service2> de <server1> et <server2>
rake services:kill[<server1>;<server2>,<service1>;<service2>]

# Kill les services <service1> et <service2> sur tous les serveurs
rake services:kill[,<service1>;<service2>]

# Activation au démarrage (enable)
rake services:enable
```

## Execution OneShot de commande

```bash
# Lancer la commande <commande> (défini dans le yaml config)
rake run:<commande>[<server1>,<server2>]
```


## Tests automatisés

Le fonctionnement de l'infrastructure actuelle (selon `$RAKE_ENV`) peut être
validé par l'exécution de tests automatisés, tels que définis dans le dossier
`features/`.

```bash
# Exécution de tous les tests
rake features

# Exécution des tests de déploiement
rake features:deployment

# Exécution des tests du composant service_watcher
rake features:service_watcher

# Exécution des tests de contrôle des services systemd
rake features:services
```


# Environnement de test Vagrant

Le dossier vagrant contient :

* `Vagrantfile` : définition de machines virtuelles de test
* `vagrant-hosts.yml` : configuration des différentes machines de test

Pour utiliser cet environnement de test :

* Installer [Vagrant](https://www.vagrantup.com/).
* Installer [VirtualBox](https://www.virtualbox.org/).
* Installer le plugin "vagrant-hostmanager" :

```bash
vagrant plugin install vagrant-hostmanager
```

* Suivre les instructions de https://github.com/devopsgroup-io/vagrant-hostmanager#passwordless-sudo pour éviter la
    demande de mot de passe sudo à chaque démarrage des machines virtuelles.

Une fois que tout est installé, les commandes suivantes peuvent être utilisées :

```bash
# Démarrage des machines définies dans le Vagrantfile
# La première fois, les images vont être téléchargées et configurées. Cela prend du temps.
# Les fois suivantes les machines installées seront reprises dans leur état actuel.
vagrant up

# Connexion SSH à une des machines
vagrant ssh worker1

# Recréer les machines suite à une modification du Vagrantfile
vagrant reload

# Mise en pause des machines
vagrant suspend

# Arrêt des machines (shutdown)
vagrant halt

# Destruction des machines (pour réinstallation propre)
vagrant destroy
```

Si _vagrant-hostmanager_ est configuré correctement, les machines peuvent être contactées en utilisant les noms
`worker1`, `worker2` etc. plutôt que leurs adresses IP.

Le réseau privé utilisé pour les machines Vagrant est 10.20.1.0/24. Par défaut l'adresse de la machine hôte est
10.20.1.1.

## Troubleshooting

### vagrant plugin install vagrant-hostmanager échoue

sous debian il peut être nécessaire d'installer le paquet ruby-dev.
