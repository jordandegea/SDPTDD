      _____     _____     _______    _____  
     / ____|   |  __  \  |__   __|  |  __ \ 
    | (___     | |  | |     | |     | |  | |
     \___ \    | |  | |     | |     | |  | |
     ____) |   | |__| |     | |     | |__| |
    |_____/    |______/     |_|     |_____/ 

Système distribué pour le traitement de données.

[Précédent](../README.md)

# Configuration & Aide pour Flink Producer

## [Pour commencer](Help/FLINK.md)


## Information

Les sources des tâches sont dans le dossier `source/apps/FlinkProducer`. 

- FakeTwitter : Envoi periodiquement un tweet à kafka, dans une table défini aléatoirement. 


## Objectifs

Récupérer tous les tweets des lieux où nous souhaitons effectuer nos calculs. Sépare les tweets par lieu et les envoi sur Kafka sur le bon topic. 


## Paramètres

- `number of tweet par second` 
- `bootstrap server`

```bash
# Run example
bin/flink run FakeTwitter.jar 10 worker1:9092,worker2:9092,worker3:9092
```

## Autres

Lorsque des données sont perdues, nous ne cherchons pas à les récupérer. Si les calculs échouent de même. N'oublions pas l'esprit du Streaming. 
Si Kafka n'est pas accessible à un moment, on ne cherche pas a reenvoyer les tweets, on les oublie. 
