      _____     _____     _______    _____  
     / ____|   |  __  \  |__   __|  |  __ \ 
    | (___     | |  | |     | |     | |  | |
     \___ \    | |  | |     | |     | |  | |
     ____) |   | |__| |     | |     | |__| |
    |_____/    |______/     |_|     |_____/ 

Système distribué pour traitement de données.

[Précédent](../ZEPPELIN.md)

# Aide Zeppelin

## Information
Apache Zeppelin est un système de visualisation de données au travers d'une 
interface web. 
Il permet d'accéder et de mettre en forme de gros volumes de données,
de façon visuelle et interactive, afin de permettre leur analyse.

Grâce à un système de plugins et d'interpréteurs, Apache Zeppelin peut 
s'interfacer avec de nombreux systèmes et langages, ici notamment avec 
Apache HBase.

## Pour commencer
Une fois Apache Zeppelin lancé sur un serveur, il suffit de se connecter 
au serveur en question sur le port 8080 via un navigateur web pour y accéder.

Apache Zeppelin fonctionne grâce à des notes, permettant d'écrire les 
requêtes souhaitées aux différents systèmes avec lesquels Zeppelin
s'interface.

Pour créer un nouveau Notebook, cliquez sur *Notebook* -> *Create new note*.
Si l'intrepreteur du système ou langage que vous désirez utiliser est installé
et Apache Zeppelin correctement configuré, il suffira d'écrire en début de note
%*nom_du_système_ou_langage* puis d'écrire les commandes du système en question.
Par exemple pour Apache HBase, la note suivante permet de lister les tables :  
%hbase  
list  

La configuration de Apache Zeppelin dépend de l'interpréteur que l'on veut utiliser,
mais s'effectuera en modifiant les fichiers conf/zeppelin-env.sh et conf/zeppelin-site.xml
du dossier d'installation de Apache Zeppelin.