      _____     _____     _______    _____  
     / ____|   |  __  \  |__   __|  |  __ \ 
    | (___     | |  | |     | |     | |  | |
     \___ \    | |  | |     | |     | |  | |
     ____) |   | |__| |     | |     | |__| |
    |_____/    |______/     |_|     |_____/ 

Système distribué pour le traitement de données.

[Précédent](../README.md)
# Composants

## Kafka

>**Kafka** est un système de messagerie distribué. Il joue le rôle de *broker* pour des flux de données : des **producteurs** envoient des flux de données à Kafka, qui va les stocker et permettre à des **consommateurs** de traiter ces flux.

>Chaque flux peut être partitionné, permettant à plusieurs consommateurs de travailler sur le même flux en parallèle. Une partition est une suite de messages ordonnée et immutable, chaque message ayant un identifiant qui lui est affecté.

>**Kafka** fonctionne en cluster, permettant de répliquer les partitions pour être tolérant aux fautes, d'automatiquement balancer les consommateurs en cas de faute et d'être très facilement horizontalement scalable.

>Dans notre cas, Kafka sera utilisé pour s'abonner aux flux Twitter et météo, et partitionner ces flux par région.

>**Kafka** est tolérant aux pannes franches, du fait de la réplication des partitions sur les différents serveurs (réplication configurable). Cette tolérance est valable si on considère que les communications entre producteur et cluster Kafka sont fiables. En effet la réplication se fait au sein du cluster Kafka, les serveurs de réplication (**followers**) pour une partition donnée copiant la partition depuis le serveur référent (**leader**) pour cette partition. Dés lors si le producteur ne parvient pas à contacter le serveur référent, le message ne sera pas renvoyé et sera perdu. 

>**Utilisé par :** Netflix, PayPal, Uber...


## Flink

>**Apache Flink** est un framework de traitement temps-réel. Il permet donc de traiter des données arrivant en temps-réel, plutôt que par *batch*, et donc d'avoir un temps de latence extrêmement court.

>En utilisant **Flink** pour traiter les flux fournis par Kafka, nous conservons l'aspect temps-réel qui fait la particularité de Twitter.

>**Utilisé par :** Bouygues Telecom, Alibaba, Amadeus, ATOS...

## HBase

>HBase est une base de données distribuée non-relationnelle. Cette technologie permet de stocker de larges quantités de données, et est très efficace pour les applications ayant un haut débit de données.

>Hbase gère la réplication au sein du cluster, le sharding et le balancement de la charge. Le requêtage est extrêmement rapide et des des filtres peuvent être appliqués.

>**Utilisé par :** Adobe, Airbnb, Facebook Messenger, Netflix...

>**HBase** assure une cohérence stricte des écritures et lectures, c'est à dire qu'une lecture renvoie toujours le résultat de la dernière écriture effectuée.
HBase gère de manière automatique la réplication au sein du cluster ainsi que le basculement en cas de panne.

## Zeppelin

>**Zeppelin** fournit une interface web de visualisation de données. Son principal intérêt est d'être capable d'analyser et mettre en forme de grandes quantités de données, et de s'intégrer très bien aux autres technologies (faisant partie de l'écosystème Apache).

>Cet outil fournit de nombreuses graphes pour la visualisation de données, permettant de rapidement et facilement travailler sur de gros volumes.

>Zeppelin, en tant que simple outil de visualisation, ne garantit rien en termes de tolérance aux fautes. Cependant, Zeppelin intervient en bout de chaîne et son plantage n'a aucune incidence sur le fonctionnement du reste des composants du système. 