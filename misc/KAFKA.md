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
