      _____     _____     _______    _____  
     / ____|   |  __  \  |__   __|  |  __ \ 
    | (___     | |  | |     | |     | |  | |
     \___ \    | |  | |     | |     | |  | |
     ____) |   | |__| |     | |     | |__| |
    |_____/    |______/     |_|     |_____/ 

Système distribué pour le traitement de données.

[Précédent](../README.md)

# Configuration & Aide pour Flink Processing

## [Pour commencer](Help/FLINK.md)


## Information

Les sources des tâches sont dans le dossier `source/apps/FlinkProcess`. 

- KafkaToConsole : Recupere les tweets de Kafka et les écrits dans la console
- KafkaToHBase : Récupère les tweets de Kafka et les envoi à HBase


## Objectifs

Toutes les ***S*** secondes, nous écrivons l'humeur estimée sur les ***M*** dernières minutes dans la base de données. 
Pour cela, toute les ***X*** minutes, nous récupérons la météo et l'enregistrons localement. 

Nous prenons ***S*** = 10, et ***M*** = 10, ***X*** = 10

Les tweets sont continuellement récupérés de Kafka, estimés et enregistrés dans HBase. 


## Paramètres

- `--port <flink port>` 
- `--topic <place>`
- `--bootstrap.servers <bootstrap servers>`
- `--zookeeper.connect <zookeeper machine:port>`
- `--group.id <consumer group>`
- `--hbasetable <topic name>`
- `--hbasequorum <hbase quorum>` 
- `--hbaseport <port of hbase quorum>`

```bash
# Run example
bin/flink run KafkaConsoleBridge.jar \
	--port 9000 \
	--topic paris \
	--bootstrap.servers worker1:9092,worker2:9092,worker3:9092 \
	--zookeeper.connect localhost:2181 \
	--group.id parisconsumer \
	--hbasetable paris_tweets \
	--hbasequorum worker1,worker2,worker3 \
	--hbaseport 2181

```

## Autres

Lorsque des données sont perdues, nous ne cherchons pas à les récupérer. Si les calculs échouent de même. N'oublions pas l'esprit du Streaming. 