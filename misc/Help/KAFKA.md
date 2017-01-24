      _____     _____     _______    _____  
     / ____|   |  __  \  |__   __|  |  __ \ 
    | (___     | |  | |     | |     | |  | |
     \___ \    | |  | |     | |     | |  | |
     ____) |   | |__| |     | |     | |__| |
    |_____/    |______/     |_|     |_____/ 

Système distribué pour traitement de données.

[Précédent](../KAFKA.md)

# Introduction concernant Apache Kafka

## Principe de fonctionnement
Apache Kafka est un système de **gestion de messages applicatifs**. 

En quelques mots, lorsque des informations doivent être stockées et 
communiquées de manière structurée entre plusieurs applications 
potentiellement hétérogènes, Apache Kafka est une des solutions 
envisageables. Ses caractéristiques intrinsèques permettent à Apache 
Kafka d'atteindre des performances, notamment en termes d'écriture
sur disque des messages à stocker. C'est pour cela qu'Apache Kafka 
occupe une position dominante lorsqu'il s'agit de **streaming** de
messages applicatifs.

Apache Kafka met à disposition des API permettant à toute application 
de se connecter à lui, dont notamment :
* une interface pour la production de message qui seront stockés 
et mis à disposition par Apache Kafka, on parle d'interface 
**Producer** ;
* une interface pour accéder aux messages stockés par Kafka, on parle d'interface **Consumer**.

L'architecture interne d'Apache Kafka repose sur le principe de 
**publication/abonnement**. Pour le dire plus simplement, Apache Kafka
offre la possibilité de structurer les messages stockés sous forme
de topics (généralement, la ségrégation des messages entre les
différents topics repose sur des considérations thématiques).
Les différents producteurs de messages peuvent alors décider dans
quel topic ils souhaitent publier leurs messages. 
De même, les consommateurs de messages peuvent choisir les topics
auxquels ils s'abonnent. Les messages étant stockés sur les 
périphériques de stockage de données physiques des machines hébergeant
Apache Kafka, plusieurs consommateurs différents peuvent s'abonner au
même topic, et chacun pour lire l'ensemble des messages y figurant
exactement une fois.

De plus, Apache Kafka est pensé pour être une application distribuée.
Ainsi, les fonctionnalités de réplication des messages entre 
différents serveurs (on réplique des *partitions*, une partition 
pouvant contenir plusieurs *topics*) sont nativement présentes.
Cela permet de mettre en place une politique de tolérance aux fautes
assez aisément.

## Dépendance envers Apache Zookeeper
Afin d'assurer les propriétés de réplication et de tolérance aux 
pannes explicitées ci-dessus, Apache Kafka a recours aux services
proposés par Apache Zookeeper.

En conséquence, avant d'instancier un cluster Apache Kafka, il faut
s'assurer d'avoir mis à disposition de ce dernier un quorum Zookeeper.

## Prendre Kafka en main
Afin de clôturer cette présentation rapide , voici quelques 
manipulations basiques pour établir un premier contact pratique 
avec Apache Kafka :
```bash
# Décompresser et se rendre dans le dossier d'Apache Kafka.
tar -xzf kafka_2.11-0.10.1.0.tgz
cd kafka_2.11-0.10.1.0
# Démarrer un daemon Apache Zookeeper.
bin/zookeeper-server-start.sh config/zookeeper.properties
# Démarrer un serveur Apache Kafka.
bin/kafka-server-start.sh config/server.properties
# Créer un topic dans une partition unique sans réplication.
bin/kafka-topics.sh --create --zookeeper localhost:2181 --replication-factor 1 --partitions 1 --topic test
# Lister les topics existants.
bin/kafka-topics.sh --list --zookeeper localhost:2181
# Publier des messages.
bin/kafka-console-producer.sh --broker-list localhost:9092 --topic test
This is a message
This is another message
# Lire lesdits messages.
bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic test --from-beginning
```
