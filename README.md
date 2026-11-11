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

Réglages → Rappels et notifications permet d’activer le rappel quotidien et les notifications d’échéance séparément. Les examens d’une matière reçoivent des rappels J−7, J−1 et le jour même à 9 h. Les contrôles, présentations et rendus utilisent la date de rappel choisie et leur échéance exacte. Les rappels espacés suivent leur date à 18 h. Les modifications et validations actualisent les notifications ; supprimer un travail annule ses notifications futures. Aucune autorisation n’est demandée avant une activation explicite.

L’app garde au maximum 60 notifications locales en attente, rappel quotidien compris. Si le parcours dépasse cette capacité, les plus proches sont programmées et le statut dans les réglages l’indique. Les suivantes sont rechargées à l’ouverture de l’app. Les autorisations, le mode Concentration et la livraison effective doivent aussi être vérifiés sur appareil réel.

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

Dans une matière ou dans le **Parcours de révision**, **Importer un planning en photo** permet d'importer automatiquement ses séances, cours et TD. Cette fonctionnalité d’IA est gratuite pour tous les utilisateurs : aucun abonnement Premium ni clé API distante (comme Gemini) n’est nécessaire.

Les étudiants choisissent une photo avec le sélecteur système ou utilisent l’appareil photo après autorisation iOS. Vision lit le texte et les tableaux localement en conservant les coordonnées. L'analyse locale sépare intelligemment chaque TD et séance en élément distinct au lieu de les fusionner dans un seul bloc. Sur iOS 26 et les appareils compatibles avec Apple Intelligence, Foundation Models peut être mis à contribution localement. Sur les autres appareils, un extracteur intelligent local prend le relais pour détecter automatiquement les TD, cours, contrôles et examens. Tout se passe sur l’appareil, de manière 100 % gratuite et confidentielle.

La prévisualisation et la gestion des séances s’affichent sous forme de **timeline interactive**, où chaque TD ou cours forme son propre jalon avec sa ligne chronologique. Chaque séance est **glissable et déplaçable (draggable & droppable)** pour réordonner facilement ses séances dans l'ordre souhaité, avec un menu contextuel rapide pour monter ou descendre d'une place. L’étudiant peut compléter ou corriger les dates, le titre, le type et les exercices avant validation.

L’import limite les photos à 30 Mo et les brouillons à 50 éléments. Les doublons, les dates manquantes, les examens incohérents avec les dates de début et le remplacement non confirmé d’un examen existant sont refusés avant écriture. L’ajout et la replanification sont sauvegardés ensemble.

Les fonctionnalités Premium exclusives restent dédiées aux statistiques avancées : bilan Focus sur 30 jours, temps par matière et export CSV dans Stats.

## Identité visuelle

Studaya utilise une palette violet profond, papier clair, menthe et corail. La typographie système arrondie conserve Dynamic Type et les icônes SF Symbols restent natives. Les cinq onglets sont Accueil, Planning, Focus, Matières et Progrès. L’accueil présente la progression du jour, les actions rapides, l’objectif hebdomadaire et les échéances dans des cartes. Les matières ont des couleurs stables et des icônes adaptées à leur domaine. Focus dispose d’un cadran à dégradé et d’états distincts pour le travail et la pause.

Les apparitions de cartes, retours visuels des boutons et changements d’état respectent Réduire les animations. Les champs conservent leurs zones tactiles agrandies, les sélecteurs natifs et les fonctions Premium visibles en gratuit.
