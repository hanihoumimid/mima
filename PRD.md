1. Vision du Produit
Utilisatrice : Personne âgée avec une dextérité et une vision réduites.

Objectif : Zéro oubli, zéro maintenance. L'application doit être une "boîte noire" qui sonne fidèlement, même après un redémarrage ou une extinction du téléphone.

2. Fonctionnalités Clés
Alarme "Action Unique" : L'alerte occupe tout l'écran. Un bouton massif "OK" pour confirmer la prise. L'appui désactive le son et replanifie instantanément pour le lendemain à la même heure exacte.

Auto-Réparation (Boot) : Utilisation d'un BroadcastReceiver natif (ou via plugin) pour que les alarmes soient reprogrammées en arrière-plan dès que le téléphone s'allume, sans intervention humaine.

Pas de décalage : Contrairement à un timer, l'alarme se base sur l'heure fixe définie (ex: 08:00). Si elle appuie sur OK à 08:15, la prochaine alarme reste à 08:00 le lendemain.

3. Design "3G" (Gros, Gras, Garanti)
Contraste : Noir sur blanc ou Jaune sur Noir.

Taille : Police minimum 24pt, boutons minimum 100px de hauteur.

Navigation : Une seule page. La liste des médicaments est le menu principal.