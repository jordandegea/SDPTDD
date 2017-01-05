      _____     _____     _______    _____  
     / ____|   |  __  \  |__   __|  |  __ \ 
    | (___     | |  | |     | |     | |  | |
     \___ \    | |  | |     | |     | |  | |
     ____) |   | |__| |     | |     | |__| |
    |_____/    |______/     |_|     |_____/ 

Système distribué pour traitement de données.

# TODO

Pour qui ?
  Mettre en place la scalabilité horizontal afin d'ajouter des machines à Zookeeper. 


William & Joseph : 
  HBASE en distribué


Selim : 
    Maintenant qu’on a HBase en pseudo distribué, tu peux vérifier que Zeppelin fonctionne

Guillaume & Pierre : 
    Installation et configuration de HAProxy sur les serveurs. Chaque serveur ferait tourner une instance de HAProxy qui fait du load-balancing entre tous les autres serveurs. Je m'explique : si on fait tourner Zeppelin sur le port 8080 (très original :slightly_smiling_face: ) HAProxy tournerait sur le port 80 et transmettrait les requêtes à n'importe quel membre du cluster qui fait tourner Zeppelin. Là où il y a de la valeur ajoutée, c'est que Quéma pourrait effectivement buter n'importe quel serveur, mais il suffirait pour nous de prendre n'importe quel autre et on aurait toujours accès à l'interface de l'appli.

    HAProxy détecte tout seul les serveurs "alive" en testant s'il peut établir la connexion sur le port de destination (celui de Zeppelin en l'occurrence), donc y a vraiment rien à faire. A part lire la doc pendant environ 12 minutes et 27 secondes.

Mathieu : 
    La vrai tache de Flink (j’ai fait des schema et tout, on se voit sur slack pour qu’on soit OK)


Selim : 
    Il faudrait s’intéresser au Benchmarking, c’est a dire créer un script ou quelque chose qui fasse des tests avec des faux tweets par exemple et voir comment réagit les serveurs et services.


Selim & Pierre : 
    Est-ce que c’est possible avec Zeppelin d’avoir une visualisation en temps réel ? C’est en dire, sans taper de commande et en ayant seulement Zepellin sur une machine de voir en temps réel les fluctuations, un peut comme la bourse.


Selim, Pierre & Guillaume : 
    A des fins de test, il nous faut penser a des scénarios d’interruptions. Du coup, il faudrait créer des scénarios que l’on test pour voir si nos machines fonctionne. Ce sera une sorte de système d’intégration continue pour le projet


Imane : 
    Creer le Vrai producer Twitter. Le producer doit fonctionner avec des paramètres en entrée


Tout le monde: 
    On est noté sur la qualité des scripts et la documentation. Du coup, exercez vous de faire de jolie script et de mettre des README dans chaque petit bout de code que vous faites