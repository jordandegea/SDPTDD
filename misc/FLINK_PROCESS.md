      _____     _____     _______    _____  
     / ____|   |  __  \  |__   __|  |  __ \ 
    | (___     | |  | |     | |     | |  | |
     \___ \    | |  | |     | |     | |  | |
     ____) |   | |__| |     | |     | |__| |
    |_____/    |______/     |_|     |_____/ 

Système distribué pour traitement de données.

[Précédent](../README.md)

# Configuration & Aide pour Flink Processing

## [Pour commencer](Help/FLINK.md)


## Information

Le source des tâches sont dans le dossier `source/apps/FlinkProcess`. 

- KafkaToConsole : Recupere les tweets de Kafka et les écrits dans la console
- KafkaToHBase : Récupère les tweets de Kafka et les envoi à HBase

## Objectifs

Toutes les ***S*** secondes, nous écrivons l'humeur estimé sur les ***M*** dernière minutes dans la base de données. 
Pour cela, toute les ***X*** minutes, nous récupérons la météo et l'enregistrons localement. 

Nous prenons ***S*** = 10, et ***M*** = 10, ***X*** = 10

Les tweets sont continuellement récupérés de Kafka, estimé et enregistré dans HBase. 

## Autres

Lorsque des données sont perdus, nous ne cherchons pas à les récupérer. Si les calculs échoue de même. N'oublions pas l'esprit du Streaming. 