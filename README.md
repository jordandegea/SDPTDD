# SDTD - "Twitter & Meteo"
Système distribué pour traitement de données.


## Sujet

L'objectif de ce projet est d'estimer l'humeur des gens dans différentes régions suivant la météo. Nous récupérons des flux twitters sur différentes régions. Sur chaque tweet, nous attribuons une appréciation. Puis nous stockons chaque tweet traité et son appreciation dans la base. A intervalle régulier, nous enregistrons l'appréciation générale sur une période donnée dans dans la base. 

## Composants

### Kafka

**Kafka** est un système de messagerie distribué. Il joue le rôle de *broker* pour des flux de données : des **producteurs** envoient des flux de données à Kafka, qui va les stocker et permettre à des **consommateurs** de traiter ces flux.

Chaque flux peut être partitionné, permettant à plusieurs consommateurs de travailler sur le même flux en parallèle. Une partition est une suite de messages ordonnée et immutable, chaque message ayant un identifiant qui lui est affecté.

**Kafka** fonctionne en cluster, permettant de répliquer les partitions pour être tolérant aux fautes, d'automatiquement balancer les consommateurs en cas de faute et d'être très facilement horizontalement scalable.

Dans notre cas, Kafka sera utilisé pour s'abonner aux flux Twitter et météo, et partitionner ces flux par région.

**Kafka** est tolérant aux pannes franches, du fait de la réplication des partitions sur les différents serveurs (réplication configurable). Cette tolérance est valable si on considère que les communications entre producteur et cluster Kafka sont fiables. En effet la réplication se fait au sein du cluster Kafka, les serveurs de réplication (**followers**) pour une partition donnée copiant la partition depuis le serveur référent (**leader**) pour cette partition. Dés lors si le producteur ne parvient pas à contacter le serveur référent, le message ne sera pas renvoyé et sera perdu. 

**Utilisé par :** Netflix, PayPal, Uber...

### Flink

**Apache Flink** est un framework de traitement temps-réel. Il permet donc de traiter des données arrivant en temps-réel, plutôt que par *batch*, et donc d'avoir un temps de latence extrêmement court.

En utilisant **Flink** pour traiter les flux fournis par Kafka, nous conservons l'aspect temps-réel qui fait la particularité de Twitter.

**Utilisé par :** Bouygues Telecom, Alibaba, Amadeus, ATOS...

### HBase

HBase est une base de données distribuée non-relationnelle. Cette technologie permet de stocker de larges quantités de données, et est très efficace pour les applications ayant un haut débit de données.

Hbase gère la réplication au sein du cluster, le sharding et le balancement de la charge. Le requêtage est extrêmement rapide et des des filtres peuvent être appliqués.

**Utilisé par :** Adobe, Airbnb, Facebook Messenger, Netflix...

**HBase** assure une cohérence stricte des écritures et lectures, c'est à dire qu'une lecture renvoie toujours le résultat de la dernière écriture effectuée.
HBase gère de manière automatique la réplication au sein du cluster ainsi que le basculement en cas de panne.

### Zeppelin

**Zeppelin** fournit une interface web de visualisation de données. Son principal intérêt est d'être capable d'analyser et mettre en forme de grandes quantités de données, et de s'intégrer très bien aux autres technologies (faisant partie de l'écosystème Apache).

Cet outil fournit de nombreuses graphes pour la visualisation de données, permettant de rapidement et facilement travailler sur de gros volumes.

Zeppelin, en tant que simple outil de visualisation, ne garantit rien en termes de tolérance aux fautes. Cependant, Zeppelin intervient en bout de chaîne et son plantage n'a aucune incidence sur le fonctionnement du reste des composants du système. 

## Architecture

#### Producer : Flink

Le **Producer** s'inscrit sur un flux twitter pour récupérer les tweets sur les régions désirées. A chaque réception de tweets, le produceur distribue les tweets sur **Kafka**

#### Distributeur : Kafka

Notre **Kafka** est découpé en ville, chaque *topic* correspond à une ville. Kafka stocke message par message les tweets pour chaque *topic*. 

#### Traitement : Flink

Nos **Flink** de traitement sont découpés en ville. Il récupère message par message, les tweets de leur ville dans le 'topic' 
associé dans **Kafka**. Il traite chaque tweet afin d'attribuer une appréciation au tweet et de calculer l'appréciation général. Ces **Flink** se chargent aussi de récupérer la météo pour sa ville. 

#### Base de données : HBase

Nous stockons chaque tweet dans une table correspondant à sa ville. 
Nous stockons les appréciations pour chaque ville dans une table différente. 

#### Visualisation : Zeppelin

Nous visualisons nos données grâce à **Zeppelin**

## Equipe

    ABOUBACAR Salim     DE GEA Jordan           DUCLOT William      
    HEINISCH Pierre     PEREZ Joseph            RACHDI Imane    
    STOFFEL Mathieu     TAVERNIER Vincent       THIOLLIERE Guillaume

## Informations

Environnement de déploiement : **Vagrant**

Outil de deploiement : **Rake**

## Pour commencer

### Lancer en developpement local

```bash
./start_vagrant.sh
export RAKE_ENV=development
./deploy.sh
```

### Lancer en production

Le document hosts.yml contient les informations de connexion aux machines de production. 

```bash
export RAKE_ENV=production
./deploy.sh
```


## Utilisation de Rake pour les tâches de maintenance

### Installation

```bash
# Installation de Bundler (once)
gem install bundler

# Installation de Rake + SSHKit (once)
# En cas d'incompatibilité avec Gemfile.lock sur le dépôt : bundle update
bundle
```

### Environnement

```bash
# Utilisation de l'environnement de développement
export RAKE_ENV=development
# Ne pas oublier de démarrer les machines virtuelles pour l'environnement de développement
(cd source/vagrant && vagrant up)

# Utilisation de l'environnement de production
export RAKE_ENV=production
```
### Deploiement

```bash
# Listing des tâches Rake avec leur description
rake -T

# Connexion SSH
rake ssh server-1

# Déploiement et provisioning
rake deploy

# Uniquement sur deux serveurs (définis dans hosts.yml)
rake deploy[server-2;server-3]
```

### Services

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

### Execution OneShot de commande

```bash
# Lancer la commande <commande> (défini dans le yaml config)
rake run:<commande>[<server1>,<server2>]
```




## Environnement de test Vagrant

Le dossier source/vagrant contient :

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

### Troubleshooting

#### vagrant plugin install vagrant-hostmanager échoue

sous debian il peut être nécessaire d'installer le paquet ruby-dev.
