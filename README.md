# Studaya

Application SwiftUI et SwiftData pour iPhone et iPad, à partir d’iOS 17. Studaya associe *study* et *day*. Le livre ouvert et la courbe de progression utilisent le bleu nuit #101D35 et le vert menthe #20C878.

## Lancement

Ouvrir Studaya.xcodeproj dans Xcode 26, sélectionner le schéma Studaya et un simulateur iOS. ⌘R lance l’application, ⌘U lance les tests unitaires et d’interface. Pour un appareil physique, sélectionner son équipe dans Signing & Capabilities.

## Premier planning

1. Suivre les six étapes de configuration. Renseigner la formation, le niveau, la période et les disponibilités. Une étape dédiée propose d’activer les notifications. Le prénom et l’établissement sont facultatifs.
2. Vérifier le récapitulatif, puis choisir une formule Premium ou continuer gratuitement. La configuration initiale conserve uniquement le profil et le rythme ; les matières sont créées séparément.
3. Consulter Today et parcourir les semestres dans Planner. Ajouter ses dates d’examen et chapitres dans Révision. Leur préparation prend la priorité sur les séances régulières.
4. Utiliser Réglages pour revoir le parcours, modifier le rythme, programmer le rappel quotidien ou gérer l’abonnement. La reconfiguration conserve les séances terminées.
5. Le premier lancement après mise à jour propose le nouveau parcours aux profils de la première version. Les matières et l’historique existants sont conservés.

## Planification

Scheduling.swift reçoit le contexte SwiftData, les disponibilités, l’heure de référence et le calendrier. Le premier passage réserve les créneaux entiers avant le jour de l’échéance (examen, contrôle, présentation ou rendu). Il traite les échéances les plus proches en premier et équilibre les chapitres de même priorité. À échéance égale, les cours et TD fragiles passent en priorité. Un chapitre fragile bénéficie d’un rappel supplémentaire. Le second passage espace les répétitions dans les créneaux libres en remontant depuis la date d’examen.

Les modifications des chapitres, examens ou disponibilités déclenchent un recalcul. Les séances terminées gardent leur identité et réservent leur créneau. Les séances manquées sont recalculées au retour dans l’application. Le bouton de replanification indique combien de séances restent sans créneau.

## Persistance et extensions

Models.swift définit les entités et les identifiants stables. Storage.container centralise la configuration du stockage. Les préférences et l’échéance absolue du Pomodoro utilisent UserDefaults pour reprendre après suspension.

Pour activer la synchronisation, provisionner un conteneur iCloud, activer les capacités CloudKit et notifications à distance, passer une base privée à Storage.container et tester migration et conflits sur deux appareils. Les préférences restent propres à l’appareil.

## Abonnements StoreKit 2

Le schéma Studaya conserve la boutique de test locale pour lancer l’app depuis Xcode sur iPhone et retrouver ses achats de test. Le schéma Studaya Sandbox utilise les produits configurés dans App Store Connect. Les achats Xcode sont propres à leur environnement. Trois produits locaux reprennent la structure de Tidiva, mensuel, annuel et achat à vie. Les formules récurrentes ont une offre introductive de sept jours pour les comptes éligibles. Premium déverrouille le bilan Focus sur trente jours, le détail par matière et l’export CSV. Les prix proviennent de StoreKit.

PremiumOptions charge les produits, vérifie les transactions, traite les mises à jour, restaure les achats et ouvre la gestion Apple des abonnements. MembershipTests vérifie le catalogue et l’activation par achat annuel dans la boutique de test. Pour distribuer ces offres, configurer dans App Store Connect les identifiants studaya.premium.monthly, studaya.premium.yearly et studaya.premium.lifetime, le groupe, les tarifs et les essais de production.

## Organisation étudiante

Le créateur « Parcours de révision », accessible depuis Today et Révision, accepte plusieurs matières et les répartit par année et semestre ou par matière. Chaque matière possède son mode et sa date prévue d’examen. Les révisions régulières respectent l’année et le semestre affectés ; les préparations ne commencent pas avant cette période.

Chaque matière contient des cours et TD. Les cours suivent les séances réalisées ; les TD suivent le nombre d’exercices terminés. Une fois tous les exercices faits, le coach recommande un exercice de synthèse de bout en bout sans correction. Sa validation permet de classer le TD dans une section séparée, sans supprimer les notes, flashcards et séances. Les unités terminées sortent de la planification.

Les échéances supplémentaires (contrôle, examen, présentation, rendu) ont une date avec heure, un objectif de préparation et un rappel configurable de 0 à 30 jours avant. Leurs rappels sont affichés dans l’application ; les notifications iOS d’échéance sont activables dans Réglages → Rappels et notifications. Elles sont programmées localement et peuvent être reçues lorsque l’app est fermée, selon les autorisations et réglages de concentration iOS. L’accueil affiche les échéances, les retards, le compte à rebours du prochain examen et la progression du travail suivi. Ce pourcentage mesure l’avancement déclaré, pas une garantie de maîtrise ou de note.

Le calendrier mensuel et hebdomadaire affiche des points sur les jours contenant un rappel ou une échéance, y compris les rappels d’examen J−7/J−1 et les rappels espacés. Le planning prépare les échéances proches avant les suivantes, signale les séances sans place et conserve l’historique des séances effectuées.

## Emploi du temps et reports

Dans Planner ou Réglages → Emploi du temps et indisponibilités, ajouter une période ponctuelle (vacances comprises) ou une occupation hebdomadaire avec date de fin. Les séances automatiques, leur espacement et les révisions régulières évitent ces périodes. Les séances déjà réalisées sont conservées. Une occupation qui chevauche une séance reportée demande de déplacer cette séance au préalable.

Un appui long sur une séance à faire propose de la travailler avec Focus ou de la reporter. Le report vérifie les autres séances, les indisponibilités et l’échéance liée. La séance garde son identité et son créneau lors des recalculs, et compte dans le travail restant.

## Focus et entretien des acquis

Démarrer Focus depuis un cours/TD ou depuis une séance conserve le lien avec ce travail. La fin d’un cycle enregistre une seule fois le temps étudié, valide la séance liée ou crée une séance réalisée pour le cours. Le bilan demande explicitement le nombre d’exercices réellement terminés dans un TD. Fermer le bilan conserve le temps de travail, sans inventer d’exercices terminés. Les réglages du minuteur et sa cible survivent à la suspension de l’app.

Valider un cours ou un TD crée trois rappels à J+2, J+7 et J+21 à 18 h, dans une section indépendante. Ils apparaissent sur l’accueil à l’approche de leur date, dans le calendrier et dans les archives. Ils peuvent être validés directement ou travaillés avec Focus. Le cours/TD reste terminé. Le remettre en cours annule ses rappels futurs non effectués ; les rappels déjà faits restent dans l’historique.

## Notifications

Réglages → Rappels et notifications propose des catégories indépendantes : planning du matin (8 h par défaut), bilan du soir (20 h), début des séances, échéances et rappels espacés, accompagnement et Focus. Les examens gardent leurs rappels à J−7, J−1 et le jour même à 9 h. Les contrôles et présentations suivent leur date choisie ; les éléments sans date ne déclenchent pas de faux rappels. Les invitations du matin et du soir sont quotidiennes et récurrentes. Elles invitent à consulter l’état réel du planning dans l’app ; les alertes de séance sont recalculées lorsque le travail est validé ou reporté. Toucher une notification ouvre l’onglet approprié.

L’accompagnement invite à créer une première matière ou un premier cours, à renseigner un examen lorsqu’il est annoncé, à reprendre après 3 ou 7 jours sans révision, à refaire une synthèse après les exercices d’un TD et à consulter le bilan hebdomadaire. Les rappels espacés à J+2, J+7 et J+21 entretiennent les acquis des TD terminés. Les messages d’accompagnement respectent une plage calme de 22 h à 8 h par défaut ; les horaires explicitement choisis pour une séance, une échéance ou Focus restent prioritaires.

Le minuteur programme dès son démarrage la fin du Focus / début du repos, puis la fin du repos, même lorsque l’app est suspendue. Le repos démarre à l’heure de fin réelle du Focus, y compris si l’utilisateur revient plus tard. Le temps de travail est enregistré une seule fois à la réouverture ; les exercices terminés restent à confirmer dans le bilan. Pause et réinitialisation annulent les futures alertes du minuteur. L’extension **StudayaFocusWidget** affiche les compteurs de révision et de repos sur l’écran verrouillé et dans Dynamic Island, avec un lien vers Focus ; les activités en direct doivent être autorisées sur l’iPhone. Les compteurs s’affichent sans serveur ni mises à jour réseau. Une activité peut rester visible à zéro jusqu’au retour dans l’app ou jusqu’à sa suppression par iOS.

Les invitations du matin et du soir restent récurrentes même sans réouverture. Le reste du plan local couvre jusqu’à 14 jours et garde au maximum 56 notifications de planning, avec quatre places réservées à Focus. Les identifiants stables évitent les doublons et les catégories restent représentées lorsqu’il y a beaucoup de séances. Les suivants sont renouvelés à chaque ouverture. iOS ne permet pas de recalculer arbitrairement un planning local quand l’app est arrêtée : après cette fenêtre sans réouverture, les alertes de séance et relances ponctuelles cessent jusqu’à la prochaine ouverture, tandis que les invitations quotidiennes restent actives. Les autorisations, le mode Concentration, la livraison réelle et le rendu de l’activité en direct doivent être vérifiés sur un iPhone physique.

Références Apple : [notifications locales](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app), [activités en direct](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities).

## Archives, suppression et sauvegarde

La bibliothèque permet de rechercher une matière et d’ouvrir les archives des cours/TD et échéances terminés. Les archives disposent de leur propre recherche et affichent les rappels futurs ainsi que leur historique. Glisser une matière ou un cours/TD pour le supprimer ; une confirmation détaille les données liées supprimées. Une échéance se supprime dans son écran de modification. Le temps Focus historique est conservé en retirant les liens vers les travaux supprimés.

Réglages → Sauvegarde et restauration exporte un fichier JSON versionné dans Fichiers, iCloud Drive ou une autre destination choisie. Il comprend le profil, les matières, les cours/TD et notes, les cartes, les échéances, les séances et reports, les journaux Focus, les indisponibilités, les rappels espacés et les préférences. Ce fichier n’est ni une synchronisation automatique ni une sauvegarde des droits Premium, gérés par Apple.

La restauration valide le format, la version, les identifiants, les liens et les valeurs avant de proposer une confirmation de remplacement. Elle remplace les données locales en une transaction, puis rétablit les préférences. Une sauvegarde invalide est refusée sans remplacement. Les fichiers sont limités à 20 Mo et 50 000 enregistrements. Le minuteur en cours est réinitialisé ; les notifications sont reprogrammées selon les autorisations de l’appareil destinataire. Exporter le parcours actuel avant de le remplacer si on souhaite le conserver.

## Créateur « Parcours de révision »

Les matières et TD sont séparés du formulaire initial. Depuis Today ou Révision, choisir **Créer mon Parcours de révision**. Saisir les matières, puis renseigner pour chacune : les cours/TD avec leur date de début, les présentations éventuelles, les contrôles éventuels, puis la date de l’examen final si elle est connue. Un récapitulatif précède la création ; les brouillons ne sont pas enregistrés avant validation.

Une timeline de génération à six étapes reliées reste visible au moins 15 secondes avant la confirmation. Elle affiche les matières, cours/TD et échéances du parcours, anime l’étape active, coche les étapes terminées et défile automatiquement. Elle respecte Réduire les animations et laisse ensuite ouvrir Planner. L’app signale les séances qui n’ont pas trouvé de créneau. Une matière déjà présente sous le même nom, année et semestre est réutilisée, avec ses notes et son historique conservés ; les nouveaux cours et échéances y sont ajoutés.

Les dates de début sont conservées dans la sauvegarde complète. Le planning respecte à la fois le semestre et le début de chaque cours/TD. Les cours sans échéance connue ont un horizon de planification de 90 jours à partir de leur disponibilité. Dès qu’une matière contient des cours/TD suivis, ces séances remplacent la rotation générique de la matière.

L’étape Notifications du profil propose explicitement **Activer les notifications**, qui ouvre la demande iOS si l’autorisation n’a pas encore été décidée. **Plus tard** permet de continuer. Pour les profils existants qui n’ont jamais vu cette invitation, elle apparaît dans Today. Après un refus iOS, le lien vers les réglages permet de modifier l’autorisation ; iOS ne réaffiche pas sa demande système à chaque lancement.

Le choix d’organisation du profil pilote tous les écrans : « Par semestre » affiche et utilise S1/S2 ; « Par matière » (cours/TD) masque le semestre dans le créateur et l’éditeur, regroupe les matières par année et propose une navigation annuelle dans Planner. Le moteur ignore alors les anciennes valeurs de semestre, sans effacer les données existantes.

## Import photo du planning — IA gratuite et locale

Dans une matière ou dans le **Parcours de révision**, **Importer une photo** permet d'importer automatiquement ses séances, cours et TD. Cette fonctionnalité d’IA est gratuite pour tous les utilisateurs : aucun abonnement Premium ni clé API distante (comme Gemini) n’est nécessaire.

Les étudiants choisissent une photo avec le sélecteur système ou utilisent l’appareil photo après autorisation iOS. Vision lit le texte et les tableaux localement en conservant les coordonnées. L'analyse locale sépare intelligemment chaque TD et séance en élément distinct au lieu de les fusionner dans un seul bloc. Sur iOS 26 et les appareils compatibles avec Apple Intelligence, Foundation Models peut être mis à contribution localement. Sur les autres appareils, un extracteur intelligent local prend le relais pour détecter automatiquement les TD, cours, contrôles et examens. Tout se passe sur l’appareil, de manière 100 % gratuite et confidentielle.

La prévisualisation et la gestion des séances s’affichent sous forme de **timeline interactive**, où chaque TD ou cours forme son propre jalon avec sa ligne chronologique. Chaque séance est **glissable et déplaçable (draggable & droppable)** pour réordonner facilement ses séances dans l'ordre souhaité, avec un menu contextuel rapide pour monter ou descendre d'une place. L’étudiant peut compléter ou corriger les dates, le titre, le type et les exercices avant validation.

L’import limite les photos à 30 Mo et les brouillons à 50 éléments. Les dates sont facultatives et aucune case de vérification individuelle n’est requise. Le bouton fixe **Ajouter à la matière** (ou **Ajouter au parcours**) importe les éléments sélectionnés. Les échéances sans date restent visibles avec « Date à préciser », sans rappel ni séance de préparation automatique avant de renseigner leur date. Les doublons, les examens incohérents avec les dates de début et le remplacement non confirmé d’un examen existant sont refusés avant écriture. L’ajout et la replanification sont sauvegardés ensemble.

Les fonctionnalités Premium exclusives restent dédiées aux statistiques avancées : bilan Focus sur 30 jours, temps par matière et export CSV dans Stats.

## Identité visuelle

Studaya utilise une palette violet profond, papier clair, menthe et corail. La typographie système arrondie conserve Dynamic Type et les icônes SF Symbols restent natives. Les cinq onglets sont Accueil, Planning, Focus, Matières et Progrès. L’accueil présente la progression du jour, les actions rapides, l’objectif hebdomadaire et les échéances dans des cartes. Les matières ont des couleurs stables et des icônes adaptées à leur domaine. Focus dispose d’un cadran à dégradé et d’états distincts pour le travail et la pause.

Les apparitions de cartes, retours visuels des boutons et changements d’état respectent Réduire les animations. Les champs conservent leurs zones tactiles agrandies, les sélecteurs natifs et les fonctions Premium visibles en gratuit.

Les présentations et contrôles proposent un lien facultatif vers un cours ou TD de la matière (y compris dans l’import photo). Aucun titre n’est à saisir : le nom vient du cours/TD choisi, ou de la matière si « Toute la matière » est sélectionné. Les examens restent associés à la matière. Ces liens sont conservés dans les sauvegardes ; supprimer un cours ou TD rattache ses évaluations à la matière.

Chaque matière possède un code facultatif, modifiable à la création et à l’édition ainsi que dans le parcours. Si le champ reste vide, les initiales de chaque mot du nom sont calculées automatiquement (Analyse numérique → AN). Les cartes, séances, rappels et plannings affichent ce code ; le nom complet reste conservé et recherchable, et les codes personnalisés sont inclus dans les sauvegardes.

## Calendrier interne et Calendrier Apple

Les vues semaine et mois affichent les icônes et codes des matières, avec des fonds rouges pour les examens, ambre pour les contrôles et bleus pour les présentations. Plusieurs types le même jour conservent leurs marqueurs et la couleur prioritaire de l’examen. Les séances seules sont aussi signalées ; une légende et les libellés VoiceOver expliquent les marqueurs.

Planning → Synchroniser avec Calendrier Apple (ou Réglages → Calendrier Apple) active un export unidirectionnel après autorisation complète EventKit. Studaya crée un calendrier dédié sur une source modifiable disponible. Les séances conservent leur durée ; les examens dont seule la date est connue sont sur la journée ; les autres échéances et rappels sont des repères de 15 minutes. Les éléments sans date ne sont pas exportés. Aucune alarme Apple supplémentaire n’est créée : les notifications restent gérées par Studaya.

L’ouverture de l’app et les modifications du planning mettent à jour les événements exportés avec des identifiants stables. Les modifications effectuées dans Calendrier Apple ne sont pas importées dans Studaya et peuvent être réécrites lors de la prochaine synchronisation. « Arrêter la synchronisation » conserve les événements exportés. « Tout supprimer de Calendrier Apple » exige une confirmation, retire uniquement les événements identifiés comme exportés par cette installation et désactive la synchronisation pour empêcher leur recréation. Les rendez-vous personnels, même ajoutés manuellement au calendrier Studaya, ne sont pas supprimés. Le suivi d’export reste propre à l’appareil et n’est pas inclus dans les sauvegardes de parcours ; une désinstallation efface ce suivi.

Référence : [EventKit et les autorisations Calendrier Apple](https://developer.apple.com/documentation/eventkit/accessing-calendar-using-eventkit-and-eventkitui).

Les notifications Studaya conservent désormais leurs clés et arguments de traduction via l’API de localisation différée iOS : le texte est localisé lors de la présentation. La première ouverture après mise à jour ou changement de langue retire les anciennes notifications Studaya en attente et déjà présentées, puis reprogramme les rappels et le cycle Focus. Les notifications d’autres applications ne sont pas touchées. Le minuteur verrouillé utilise un fond bleu nuit opaque et des textes blancs explicites, également dans Dynamic Island. Le libellé Focus libre est traduit côté extension, y compris pour une activité issue d’une ancienne version.
