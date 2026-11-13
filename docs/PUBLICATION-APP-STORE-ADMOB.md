# Studaya — publication App Store et AdMob de bout en bout

Document de référence du lancement du 13 novembre 2026, établi à partir de notre conversation, des captures App Store Connect et des fichiers du projet. Il couvre la préparation, les champs à remplir, les achats, la publicité, la soumission et le suivi.

**État constaté à 14 h 38 : soumission envoyée, en attente de vérification Apple.** Cela ne signifie pas encore « approuvée » ou « disponible dans l’App Store ».

Les valeurs marquées **confirmées** ont été vues dans le projet ou les captures. Les textes proposés peuvent être copiés après vérification de leur correspondance avec la version distribuée. Les réglages de confidentialité dépendent du comportement réel de l’app et des SDK : ne pas réutiliser cette déclaration sans revue lors d’une modification.

## Sommaire

1. [État du lancement et points ouverts](#1-état-du-lancement-et-points-ouverts)
2. [Ce qu’il faut préparer](#2-ce-quil-faut-préparer)
3. [Identifiants et URLs](#3-identifiants-et-urls)
4. [Préparer et envoyer le build Xcode](#4-préparer-et-envoyer-le-build-xcode)
5. [Créer la fiche App Store](#5-créer-la-fiche-app-store)
6. [Textes de la fiche produit](#6-textes-de-la-fiche-produit)
7. [Captures, icône et vidéo de démonstration](#7-captures-icône-et-vidéo-de-démonstration)
8. [Informations générales et classification](#8-informations-générales-et-classification)
9. [Confidentialité et suivi publicitaire](#9-confidentialité-et-suivi-publicitaire)
10. [Tarifs et territoires](#10-tarifs-et-territoires)
11. [Premium : groupe, abonnements et achat à vie](#11-premium--groupe-abonnements-et-achat-à-vie)
12. [Informations pour App Review](#12-informations-pour-app-review)
13. [AdMob : configuration et placements](#13-admob--configuration-et-placements)
14. [Soumission et publication](#14-soumission-et-publication)
15. [Problèmes rencontrés et solutions](#15-problèmes-rencontrés-et-solutions)
16. [Checklist réutilisable et références](#16-checklist-réutilisable-et-références)

## 1. État du lancement et points ouverts

### Éléments envoyés

| Élément | Valeur / état confirmé |
|---|---|
| App | Studaya, iOS 1.0, build 2 |
| Achat à vie | Studaya Premium Lifetime — en attente de vérification |
| Abonnement mensuel | Studaya Premium Monthly — en attente de vérification |
| Abonnement annuel | Studaya Premium Yearly — en attente de vérification |
| Groupe | Studaya Premium — en attente de vérification |
| Date de soumission | 13 novembre 2026, 14 h 37 |
| Identifiant de soumission | `37bbfc12-f434-47be-ac2f-a3daf8babbd6` |
| Compte utilisé | Compte personnel Adil Echcharafi |

Le groupe est un cinquième élément distinct : mon indication précédente de « quatre éléments » comptait seulement l’app et les trois produits.

### Points à ne pas considérer comme validés

- **Suivi / ATT :** le formulaire publié déclare l’identifiant de l’appareil utilisé pour le suivi, mais le build 2 ne demande pas l’autorisation ATT et ne contient pas `NSUserTrackingUsageDescription`. Ce point n’a pas été résolu avant l’envoi. Il faut examiner les requêtes et paramètres publicitaires réels, puis aligner code, politique et déclaration. L’absence de demande ATT ne démontre pas à elle seule l’absence de suivi ; le manifeste du SDK décrit ses capacités et ne prouve pas à lui seul chaque usage effectif de Studaya.
- **Politique du site :** le texte local Talinha a été corrigé pour AdMob/UMP. Son déploiement public n’a pas été confirmé. Une modification du dépôt ne publie pas le site.
- **Console AdMob :** publication des messages UMP, validation du compte, association App Store, vérification app-ads.txt et autorisation de diffusion non confirmées dans cette conversation.
- **Prix Lifetime :** 79,99 USD était la valeur proposée ; le montant final de la console n’a pas été lisiblement confirmé. Ne pas présenter 80 USD du simulateur comme preuve du prix réel.
- La capture de soumission ne prouve pas que la vidéo de démonstration a été jointe : vérifier sa présence sur la fiche de version.

Pour traiter le suivi : soit mettre en œuvre une demande ATT et respecter le refus avant tout suivi, soit garantir une configuration sans suivi et déclarer ce comportement vérifié. Une simple modification de la réponse du formulaire ou l’ajout de la clé plist sans gestion du consentement ne suffit pas. Si un nouveau binaire est nécessaire, retirer la version de la vérification, envoyer un build supérieur puis soumettre à nouveau.

## 2. Ce qu’il faut préparer

### Comptes et informations

- Compte Apple Developer payant actif, accès App Store Connect et signature Xcode avec la même équipe.
- Identité exacte de l’éditeur ; ici le compte personnel a été choisi. Le Kbis de la société de l’épouse n’a pas servi à changer le compte de publication.
- Coordonnées de revue : prénom, nom, téléphone joignable avec indicatif, email consulté.
- Accords applicables aux apps payantes/achats, informations fiscales et bancaires dans Business. Ne pas copier des coordonnées bancaires, secrets ou documents d’identité dans ce guide.
- Compte AdMob, application iOS et unités publicitaires.
- Site d’assistance, politique de confidentialité, conditions et fichier app-ads.txt publiés.

### Fichiers et preuves

- Icône de production dans le catalogue d’assets, notamment ressource App Store 1024 × 1024 conforme aux contraintes Xcode.
- Archive Release signée et version/build cohérents entre app et extension.
- Captures réelles iPhone et iPad si l’app déclare prendre en charge l’iPad.
- Une capture du paywall pour chaque produit envoyé à la revue, avec la formule correspondante sélectionnée.
- Vidéo courte montrant le parcours réel si utile ou demandée par Apple.
- Textes marketing, mots-clés, notes de revue et accès gratuit clairement visible.
- Vérification ciblée : démarrage, création matière/cours/TD, planning, notifications dans la langue de l’app, minuteur, achats/restauration et consentement publicitaire.

## 3. Identifiants et URLs

| Champ | Valeur |
|---|---|
| Nom | `Studaya` |
| Bundle ID app | `app.studaya.ios` |
| Bundle ID extension Focus | `app.studaya.ios.focus` |
| Apple Team ID | `U4X7CC9N42` |
| Apple ID de l’app | `6834361770` |
| SKU / UGS | `studaya-ios` |
| Version marketing | `1.0` |
| Build soumis | `2` |
| Langue principale de la fiche | Anglais (États-Unis) |
| Site marketing | `https://talinha.com/studaya/` |
| Assistance | `https://talinha.com/studaya/contact/` |
| Confidentialité | `https://talinha.com/studaya/privacy/` |
| Page juridique du site | `https://talinha.com/studaya/legal/` |
| EULA Apple standard | `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/` |
| Email d’assistance du site | `support@talinha.com` |
| Fiche App Store après publication | `https://apps.apple.com/app/id6834361770` |

La langue principale de la fiche n’impose pas la langue de l’app : celle-ci suit les préférences iOS parmi les ressources disponibles. Les métadonnées App Store se traduisent séparément des ressources de l’app.

## 4. Préparer et envoyer le build Xcode

1. Ouvrir `Studaya.xcodeproj`, choisir le scheme **Studaya**.
2. Dans Signing & Capabilities, sélectionner l’équipe du compte de publication et vérifier les Bundle IDs de l’app et du widget.
3. Conserver la version `1.0` ; incrémenter le build à chaque nouvel envoi : après le build 2, utiliser au minimum `3`.
4. Vérifier la configuration **Release** et les identifiants AdMob de production. Debug utilise les unités de test.
5. Choisir une destination générique iOS / Any iOS Device puis **Product → Archive**.
6. Dans Organizer → Archives, sélectionner la bonne archive, **Distribute App → App Store Connect**, suivre la validation et l’envoi.
7. Attendre le traitement dans App Store Connect / TestFlight. Revenir dans Distribution → version 1.0 → Build et choisir le build voulu.
8. Vérifier le numéro : la capture finale de cette session indique bien **1.0 (2)**.

L’icône de la fiche est extraite du build : elle peut être absente avant le traitement. Les captures du simulateur et les champs de la fiche ne sont pas récupérés automatiquement depuis Xcode.

### Particularités du projet

- `ITSAppUsesNonExemptEncryption = false` est présent pour cette version. Réévaluer cette déclaration si les fonctions de chiffrement changent ; ne pas charger arbitrairement un document de chiffrement.
- `NSSupportsLiveActivities = true` ; usage Calendrier décrit dans le plist ; orientations iPad portrait et paysage déclarées.
- Un manifeste de confidentialité app existe pour UserDefaults (`CA92.1`) ; les SDK embarquent leurs propres manifestes.
- Le build 2 corrige le texte de notification qui affichait `$lld min` : les valeurs numériques des notifications sont désormais transmises comme chaînes dans les nouveaux modèles localisés. Les anciennes notifications appartenant à l’app sont migrées lors de sa réouverture.

## 5. Créer la fiche App Store

App Store Connect → Apps → **+ → Nouvelle app**.

| Champ | Valeur à renseigner |
|---|---|
| Plateforme | iOS |
| Nom | `Studaya` |
| Langue principale | Anglais (États-Unis) |
| Identifiant de lot | `app.studaya.ios` |
| UGS | `studaya-ios` |
| Accès utilisateur | Selon les membres autorisés de ton compte |

Si seul l’identifiant Tidiva apparaît, créer/enregistrer l’identifiant Studaya dans l’équipe Apple Developer appropriée puis revenir au formulaire. Ne pas sélectionner `com.example.tidiva` pour Studaya.

## 6. Textes de la fiche produit

### Valeurs générales

| Champ | Texte / valeur |
|---|---|
| Nom | `Studaya` |
| Sous-titre anglais proposé | `Study planner & focus timer` |
| Sous-titre français proposé | `Révisions, planning et focus` |
| Catégorie principale proposée | Éducation |
| Catégorie secondaire proposée | Productivité |
| Version | `1.0` |
| Copyright | `2026 Adil Echcharafi` |
| URL assistance | `https://talinha.com/studaya/contact/` |
| URL marketing | `https://talinha.com/studaya/` |
| Fichier couverture géographique | Laisser vide : pas de fonction de couverture d’itinéraires |
| Extrait d’app / App Clip | Ne rien ajouter si aucun App Clip |
| App iMessage | Ne rien ajouter si aucune extension iMessage |
| Game Center | Décoché |

### Texte promotionnel anglais — saisi pendant la session

```text
Bring your subjects, tutorials and deadlines together. Build your revision plan, track your progress and make time for focused study.
```

### Description anglaise — modèle complet prêt à copier

Le champ entier saisi dans la console n’était pas visible dans les captures. Le texte ci-dessous est un modèle consolidé, pas une transcription garantie du champ envoyé.

```text
Make room for studying with a plan built around your subjects, tutorials and deadlines.

BUILD YOUR REVISION PATH
Add your subjects and optional subject codes. Organize courses and tutorials, record their start dates, and prepare for presentations, tests and final exams. Choose the study organization that fits your academic program.

TURN YOUR PLANS INTO STUDY SESSIONS
Create a revision plan around your availability. View your sessions and deadlines in the calendar, distinguish exams from tests and presentations, and adjust your schedule when your plans change.

SEE YOUR PROGRESS
Track your courses and tutorials, completed exercises and study progress. Keep completed work organized and return to topics that need more practice.

MAKE TIME TO FOCUS
Use a Focus timer for work and breaks. Follow your active timer on the Lock Screen and enable optional reminders for study sessions and upcoming deadlines.

KEEP YOUR TIMETABLE CLOSE
Import timetable information from a photo and review the recognized content before saving. Export your study sessions and deadlines to a dedicated Apple Calendar, with an option to remove events exported by Studaya.

START FOR FREE
Studaya offers a free version and optional monthly, annual and lifetime Premium access. Premium features and current prices are shown before purchase. Premium removes advertising.

Subscriptions renew automatically unless cancelled through your Apple account settings. Any free trial is subject to eligibility and the offer displayed at purchase. Lifetime access is a one-time, non-consumable purchase.

Your study data is stored on your device. The free version may display ads to adult users according to their privacy choices.

Privacy policy: https://talinha.com/studaya/privacy/
Terms of use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

### Mots-clés anglais — saisis pendant la session

```text
study,planner,revision,exam,student,homework,focus,pomodoro,timetable,university,tutorial
```

### Français

Texte promotionnel :

```text
Tes matières, tes TD et tes échéances au même endroit. Construis ton planning de révision et avance avec des séances Focus adaptées à ton rythme.
```

Description française complète et notes complémentaires : voir [release/1.0/app-store-fr.md](../release/1.0/app-store-fr.md).

Mots-clés :

```text
révision,étudiant,planning,études,examen,TD,cours,focus,pomodoro,agenda,université
```

Les champs ont leurs limites propres : nom et sous-titre 30 caractères, promotion 170, description 4 000, mots-clés 100 selon le compteur App Store Connect. Le compteur de la console fait foi.

## 7. Captures, icône et vidéo de démonstration

### Captures publiques de la fiche

Distribution → App iOS Version 1.0 → **Aperçus d’app et captures d’écran**.

- Choisir la famille iPhone, charger les captures réelles de l’app, puis faire pareil dans **iPad écran de 13 pouces**.
- Utiliser les dimensions que la console accepte pour chaque emplacement. Ne pas étirer une capture iPhone pour fabriquer une capture iPad.
- Captures iPhone utilisées : Accueil, Planning, Matières, Focus. Les fichiers du site étaient en `1206 × 2622` et ont été acceptés.
- Les captures iPad Air 13 pouces fournies par le simulateur sont en `2048 × 2732`. La capture d’erreur suivante n’exigeait plus d’image iPad après leur ajout.
- L’en-tête marketing et l’aperçu vidéo public sont des ressources différentes des captures. Ne pas y placer une vidéo destinée uniquement à Apple.
- Captures françaises sur fiche anglaise : mieux vaut produire un jeu anglais correspondant à la langue de la fiche lors d’une amélioration ; ne pas décrire ces captures comme traduites.

Sources locales iPhone dans Talinha :

```text
/Users/adil.echcharafi/Server/Tools/talinha/public/assets/studaya/today.png
/Users/adil.echcharafi/Server/Tools/talinha/public/assets/studaya/planner.png
/Users/adil.echcharafi/Server/Tools/talinha/public/assets/studaya/subjects.png
/Users/adil.echcharafi/Server/Tools/talinha/public/assets/studaya/focus.png
```

Captures réelles iPad conseillées parmi celles produites :

| Écran | Fichier sur le Bureau du Mac |
|---|---|
| Accueil avec révisions | `Simulator Screenshot - iPad Air 13-inch (M4) - 2026-11-13 at 14.26.43.png` |
| Calendrier rempli | `Simulator Screenshot - iPad Air 13-inch (M4) - 2026-11-13 at 14.26.38.png` |
| Matières | `Simulator Screenshot - iPad Air 13-inch (M4) - 2026-11-13 at 14.26.47.png` |
| Focus | `Simulator Screenshot - iPad Air 13-inch (M4) - 2026-11-13 at 14.26.48.png` |
| Progrès | `Simulator Screenshot - iPad Air 13-inch (M4) - 2026-11-13 at 14.26.52.png` |

### Faire une capture dans Simulator

Ouvrir le bon écran dans l’app puis **File → Save Screen** ou `⌘S`. Les fichiers de cette session ont été enregistrés dans `/Users/adil.echcharafi/Desktop/`. Le dossier peut varier selon les réglages du simulateur.

Pour le paywall, prendre une capture **avant l’achat**, avec Monthly, Yearly ou Lifetime sélectionné. Si le simulateur est déjà abonné avec le fichier StoreKit local : Xcode → Debug → StoreKit → Manage Transactions, supprimer les transactions de test ou réinitialiser l’environnement de test, puis relancer. Une simple annulation laisse souvent le droit actif jusqu’à l’expiration.

Captures iPhone déjà faites pour les abonnements :

- Mensuel : `Simulator Screenshot - iPhone 17 Pro - 2026-11-13 at 14.01.57.png`.
- Annuel : `Simulator Screenshot - iPhone 17 Pro - 2026-11-13 at 14.02.07.png`.
- `14.03.38` montre Premium déjà actif et `14.03.44` montre la gestion Apple : préférer le paywall avant achat pour la preuve du produit.

### Vidéo destinée à Apple

**Distribution → version 1.0 → Informations utiles à la vérification de l’app → Pièce jointe → Choisir un fichier.** Enregistrer la fiche et vérifier que le fichier apparaît. Si le format ou la taille est refusé, fournir un lien accessible sans connexion dans les remarques et vérifier son accès.

Texte à ajouter aux remarques après avoir réellement joint le fichier :

```text
A demonstration video is attached for the App Review team.
```

Parcours utile à montrer : lancement → configuration → continuer gratuitement → créer matière/cours/TD → planning et échéances → Focus → Premium et restauration. Éviter les données personnelles ou de vrais paiements dans la vidéo.

## 8. Informations générales et classification

### Droits relatifs au contenu

Informations sur l’app → Droits relatifs au contenu → Modifier.

Pendant cette session, la réponse recommandée pour les contenus publicitaires tiers autorisés était **Oui, contient/affiche des contenus tiers et possède les droits nécessaires**. Ne sélectionner cette réponse que si les accords et autorisations couvrent effectivement leur diffusion. Les droits des supports d’étude importés par l’utilisateur ne deviennent pas automatiquement les droits de l’éditeur.

### Questionnaire d’âge

Répondre selon les fonctions réellement présentes. La publicité doit être déclarée même si elle n’est affichée qu’aux adultes.

| Fonction | Réponse pour le parcours décrit |
|---|---|
| Contrôle parental | Non |
| Validation de l’âge | Oui si le mécanisme de déclaration d’âge de la version satisfait bien la définition affichée ; ce n’est pas une vérification d’identité |
| Accès au Web sans restrictions | Non : pas de navigateur libre intégré |
| Contenu généré par les utilisateurs | Non pour les notes privées locales, sans distribution sociale |
| Réseaux sociaux | Non |
| Réseaux sociaux désactivés pour moins de 13 ans | Non / non applicable puisque pas de réseaux sociaux |
| Messagerie et chat entre utilisateurs | Non |
| Publicité | **Oui** |
| Violence, sexualité, jeux d’argent, substances, horreur, etc. | Aucun / jamais si aucun contenu de cette nature dans l’app ; revoir aussi l’adéquation des annonces |
| Informations médicales ou de traitement | Aucune si l’app ne fournit pas ces informations |
| Conçue pour les enfants | Non |
| URL d’adéquation à l’âge | Facultative ; laisser vide si aucune page dédiée |

Le calcul affichait **4+**. Un remplacement vers **13+** avait été proposé pour correspondre au minimum déclaré dans l’app. La capture finale de cette sélection n’a pas été fournie : vérifier la valeur enregistrée. Ne pas déclarer « Conçue pour les enfants » pour une app simplement destinée aux étudiants.

### Autres champs

- Contrat de licence : **contrat standard Apple**, avec lien EULA dans l’app et la description.
- Accessibilité : déclarer seulement les fonctions réellement vérifiées, pas toutes les options par défaut.
- Statut professionnel / DSA : utiliser le statut réel de l’éditeur. Exclure des territoires ne remplace pas les obligations fiscales ou les accords applicables.
- Notifications serveur App Store et secret partagé : aucun endpoint n’a été configuré ici. Ne pas inventer d’URL ni publier de secret ; l’implémentation utilise StoreKit 2 côté app.

## 9. Confidentialité et suivi publicitaire

### Première étape

Confidentialité de l’app → Politique de confidentialité → Modifier :

| Champ | Valeur |
|---|---|
| URL de la politique | `https://talinha.com/studaya/privacy/` |
| URL des choix de confidentialité | Facultative : vide si aucune page dédiée ; l’app propose ses choix publicitaires dans ses réglages |
| Vous ou vos partenaires collectez des données ? | **Oui**, compte tenu des SDK publicitaires |

Une donnée conservée uniquement sur l’appareil n’est pas automatiquement une donnée « collectée » au sens du formulaire. À l’inverse, les SDK tiers sont à inclure même si Studaya n’a pas de compte serveur.

### Les trois formulaires de chaque type

1. **Finalités** : cocher les usages applicables.
2. **Lié à l’identité** : répondre selon les possibilités d’association, y compris via l’appareil. L’absence de compte ne suffit pas à répondre Non.
3. **Utilisé pour le suivi** : répondre selon le suivi entre apps/sites d’autres entreprises, pas seulement selon l’accès à l’IDFA.

### Réponses documentées pendant la session — base à auditer, pas certification

Ces valeurs combinent les manifestes embarqués Google Mobile Ads 13.12.0 et UMP 3.1.0. La configuration effective doit être contrôlée avant réutilisation. **La colonne suivi de l’identifiant reste le point ouvert de la version soumise.**

| Type | Formulaire 1 : finalités | Formulaire 2 : lié | Formulaire 3 : suivi |
|---|---|---|---|
| Emplacement approximatif | Publicités tierces ; Publicités ou marketing du développeur ; Analyses ; Fonctionnalité de l’app | Oui | Non dans la déclaration de cette session |
| Identifiant de l’appareil | Publicités tierces ; Publicités ou marketing du développeur ; Analyses | Oui | **Oui saisi — à aligner avec le comportement réel / ATT** |
| Interaction avec le produit | Publicités tierces ; Publicités ou marketing du développeur ; Analyses ; Fonctionnalité de l’app | Oui | Non dans la déclaration de cette session |
| Données publicitaires | Publicités tierces ; Publicités ou marketing du développeur ; Analyses | Oui | Non dans la déclaration de cette session |
| Données sur les pannes | Analyses | Non | Non |
| Données de performance | Publicités tierces ; Publicités ou marketing du développeur ; Analyses ; Fonctionnalité de l’app | Non | Non |
| Autres données de diagnostic | Publicités tierces ; Publicités ou marketing du développeur ; Analyses | Non | Non |

« Fonctionnalité de l’app » pour les performances venait du manifeste UMP ; la capture récapitulative ne l’affichait pas encore et sa correction avait été demandée. Confirmer le formulaire enregistré.

Les finalités « marketing du développeur » ci-dessus viennent des déclarations du SDK, elles ne signifient pas qu’une campagne marketing propre à Studaya a été lancée. Si l’usage réel exclut une finalité déclarée comme capacité par le SDK, déterminer la réponse exacte avec sa documentation et sa configuration ; ne pas cocher des usages inexistants uniquement pour remplir le formulaire.

Ne pas ajouter par défaut : contacts, santé, nom/email, photos, documents d’étude ou achats. Vérifier leurs flux réels, notamment toute évolution de l’import photo vers un service distant ou l’ajout d’un fournisseur d’achats/analytics. La politique doit décrire les destinataires et traitements effectifs.

### Enregistrement puis publication

Enregistrer chaque type ne publie pas encore l’ensemble. Revenir à Confidentialité de l’app et cliquer **Publier** après revue de cohérence. C’est ce bouton manquant qui causait le message « un administrateur doit fournir des informations sur les pratiques en matière de vie privée ».

L’aperçu publié pendant la session montrait : identifiants utilisés pour le suivi ; identifiants, emplacement et utilisation liés ; diagnostics non liés. Cet aperçu ne constitue pas une validation technique d’Apple.

## 10. Tarifs et territoires

Tarifs et disponibilité :

| Champ | Valeur choisie / à utiliser |
|---|---|
| Prix de téléchargement de l’app | Gratuit, `0` ; les achats Premium sont configurés séparément |
| Pays de base | États-Unis (USD) |
| Catégorie d’imposition | Logiciel pour l’App Store, à confirmer selon la nature réelle du produit |
| Disponibilité | 131 pays disponibles, 44 exclus dans la capture finale |
| Distribution | Public : détectable par tous dans les territoires choisis |
| Apple silicon Mac | Décoché pour ce lancement |
| Apple Vision Pro | Décoché pour ce lancement |
| Apple School Manager, réduction volume | Case visible cochée dans la capture ; pas de choix supplémentaire nécessaire pour les fonctions de base |

L’utilisateur a indiqué avoir retiré l’Europe, le Brésil et le Mexique. La liste détaillée des 44 territoires n’a pas été auditée : consulter **Disponibilité → Gérer** pour connaître les pays exacts. Le tableau de prix peut encore afficher 175 pays alors que seuls 131 sont disponibles : tarification et disponibilité sont deux réglages différents.

Appliquer les territoires voulus à chacun des produits. Les formulaires fiscaux dépendent du compte, des contrats et des lois applicables ; l’exclusion d’un pays ne dispense pas automatiquement de tout formulaire.

## 11. Premium : groupe, abonnements et achat à vie

### Groupe d’abonnements

Distribution → Abonnements → créer un groupe.

| Champ | Valeur |
|---|---|
| Nom de référence | `Studaya Premium` |
| ID du groupe App Store Connect | `22575933` |
| Localisation du groupe | Anglais (États-Unis) |
| Nom d’affichage localisé | `Studaya Premium` |
| Nom de l’app dans la localisation | Conserver `Studaya` |
| Niveau de Monthly et Yearly | Même niveau `1`, car mêmes droits Premium |

**Piège rencontré :** les traductions des produits ne créent pas celle du groupe. Sur la page du groupe → Nom d’affichage et description → **Créer**, ajouter l’anglais. Sans cela : « Vous devez ajouter au moins une langue pour votre groupe d’abonnements ».

### Champs des trois produits

| Champ | Monthly | Yearly | Lifetime |
|---|---|---|---|
| Type | Abonnement auto-renouvelable | Abonnement auto-renouvelable | Achat non consommable |
| Nom de référence | `Studaya Premium Monthly` | `Studaya Premium Yearly` | `Studaya Premium Lifetime` |
| Product ID exact | `studaya.premium.monthly` | `studaya.premium.yearly` | `studaya.premium.lifetime` |
| Apple ID | `6834403116` | `6834403312` | `6834409723` |
| Durée | 1 mois | 1 an, payé à l’avance | Sans renouvellement |
| Groupe | Studaya Premium | Studaya Premium | Aucun groupe d’abonnements |
| Prix US console | **4,99 USD confirmé** | **49,99 USD confirmé** | **79,99 USD proposé, prix final à confirmer** |
| Territoires | 131 selon la sélection de l’app | Idem | Idem |
| Langue | Anglais (États-Unis) | Anglais (États-Unis) | Anglais (États-Unis) |
| Nom d’affichage | `Studaya Premium Monthly` | `Studaya Premium Annual` | `Studaya Premium Lifetime` |
| Description | `Unlock all Premium features and remove ads.` | `Unlock all Premium features and remove ads.` | `Unlock all Premium features forever. One-time purchase.` |
| Partage familial | Non activé pendant cette session | Non activé | Non activé |
| Image promotionnelle 1024 × 1024 | Facultative, laissée vide | Idem | Idem |
| Catégorie fiscale produit | Faire correspondre à l’app parente si approprié | Idem | Idem |

**Ne pas recréer les produits avec d’autres IDs : le code cherche ces chaînes exactes.** L’offre à vie ne doit pas être créée comme abonnement ni comme consommable.

### Essai gratuit

Le choix initial de ne pas mettre d’essai a été remplacé pendant la session : **7 jours gratuits ont finalement été configurés pour les abonnements** afin de correspondre au paywall.

Chemin observé : produit → Prix de l’abonnement → **Afficher tous les prix de l’abonnement** → **Offres d’introduction → +**.

| Champ | Valeur |
|---|---|
| Produits | Monthly et Yearly, chacun séparément |
| Type | Essai gratuit |
| Durée | 1 semaine / 7 jours |
| Territoires | Les 131 choisis |
| Début | 13 novembre 2026 pour ce lancement |
| Fin | Durée illimitée / aucune date de fin |
| Autres offres | Fidélisation, reconquête, codes et promotions laissés sans configuration spécifique |

La capture annuelle confirme « Gratuit la première semaine » ; l’ajout au mensuel a ensuite été déclaré fait. L’éligibilité de l’utilisateur reste gérée par StoreKit ; ne pas promettre un nouvel essai après chaque changement de formule. Lifetime n’a pas d’essai d’abonnement.

### Capture et notes de revue par produit

En bas de chaque fiche → **Informations destinées à l’équipe de vérification** : charger la capture du paywall de la formule concernée. Cela diffère de l’image promotionnelle facultative.

Monthly — remarques :

```text
Auto-renewable monthly subscription that unlocks all Studaya Premium features and removes advertising.

Available from Settings > Subscription > Monthly. Restore Purchases is available on the purchase screen. No account or sign-in is required.

A 7-day free trial is available to eligible new subscribers, followed by the price displayed by the App Store.
```

Yearly — remarques :

```text
Auto-renewable annual subscription that unlocks all Studaya Premium features and removes advertising.

Available from Settings > Subscription > Annual. Restore Purchases is available on the purchase screen. No account or sign-in is required.

A 7-day free trial is available to eligible new subscribers, followed by the price displayed by the App Store.
```

Lifetime — remarques utilisées :

```text
One-time, non-consumable purchase that unlocks all Studaya Premium features and removes advertising permanently. No recurring subscription.

Available from Settings > Subscription > Lifetime. Restore Purchases is available on the same screen. No account or sign-in is required.
```

### Prix du simulateur et prix réels

`Studaya.storekit` est un catalogue de test local : mensuel **5**, annuel **50**, à vie **80** USD. Il ne configure pas la console et explique les montants arrondis sur les captures. Les prix réels observés dans App Store Connect sont 4,99 et 49,99 USD. Utiliser `Product.displayPrice` en production et vérifier avec TestFlight, sans le catalogue StoreKit local.

La capture paywall montre comme avantages : import planning depuis photo, bilan Focus sur 30 jours, temps étudié par matière et export CSV ; suppression des publicités. Confirmer que toutes ces restrictions et tous ces droits correspondent à la version effectivement envoyée.

## 12. Informations pour App Review

Distribution → App iOS Version 1.0 → **Informations utiles à la vérification de l’app**.

| Champ | Valeur |
|---|---|
| Connexion requise | **Décoché**, Studaya n’exige pas de compte |
| Nom d’utilisateur / mot de passe | Vides |
| Prénom | `Adil`, si toujours le contact responsable |
| Nom | `Echcharafi`, si toujours le contact responsable |
| Téléphone | Ton numéro joignable avec indicatif, comme saisi dans la console |
| Email | Ton email de contact App Review consulté régulièrement |
| Pièce jointe | Vidéo de démonstration, si fournie ; vérifier le chargement |

Ne pas inventer d’identifiants de démonstration pour une app sans connexion.

### Remarques complètes prêtes à copier

```text
Studaya is a study planner for iPhone and iPad. No account or sign-in is required.

To access the free version, complete the academic setup and select “Continue for free”. Create a Revision Path to add subjects, courses, tutorials and optional assessment dates.

Notifications, camera access and Apple Calendar synchronization are optional. Timetable photo import allows users to review recognized content before saving. Calendar export uses a dedicated calendar, and exported events can be removed from Studaya.

Focus provides work and break timers and a Lock Screen Live Activity.

Premium is available from Settings > Subscription. The following products are included in this submission:
- studaya.premium.monthly: auto-renewable monthly subscription.
- studaya.premium.yearly: auto-renewable annual subscription.
- studaya.premium.lifetime: one-time, non-consumable purchase.

Restore Purchases is available on the purchase screen. Subscriptions offer a 7-day free trial to eligible users. Current prices and terms are displayed before purchase. Premium removes advertising.

Ads are requested only for users with a known age of 18 or above and confirmed free access, after the consent system permits ad requests. Premium users and minors receive no ads. Interstitial ads are limited to natural action completions, at most once per elapsed hour, and do not interrupt an active work timer.

Study data is stored locally on the device. The interface follows the supported language preferences in iOS.
```

Ajouter la phrase sur la vidéo uniquement après l’avoir jointe. Ne pas affirmer qu’ATT est implémenté tant que ce n’est pas le cas. Si Apple demande une précision, répondre dans le fil de la demande avec des étapes et preuves correspondant au build soumis.

## 13. AdMob : configuration et placements

### Identifiants de production confirmés dans Xcode

| Champ | Valeur |
|---|---|
| Publisher ID | `pub-6373601597994228` |
| App ID AdMob | `ca-app-pub-6373601597994228~9948626219` |
| Bannière | `ca-app-pub-6373601597994228/5434666132` |
| Interstitiel | `ca-app-pub-6373601597994228/3023611865` |
| Version Google Mobile Ads auditée | `13.12.0` |
| Version UMP auditée | `3.1.0` |

L’App ID comporte `~`, les unités comportent `/` : ne pas les intervertir.

### Valeurs Debug officielles de test

| Type | ID |
|---|---|
| Application | `ca-app-pub-3940256099942544~1458002511` |
| Bannière | `ca-app-pub-3940256099942544/2934735716` |
| Interstitiel | `ca-app-pub-3940256099942544/4411468910` |

### Préparer la console AdMob

1. Créer/sélectionner **Studaya**, plateforme **iOS** ; conserver l’app et les unités correspondant aux IDs déjà utilisés.
2. Une fois la fiche publique disponible, associer la bonne app App Store : Apple ID `6834361770`, URL `https://apps.apple.com/app/id6834361770`.
3. Contrôler validation du compte, informations de paiement demandées, centre de règles et restrictions de diffusion. La compilation du SDK ne valide pas le compte.
4. Vérifier les formats : bannière et interstitiel ; aucun rewarded ou app-open n’a été demandé pour ce lancement.
5. **Confidentialité et messages** : configurer et publier les messages applicables à l’audience et aux régions réellement desservies, dont le message de consentement européen si applicable. Nom de l’app `Studaya`, politique `https://talinha.com/studaya/privacy/`.
6. Vérifier les paramètres de contenu et les catégories d’annonces pour une app d’organisation étudiante. Ne pas déclarer une audience enfants par défaut ; l’intégration actuelle réserve les demandes publicitaires aux 18 ans et plus.
7. Valider app-ads.txt, l’app et son état de préparation à la diffusion dans AdMob. L’approbation Apple n’entraîne pas automatiquement l’approbation AdMob.

Les libellés exacts et les formulaires de console peuvent évoluer. Aucun paramètre non vu dans le compte n’est réputé configuré par ce document.

### app-ads.txt

Fichier local : `/Users/adil.echcharafi/Server/Tools/talinha/public/app-ads.txt`.

Contenu confirmé :

```text
google.com, pub-6373601597994228, DIRECT, f08c47fec0942fa0
```

URL à servir : **`https://talinha.com/app-ads.txt`**, à la racine du domaine, pas seulement sous `/studaya/`. Le domaine du site développeur fourni à la fiche doit permettre à Google de retrouver ce fichier. Publier Talinha puis demander/recontrôler la vérification dans AdMob. Ne pas dupliquer une ligne identique pour chaque app du même compte.

### Emplacements demandés et comportement implémenté

| Demande | Comportement local audité |
|---|---|
| Bloc au début des pages | Bannières en haut des cinq onglets, pages matière/cours et réglages principaux |
| Pub dans les révisions | Bannière intégrée comme élément de la liste du jour et du planning s’il y a une séance |
| Plein écran après révision, toutes les heures | Occasion après réussite, plafond global d’une heure depuis la dernière impression réelle |
| Création de planning | Occasion après création réussie d’un parcours et sortie de ce parcours |
| Nouvelle matière / cours / TD | Occasion après enregistrement réussi |
| Autres occasions | Fin de cours/TD et validation du bilan Focus |
| Protection du Focus | Aucun interstitiel pendant le minuteur de travail actif |
| Premium / mineurs | Aucune demande de pub |
| Âge ou statut Premium indéterminé | Aucune demande de pub |
| Onboarding / paiement | Pas de bannière ajoutée |

Une « occasion » ne garantit pas une annonce : il faut consentement, connexion, annonce disponible, présentation possible et plafond respecté. Une pub non chargée ne doit pas surgir tardivement pour une ancienne action. Le délai d’une heure n’est pas une notification périodique ni une obligation d’afficher une pub exactement toutes les heures.

### Consentement et vérification

- UMP actualise le consentement avant les requêtes et expose les choix de confidentialité si requis.
- Les choix peuvent être rouverts depuis les réglages Données et confidentialité / choix publicitaires.
- UMP et ATT répondent à des questions différentes ; un consentement UMP ne remplace pas automatiquement l’autorisation ATT.
- Tester avec les unités Debug ou un appareil déclaré de test ; ne pas cliquer ses annonces de production.
- Contrôler : gratuit majeur → pub possible ; mineur → aucune ; Premium → aucune ; refus applicable → traitement conforme ; interstitiel → fermeture puis reprise normale ; actions rapprochées → plafond respecté.
- Les tests ciblés d’éligibilité et de fréquence ont passé. La diffusion réelle et les réglages du compte n’ont pas été validés depuis le dépôt.

## 14. Soumission et publication

### Ajouter les éléments à la revue

1. Sur version 1.0 : enregistrer les métadonnées, choisir le build traité, vérifier les captures iPhone/iPad.
2. Compléter droits relatifs au contenu, questionnaire d’âge et politique/confidentialité ; **publier** la déclaration de confidentialité.
3. Compléter chaque produit et la localisation du groupe.
4. Cliquer **Ajouter pour vérification** pour la version et les produits/groupe, afin de les réunir dans la même soumission iOS.
5. Ouvrir le brouillon et contrôler les **cinq éléments** : app, Monthly, Yearly, Lifetime, groupe.
6. Vérifier les points ouverts de la section 1, puis **Envoyer pour vérification**. Ce dernier bouton est l’envoi réel ; « Ajouter » prépare la soumission.

Les premiers achats doivent accompagner une version de l’app. Le message « ajoutez une version de l’app pour la plateforme sélectionnée » venait d’un brouillon contenant Lifetime seul.

### Mode de publication

Le choix de cette session était **Publier cette version automatiquement** après approbation. La publication manuelle permettrait de contrôler le moment du lancement, mais n’était pas le choix montré.

### Après l’envoi

- État actuel : **En attente de vérification**, confirmé pour les cinq éléments.
- Suivi dans **Vérification de l’app** et par email ; ne pas annoncer « disponible » avant d’avoir vérifié la fiche publique.
- Si Apple demande une vidéo ou des précisions, répondre à la demande avec la pièce jointe ou un lien accessible et les étapes exactes.
- Si correction binaire : incrémenter build, archiver, envoyer, sélectionner le nouveau build et renouveler la soumission selon les actions proposées par la console.
- Après approbation : vérifier téléchargement réel, prix/offres, restauration, URL d’assistance et politique, puis association AdMob et préparation des annonces.
- Ne promettre aucun délai précis d’approbation ; une soumission techniquement acceptée peut encore être refusée lors de la revue.

## 15. Problèmes rencontrés et solutions

| Symptôme | Action utile |
|---|---|
| Icône vide dans App Store Connect | Attendre le traitement du build puis sélectionner l’archive qui contient l’icône ; ne pas chercher un champ manuel d’icône sur cette page |
| iPhone absent des destinations Xcode sans câble | Une connexion réseau nécessite que l’appareil soit déjà jumelé au Mac et disponible selon les réglages Xcode/iOS ; un premier jumelage peut nécessiter un câble. Ne pas supposer que l’autre Mac transmet son jumelage |
| Build envoyé mais absent de Distribution | Contrôler traitement dans TestFlight, bon compte, Bundle ID, version et numéro de build |
| Notification `$lld min` | Correction incluse au build 2 ; ouvrir la nouvelle app pour régénérer les rappels migrés |
| Capture iPad exigée | Le binaire prend en charge iPad ; fournir une capture iPad réelle dans l’emplacement 13 pouces |
| Droits de contenu manquants | Informations sur l’app → Droits relatifs au contenu → répondre puis enregistrer |
| Informations de vie privée manquantes | Terminer les sept types puis **Publier**, pas seulement enregistrer les sous-formulaires |
| Groupe sans langue | Créer la localisation du groupe, indépendamment de celles des abonnements |
| Lifetime seul dans la soumission | Ajouter la version iOS et les abonnements au même ensemble |
| Paywall déjà abonné sur simulateur | Réinitialiser les transactions de test StoreKit ; annuler seul ne retire pas immédiatement le droit |
| Prix 5/50/80 sur simulateur | Catalogue local StoreKit ; vérifier les vrais prix via console/TestFlight |
| Tests StoreKit CLI indisponibles | Le parcours Xcode GUI a fonctionné ; ne pas bloquer la capture sur les essais CLI en échec de cette session |
| `index.lock` existe | Vérifier qu’aucun Git/éditeur de commit n’est actif. Supprimer uniquement un verrou confirmé obsolète ; ne pas effacer le verrou d’un processus en cours |

## 16. Checklist réutilisable et références

### Pour une prochaine version

- [ ] Définir les changements et incrémenter le build.
- [ ] Vérifier les traductions des nouveaux textes et notifications.
- [ ] Vérifier iPhone et iPad sur les parcours modifiés.
- [ ] Vérifier droits Premium, prix StoreKit, restauration et accès gratuit.
- [ ] Vérifier consentement, ATT/suivi et manifestes après toute mise à jour SDK.
- [ ] Publier la politique si les pratiques changent.
- [ ] Archiver Release, envoyer, attendre traitement, sélectionner le bon build.
- [ ] Mettre à jour captures et description si le comportement change.
- [ ] Compléter « Nouveautés » pour la nouvelle version avec les vrais changements.
- [ ] Joindre vidéo et nouvelles informations de revue si nécessaires.
- [ ] Vérifier territoires, contrats et éventuels nouveaux produits.
- [ ] Contrôler l’ensemble puis envoyer pour vérification.
- [ ] Après publication, tester la version App Store et contrôler les consoles Apple/AdMob.

### Fichiers locaux associés

- [Audit AdMob](ADMOB-LAUNCH.md).
- [Fiche française et notes App Review](../release/1.0/app-store-fr.md).
- `Studaya/Advertising.swift` : consentement, éligibilité et placements.
- `Studaya-Info.plist` : configuration app et clés publicitaires.
- `Studaya.xcodeproj/project.pbxproj` : version/build, Bundle IDs et IDs AdMob par configuration.
- `Studaya.storekit` : produits de test locaux, distincts des prix de production.
- `Studaya/PrivacyInfo.xcprivacy` : accès aux API soumises à justification.
- `/Users/adil.echcharafi/Server/Tools/talinha/app/studaya/privacy/page.tsx` : politique locale à déployer.
- `/Users/adil.echcharafi/Server/Tools/talinha/public/app-ads.txt` : autorisation du vendeur publicitaire.

### Références officielles pour revoir les règles

Ces liens servent à revalider les exigences lors du prochain lancement ; le présent document retrace la session et ne prétend pas figer les règles futures.

- [App Store Connect Help](https://developer.apple.com/help/app-store-connect/).
- [Déclarations App Privacy](https://developer.apple.com/app-store/app-privacy-details/).
- [Valeurs et définitions des classifications d’âge](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/).
- [Consentement AdMob iOS / UMP](https://developers.google.com/admob/ios/privacy).
- [Stratégies de confidentialité, ATT et identifiants](https://developers.google.com/admob/ios/privacy/strategies).
- [Données traitées par Google Mobile Ads iOS](https://developers.google.com/admob/ios/privacy/data-disclosure).
- [Interstitiels iOS](https://developers.google.com/admob/ios/interstitial).
- [Vérification et préparation à la diffusion AdMob](https://support.google.com/admob/answer/14538460).

**Aucun mot de passe, secret partagé, clé privée, donnée bancaire ou document d’identité ne doit être ajouté à ce fichier.**
