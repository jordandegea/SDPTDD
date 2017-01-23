      _____     _____     _______    _____  
     / ____|   |  __  \  |__   __|  |  __ \ 
    | (___     | |  | |     | |     | |  | |
     \___ \    | |  | |     | |     | |  | |
     ____) |   | |__| |     | |     | |__| |
    |_____/    |______/     |_|     |_____/ 

Système distribué pour le traitement de données.

[Précédent](../README.md)

[Sources](../source/apps/ServiceWatcher)

# ServiceWatcher

ServiceWatcher est un orchestrateur distribué pour la gestion de services
systemd. Son rôle est de s'assurer qu'un certain ensemble de services (définis
physiquement par des unités service systemd) est disponible sur l'ensemble des
serveurs exécutant le service ServiceWatcher.

ZooKeeper est utilisé pour distribuer le processus d'orchestration, ainsi que la
gestion des fautes des machines membres du cluster.

Il s'agit d'une application développée en Python, utilisant [Kazoo](https://kazoo.readthedocs.io/en/latest/),
un client Python pour ZooKeeper, ainsi que [pydbus](https://github.com/LEW21/pydbus),
afin de s'interfacer nativement (via DBus) avec le processus systemd.

## Installation

L'installation de ServiceWatcher sur les machines cibles s'effectue de la 
manière suivante :

```bash
# Extraction de l'archive du code
tar --strip-components=1 -C "$SERVICE_WATCHER_INSTALL_DIR" -xf "files/service_watcher.tar.xz"

# Installation des dépendances
apt-get -qq install -y libyaml-dev python-gi
pip install --quiet -r "$SERVICE_WATCHER_INSTALL_DIR/requirements.txt"
```

Afin d'assurer l'exécution de ServiceWatcher même en cas de crash du processus
ou de redémarrage de l'instance, il est recommandé d'utiliser systemd pour gérer
le processus, en créant un service :

```bash
echo "[Unit]
Description=Twitter Weather ServiceWatcher
Requires=network.target
After=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$SERVICE_WATCHER_INSTALL_DIR
ExecStart=/usr/bin/python $SERVICE_WATCHER_INSTALL_DIR/service_watcher.py monitor --config $SERVICE_WATCHER_CONFIG
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
SyslogIdentifier=service_watcher

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/service_watcher.service

systemctl daemon-reload
```

Ce service peut être ensuite activé au démarrage (`systemctl enable
service_watcher`) puis démarré (`systemctl start service_watcher`).

## Configuration des services orchestrés

ServiceWatcher utilise un fichier de configuration pour définir les services
devant être orchestrés. Ce fichier doit être *identique* sur tous les serveurs
membres du cluster. Le comportement si les configurations diffèrent est non
spécifié.

Voici un exemple de fichier de configuration (celui utilisé en développement) :

```yaml
---
zookeeper:
  quorum: zookeeper_quorum_replace_me
  timings:
    loop_tick: 0.5
    failed_loop_tick: 1.0
    partitioner_boundary: 1.0
    partitioner_reaction: 0.2
services:
  - name: dummy_global
    enabled: false
    type: global
  - name: dummy_shared
    prestart: |
      #!/bin/bash
      echo "dummy_multi@3 is running on {instance:dummy_multi@3}"
    count: 2
  - name: dummy_multi
    force:
      '1': worker2
    instances:
      '1': 1
      '2': 2
      '3': 3
```

### `zookeeper`

Cette section définit les paramètres du client ZooKeeper, comme l'ensemble des
serveurs auxquels se connecter en tant que client (remplacé lors du
déploiement par la liste de serveurs), ainsi que différents délais (en
secondes).

#### `zookeeper/timings`

Voir le code de ServiceWatcher pour plus de détails sur l'utilisation de ces
valeurs de timing.

* `loop_tick` : temps maximal d'attente lors des itérations de boucle
d'orchestration.
* `failed_loop_tick` : temps maximal d'attente lors des itérations de boucle
d'une attente de réinitialisation d'un service `failed`.
* `partitioner_boundary` : temps de stabilisation du système de partition.
* `partitioner_reaction` : temps de réaction d'un client du système de
partition.

### `services`

Cette section définit la liste des services qui devront être orchestrés. Les
différents types de services sont décrits ci-dessous.

### Service `global`

#### Déclaration

* `name` : nom de l'unité systemd correspondant au service.
* `enabled` : booléen, active ou désactive le service.
* `type: global` : indique que ce service est de type global.

#### Comportement

Un service global est un service dont une instance est exécutée sur chaque
serveur, quelque soit le nombre de serveurs.

C'est une simple surcouche à systemd, qui permet de maintenir un état distribué
des services.

### Service `shared`

#### Déclaration

* `name` : nom de l'unité systemd correspondant au service.
* `enabled` : booléen, active ou désactive le service.
* `count` : nombre d'instances du service demandées.
* `type: shared` : (optionel si `count` est spécifié) indique que ce service
est de type shared.

#### Comportement

Un service shared est un service qui est planifié sur l'ensemble des serveurs de
manière à atteindre le nombre d'instances spécifiées. Au plus une instance du
service est en cours d'exécution sur chaque serveur.

Si le nombre de serveurs disponibles `n` est inférieur au nombre de services
demandés `m`, seules `n` instances du service seront démarrées.

Si un serveur n'arrive pas à démarrer le service (systemd reporte `failed`),
alors le serveur concerné est retiré de la liste des serveurs disponibles tant
que celui-ci n'a pas été réinitialisé par l'une des deux commandes ci-dessous :

```bash
# Réinitialisation du service failed
systemctl reset-failed dummy_shared

# Réinitialisation de tous les services failed
systemctl reload service_watcher
```

### Service `multi`

### Déclaration

* `name` : nom de base du template d'unité systemd correspondant au service.
* `enabled` : booléen, active ou désactive le service.
* `instances` : ensemble de clés et de valeurs indiquant, pour chaque paramètre
du template d'unité systemd (clé) le nombre d'instances désirées (valeur).
* `force` : tableau associatif où les clés désignent des instances du service
template, et les valeurs le hostname de la machine cible. Les instances
spécifiées ne peuvent avoir qu'un nombre attendu d'instances de 1.
* `type: multi` : (optionel si `instances` est spécifié) indique que ce service
est de type multi.

### Comportement

Lecture conseillée : [systemd.unit](https://www.freedesktop.org/software/systemd/man/systemd.unit.html)

Un service `multi` peut être vu comme un ensemble de services `shared`. En
effet, pour chaque instance `X` définie dans la section correspondante :

* Au plus une instance du service `dummy_multi@X` sera en cours d'exécution par
serveur.
* Le nombre d'instances demandé pour `dummy_multi@X` est réparti sur l'ensemble
des serveurs disponibles pour ce service.
* Si une instance est spécifiée dans `force`, elle ne sera allouée que si le
pair dont le hostname est spécifié est disponible.

## Contrôle du service

Nous supposons ici que ServiceWatcher a été configuré via systemd. Les
opérations suivantes sont possibles :

```bash
# Rejoindre le cluster, démarrer les services globaux et les services assignés
# par l'orchestration
systemctl start service_watcher

# Arrêter les services et quitter le cluster
systemctl stop service_watcher

# Recharger la configuration, réinitialiser les services "failed" et demander un
# nouveau partitionnement
systemctl reload service_watcher

# Afficher l'état du cluster
service_watcher status --config /usr/local/service_watcher/config.yml
```

## Tolérance aux pannes

ServiceWatcher résiste aux pannes suivantes :

* Perte du serveur ZooKeeper : l'instance choisie comme serveur pour l'accès au
cluster ZooKeeper n'est plus disponible. Une autre instance sera choisie, et un
nouveau partitionnement sera choisi.
* Crash du processus ServiceWatcher : les services en cours d'exécution sont
maintenus le temps que le service redémarre, et qu'un nouveau partitionnement
aie lieu.
* Disparition d'une machine : les services en cours d'exécution sont
partitionnés vers une nouvelle machine.
* Passage en `failed` d'un service géré : ce service est planifié vers une autre
machine grâce à un nouveau partitionnement.
