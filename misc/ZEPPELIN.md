      _____     _____     _______    _____  
     / ____|   |  __  \  |__   __|  |  __ \ 
    | (___     | |  | |     | |     | |  | |
     \___ \    | |  | |     | |     | |  | |
     ____) |   | |__| |     | |     | |__| |
    |_____/    |______/     |_|     |_____/ 

Système distribué pour le traitement de données.

[Précédent](../README.md)

# Configuration & Aide pour Zeppelin

## [Pour commencer](Help/ZEPPELIN.md)

## Utilisation manuelle de Zeppelin
Si l'on souhaite gérer manuellement le cycle de vie d'Apache Zeppelin 
(c'est-à-dire sans avoir recours à *ServiceWatcher*), il est 
recommandé d'utiliser *systemd* :
``` bash
# Monitorer l'état d'Apache Zeppelin.
sudo systemctl status zeppelin
# Démarrer le service associé à Apache Zeppelin.
sudo systemctl start zeppelin
# Stopper le service associé à Apache Zeppelin.
sudo systemctl stop zeppelin
```

De plus, *systemd* essayera de redémarrer Apache Zeppelin en cas d'erreur
inopinée.

## Zeppelin via HAProxy
Dans le cadre de ce projet, la connection à Zeppelin peut s'effectuer directement
sur un des serveurs où HAProxy est lancé, sur le port 80, et la redirection vers
Apache Zeppelin s'effectuera automatiquement.