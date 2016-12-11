      _____     _____     _______    _____  
     / ____|   |  __  \  |__   __|  |  __ \ 
    | (___     | |  | |     | |     | |  | |
     \___ \    | |  | |     | |     | |  | |
     ____) |   | |__| |     | |     | |__| |
    |_____/    |______/     |_|     |_____/ 

Système distribué pour traitement de données.

[Précédent](README.md)
# Architecture

### Producer : Flink

Le **Producer** s'inscrit sur un flux twitter pour récupérer les tweets sur les régions désirées. A chaque réception de tweets, le produceur distribue les tweets sur **Kafka**

### Distributeur : Kafka

Notre **Kafka** est découpé en ville, chaque *topic* correspond à une ville. Kafka stocke message par message les tweets pour chaque *topic*. 

### Traitement : Flink

Nos **Flink** de traitement sont découpés en ville. Il récupère message par message, les tweets de leur ville dans le 'topic' 
associé dans **Kafka**. Il traite chaque tweet afin d'attribuer une appréciation au tweet et de calculer l'appréciation général. Ces **Flink** se chargent aussi de récupérer la météo pour sa ville. 

### Base de données : HBase

Nous stockons chaque tweet dans une table correspondant à sa ville. 
Nous stockons les appréciations pour chaque ville dans une table différente. 

### Visualisation : Zeppelin

Nous visualisons nos données grâce à **Zeppelin**