      _____     _____     _______    _____  
     / ____|   |  __  \  |__   __|  |  __ \ 
    | (___     | |  | |     | |     | |  | |
     \___ \    | |  | |     | |     | |  | |
     ____) |   | |__| |     | |     | |__| |
    |_____/    |______/     |_|     |_____/ 

Système distribué pour traitement de données.


# Comportement

Nous considérons 3 serveurs. Nous souhaitons garantir le fonctionnement du service en tolérant deux fautes. 

- Lorsque 3 machines sont en vie, alors le service fonctionne correctement.
- Lorsque 2 machines sont en vie, alors le service fonctionne correctement et cherche à remettre en place la machine en faute.
- Lorsque 1 machine est en vie, alors le service fonctionne correctement et à remettre en place les machines en faute. 

Nous executons le projet sur 3 villes : Paris, London, NYC
## Configuration

### Kafka

- Installé sur toutes les machines. 
- Un détecteur de faute se chargera de détecter les machines fautives.
- Un correcteur de faute cherchera à redémarrer la ou les machines fautives

### Flink

- Installé sur 3 machines. 
- Un détecteur de faute se chargera de répartir les différentes configurations de Flink sur les différents serveurs en vie

### Hbase

- Installé sur 3 machines. 
	
### Zeppelin

- Installé sur 3 machines. 
- Un détecteur de faute cherchera à redémarrer la ou les machines fautives 