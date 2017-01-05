      _____     _____     _______    _____  
     / ____|   |  __  \  |__   __|  |  __ \ 
    | (___     | |  | |     | |     | |  | |
     \___ \    | |  | |     | |     | |  | |
     ____) |   | |__| |     | |     | |__| |
    |_____/    |______/     |_|     |_____/ 

Système distribué pour le traitement de données.

[Précédent](../README.md)

# Configuration & Aide pour HBase

## [Pour commencer](Help/HBASE.md)

## Information

Pour découper l'enregistrement des tweets, on enregistre chaque tweet dans le lieu correspondant. C'est à dire, chaque lieu à sa propre table. De cette manière, on evite l'utilisation des filters. Le nom de la table est **<Place>_Tweets**

## Structure des tables

Table **<Place>_Tweet**
- ***RowIdentifier*** - *timestamp_UniqID* : concatenation timestamp et un identifiant pseudo unique. 
- **place** : le lieu
- **datas** : Le contenu de tout le tweet
- **feeling** : l'estimation de l'humeur de la personne