      _____     _____     _______    _____  
     / ____|   |  __  \  |__   __|  |  __ \ 
    | (___     | |  | |     | |     | |  | |
     \___ \    | |  | |     | |     | |  | |
     ____) |   | |__| |     | |     | |__| |
    |_____/    |______/     |_|     |_____/ 

Système distribué pour traitement de données.

[Précédent](../HBASE.md)

# Aide HBASE

## Information

HBase enregistre les données sous forme de ligne texte. Chaque ligne correspond à un couple *<row, column>*. 
Par exemple, 
`row1      column=col1:a, timestamp=1481392727887, value=value2`

- **row1** est l'identifiant de la ligne, HBase store les données par leur identifiant de ligne en respectant l'ordre lexicographique. 
- **col1** est le nom de la colonne
- **a** est un *qualifier*. Une colonne peut contenir un nombre illimité de *qualifier*. Nous ne l'utiliserons pas dans ce projet. 
- **timestamp** est l'heure à laquelle le donnée a été ecrite. 
- **value2** est la valeur dans la colonne. 

## Pour commencer

```bash
# Creer la table "test" avec deux colonnes "col1", "col2" 
create 'test', 'col1', 'col2'

# Inserer une ligne avec l'identifiant <row1>
# La commande <Put> entre colonne par colonne, remplissons les deux colonnes
put 'test', 'row1', 'col1', 'value11'
put 'test', 'row1', 'col2', 'value12'

# Ecrire d'autres lignes pour la demonstration
put 'test', 'row2', 'col1', 'value21'
put 'test', 'row2', 'col2', 'value22'
put 'test', 'row3', 'col1', 'value31'
put 'test', 'row3', 'col2', 'value32'
put 'test', 'row4', 'col1', 'value41'
put 'test', 'row4', 'col2', 'value42'

# Afficher tout le contenu
scan 'test'

# Afficher depuis <row2> jusqu'à <row4> exclu
scan 'test', {STARTROW => 'row2', ENDROW => 'row4'}
scan 'test', {STARTROW => 'row2', STOPROW => 'row4' }

# HBase cherche par prefix. Les deux commandes suivantes fournissent le meme resultat.
scan 'test', {STARTROW => 'row'}
scan 'test', {STARTROW => 'row1'}

# Afficher avec un filtre sur la colonne
scan 'test', { STARTROW=>'row2', STOPROW=>'row4', COLUMNS=>'col1'}

# Afficher les colonnes pour la ligne *row*
get 'test', 'row1'

# Mettre a jour une valeur
put 'test', 'row4', 'col2', 'newvalue42'

# Vider une table
truncate 'test'

# Desactiver une table
disable 'test'

# Supprimer une table
drop 'test'

```
