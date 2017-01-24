      _____     _____     _______    _____  
     / ____|   |  __  \  |__   __|  |  __ \ 
    | (___     | |  | |     | |     | |  | |
     \___ \    | |  | |     | |     | |  | |
     ____) |   | |__| |     | |     | |__| |
    |_____/    |______/     |_|     |_____/ 

Système distribué pour le traitement de données.

[Précédent](../README.md)

# Configuration d'Apache Kafka

## [Pour commencer](Help/KAFKA.md)
Le titre de la présente partie est un lien qui renvoie vers une 
introduction succinte à l'utilisation d'Apache Kafka.

## Gestion manuelle du cycle de vie
Si l'on souhaite gérer manuellement le cycle de vie d'Apache Kafka 
(c'est-à-dire sans avoir recours à *ServiceWatcher*), il est 
recommandé d'utiliser *systemd* :
``` bash
# Monitorer l'état d'Apache Kafka.
sudo systemctl status kafka
# Démarrer le service associé à Apache Kafka.
sudo systemctl start kafka
# Stopper le service associé à Apache Kafka.
sudo systemctl stop kafka
```

De plus, *systemd* essayera de redémarrer Apache Kafka en cas d'erreur
inopinée.

## Architecture externe du cluster Apache Kafka
Dans le but d'assurer une tolérance aux fautes de l'ordre de 2 pannes, nous
avons opté pour un cluster de trois serveurs Apache Kafka (et un quorum Zookeeper
sous-jacent de même taille), avec un facteur de réplication de 3 pour les partitions.

## Architecture interne du cluster Apache Kafka
Afin de profiter des propriétés de réplication offertes par Apache Kafka tout
en assurant une répartition viable de la charge de données, nous avons
décidé d'instancier une partition (comptant donc un unique topic) par ville.

En effet, la réplication proposée par Apache Kafka est une réplication au
niveau des partitions. Ainsi, dans l'hypothèse où nous aurions opté pour un
topic par ville, l'ensemble des données aurait été contenu dans une seule
partition. Cela explique notre choix d'instancier une partition par ville.

Pour résumer l'architecture interne adoptée pour le cluster Apache Kafka :
* Partition **_nycconsumer_** :
  * Topic **_tweets_**.
* Partition **_londonconsumer_** :
  * Topic **_tweets_**.
* Partition **_parisconsumer_** :
  * Topic **_tweets_**.
