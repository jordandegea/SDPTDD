      _____     _____     _______    _____  
     / ____|   |  __  \  |__   __|  |  __ \ 
    | (___     | |  | |     | |     | |  | |
     \___ \    | |  | |     | |     | |  | |
     ____) |   | |__| |     | |     | |__| |
    |_____/    |______/     |_|     |_____/ 

Système distribué pour traitement de données.

# TODO


William & Joseph : 
  HBASE en distribué


Selim : 
    Maintenant qu’on a HBase en pseudo distribué, tu peux vérifier que Zeppelin fonctionne


Mathieu : 
    La vrai tache de Flink (j’ai fait des schema et tout, on se voit sur slack pour qu’on soit OK)


Guillaume : 
    Il faudrait s’intéresser au Benchmarking, c’est a dire créer un script ou quelque chose qui fasse des tests avec des faux tweets par exemple et voir comment réagit les serveurs et services.


Selim & Pierre : 
    Est-ce que c’est possible avec Zeppelin d’avoir une visualisation en temps réel ? C’est en dire, sans taper de commande et en ayant seulement Zepellin sur une machine de voir en temps réel les fluctuations, un peut comme la bourse.


Selim, Pierre & Guillaume : 
    A des fins de test, il nous faut penser a des scénarios d’interruptions. Du coup, il faudrait créer des scénarios que l’on test pour voir si nos machines fonctionne. Ce sera une sorte de système d’intégration continue pour le projet


Imane : 
    Creer le Vrai producer Twitter. Le producer doit fonctionner avec des paramètres en entrée


Tout le monde: 
    On est noté sur la qualité des scripts et la documentation. Du coup, exercez vous de faire de jolie script et de mettre des README dans chaque petit bout de code que vous faites