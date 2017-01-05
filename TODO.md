      _____     _____     _______    _____  
     / ____|   |  __  \  |__   __|  |  __ \ 
    | (___     | |  | |     | |     | |  | |
     \___ \    | |  | |     | |     | |  | |
     ____) |   | |__| |     | |     | |__| |
    |_____/    |______/     |_|     |_____/ 

Système distribué pour traitement de données.

# TODO


Vincent : 
    Il faudrait passer tout ce qui est HardCoding en dynamique


William : 
    Creer le Vrai producer Twitter. Le producer doit fonctionner avec des paramètres en entrée


Joseph :
    William a réussi a faire un pseudo distribué. Essaye de passer le pseudo HBase en HBase distribué. Si tu ne peux pas, voie avec William.


Selim : 
    Maintenant qu’on a HBase en pseudo distribué, tu peux vérifier que Zeppelin fonctionne


Jordan : 
    Je vais m’occuper de la structure de la base de données Hbase


Mathieu : 
    La vrai tache de HBase (j’ai fait des schema et tout, on se voit sur slack pour qu’on soit OK)


Guillaume : 
    On a besoin d’un service de monitoring qui fasse de la scalabilité horizontale et de la récupération de faute.(On voit ça ensemble sur Slack)
    Il faudrait s’intéresser au Benchmarking, c’est a dire créer un script ou quelque chose qui fasse des tests avec des faux tweets par exemple et voir comment réagit les serveurs et services.


Selim & Pierre : 
    Est-ce que c’est possible avec Zeppelin d’avoir une visualisation en temps réel ? C’est en dire, sans taper de commande et en ayant seulement Zepellin sur une machine de voir en temps réel les fluctuations, un peut comme la bourse.


Selim, Pierre & Guillaume : 
    A des fins de test, il nous faut penser a des scénarios d’interruptions. Du coup, il faudrait créer des scénarios que l’on test pour voir si nos machines fonctionne. Ce sera une sorte de système d’intégration continue pour le projet


Imane : 
    Je préfère ne pas t’attribuer de tache pour le moment. Apprend git et essaye de rattraper le retard sur le code. Tu peux poser des questions sur slack si tu ne comprends pas tout.


Tout le monde: 
    On est noté sur la qualité des scripts et la documentation. Du coup, exercez vous de faire de jolie script et de mettre des README dans chaque petit bout de code que vous faites