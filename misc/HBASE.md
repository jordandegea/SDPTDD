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

Les resultats sont enregistré dans la table **Feelings**. 

Pour découper l'enregistrement des tweets, on enregistre chaque tweet dans le lieu correspondant. C'est à dire, chaque lieu à sa propre table. De cette manière, on evite l'utilisation des filters. Le nom de la table est **<Place>_Tweets**

## Structure des tables

Table **Feelings**
 - ***RowIdentifier*** - *timestamp_place* : concatenation du timestamp a l'ecriture et du lieu
 - **place** : le lieu
 - **feeling** : La valeur moyenne de l'humeur
 - **datas** : Les données entières des infos météorologiques récupérées sous forme minimal/compressé. 
 - **temperature** : La température moyenne
 - **wind** : La vitesse du vent
 - **cloud** : Indice sur les nuages
 - **rain** : Indice sur la pluie
 - **snow** : Indice sur la neige

Table **<Place>_Tweet**
- ***RowIdentifier*** - *timestamp_UniqID* : concatenation timestamp et un identifiant pseudo unique. 
- **datas** : Le contenu de tout le tweet
- **feeling** : l'estimation de l'humeur de la personne