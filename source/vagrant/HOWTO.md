# Environnement de test Vagrant

Ce dossier contient :

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

# Lancer le provisioning (automatique lors de vagrant up)
vagrant provision

# Forcer la réinstallation
FORCE_PROVISION=yes vagrant provision

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

## Statut

Les machines démarrées avec Vagrant ont les composants suivants installés :

* java
* Zookeeper (géré par systemd, config /etc/zookeeper/zookeeper.conf)
* Kafka (géré par systemd, config /etc/kafka/kafka.conf)

## Troubleshooting

### vagrant plugin install vagrant-hostmanager échoue

sous debian il peut être nécessaire d'installer le paquet ruby-dev.
