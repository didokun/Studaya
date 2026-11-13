# AdMob — audit du 13 novembre 2026

## Intégration

- Google Mobile Ads 13.12.0, UMP 3.1.0 ; consentement actualisé à chaque lancement avant les requêtes.
- Debug : identifiants de test officiels Google. Release : identifiants de production configurés dans le projet Xcode.
- Bannières identifiées en haut des cinq onglets, des pages matière/cours et des réglages principaux.
- Une bannière comme élément de la liste de révisions du jour et du planning, si la liste contient au moins une séance.
- Interstitiel après validation d’une révision, fin d’un cours/TD, validation du bilan Focus, création d’une matière/cours/TD ou sortie de la création réussie d’un parcours.
- Un plafond global d’une heure écoulée depuis la dernière impression réelle, conservé entre lancements. Pas de popup tardive après un chargement réseau, ni d’interruption d’un Focus actif.
- Aucune publicité pour Premium, les moins de 18 ans, un âge absent, une appartenance Premium non encore déterminée ou lorsque UMP n’autorise pas les requêtes.
- Onboarding, consentement et achat ne reçoivent pas de bannière.
- Lien de politique intégré : https://talinha.com/studaya/privacy/

## À vérifier dans les consoles avant diffusion

1. Publier la politique corrigée dans le dépôt Talinha : l’ancienne version affirmait l’absence de SDK publicitaire. La modification locale ne publie pas le site.
2. App Store Connect : site développeur https://talinha.com ; politique https://talinha.com/studaya/privacy/. Compléter les déclarations de données pour Google Mobile Ads, pas « aucune donnée collectée » sans revue du SDK.
3. AdMob → Confidentialité et messages : créer et publier le message européen pour **Studaya** et ses autres messages régionaux applicables, avec la politique correcte. Le SDK UMP ne crée pas ces messages dans le compte.
4. Vérifier https://talinha.com/app-ads.txt, déjà présent dans `talinha/public/app-ads.txt` avec le même publisher ID que les unités Studaya. Demander la vérification dans AdMob puis contrôler l’approbation de l’app et sa liaison à la fiche App Store.
5. Confirmer le compte et les unités actifs, absence de restriction de diffusion, et les paramètres de contenu/audience. Cette intégration réserve les pubs aux majeurs.
6. Sur un appareil de test Google : vérifier bannière, consentement et fermeture d’interstitiel. Ne pas cliquer ses propres annonces de production.

## Vérifications locales

- Compilation Debug simulateur réussie.
- Tests ciblés : âge, appartenance Premium et plafond horaire (AdvertisingTests).
- Ressources publicitaires et âge disponibles dans les 16 langues.
- Compilation Release iPhone non signée réussie ; identifiants de production confirmés dans le fichier Info.plist produit.
- Trois tests ciblés réussis ; pas de campagne complète ni de validation de diffusion réelle dans le compte AdMob.

Le compte AdMob et les paramètres App Store Connect ne sont pas accessibles depuis le dépôt. La disponibilité publique de talinha.com n’a pas pu être confirmée depuis cet environnement : le proxy réseau renvoie une page de blocage Zscaler. Cela ne permet pas de conclure que le site est indisponible pour Google.

Sources :
- https://developers.google.com/admob/ios/privacy
- https://developers.google.com/admob/ios/interstitial
- https://developers.google.com/admob/ios/privacy/data-disclosure
- https://support.google.com/admob/answer/14538460
