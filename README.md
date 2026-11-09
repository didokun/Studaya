# Studaya

Application SwiftUI et SwiftData pour iPhone et iPad, à partir d’iOS 17. Studaya associe *study* et *day*. Le livre ouvert et la courbe de progression utilisent le bleu nuit #101D35 et le vert menthe #20C878.

## Lancement

Ouvrir Studaya.xcodeproj dans Xcode 26, sélectionner le schéma Studaya et un simulateur iOS. ⌘R lance l’application, ⌘U lance les tests unitaires et d’interface. Pour un appareil physique, sélectionner son équipe dans Signing & Capabilities.

## Premier planning

1. Suivre les six étapes de configuration. Renseigner la formation, le niveau, les matières, la période et les disponibilités. Le prénom et l’établissement sont facultatifs.
2. Vérifier le récapitulatif, puis choisir une formule Premium ou continuer gratuitement. Studaya inscrit une séance tournante par jour disponible pendant un ou deux ans.
3. Consulter Today et parcourir les semestres dans Planner. Ajouter ses dates d’examen et chapitres dans Révision. Leur préparation prend la priorité sur les séances régulières.
4. Utiliser Réglages pour revoir le parcours, modifier le rythme, programmer le rappel quotidien ou gérer l’abonnement. La reconfiguration conserve les séances terminées.
5. Le premier lancement après mise à jour propose le nouveau parcours aux profils de la première version. Les matières et l’historique existants sont conservés.

## Planification

Scheduling.swift reçoit le contexte SwiftData, les disponibilités, l’heure de référence et le calendrier. Le premier passage réserve les créneaux entiers avant le jour de l’examen. Il traite les échéances les plus proches en premier et équilibre les chapitres de même priorité. Un chapitre fragile bénéficie d’un rappel supplémentaire. Le second passage espace les répétitions dans les créneaux libres en remontant depuis la date d’examen.

Les modifications des chapitres, examens ou disponibilités déclenchent un recalcul. Les séances terminées gardent leur identité et réservent leur créneau. Les séances manquées sont recalculées au retour dans l’application. Le bouton de replanification indique combien de séances restent sans créneau.

## Persistance et extensions

Models.swift définit les entités et les identifiants stables. Storage.container centralise la configuration du stockage. Les préférences et l’échéance absolue du Pomodoro utilisent UserDefaults pour reprendre après suspension.

Pour activer la synchronisation, provisionner un conteneur iCloud, activer les capacités CloudKit et notifications à distance, passer une base privée à Storage.container et tester migration et conflits sur deux appareils. Les préférences restent propres à l’appareil.

## Abonnements StoreKit 2

Le schéma partagé Studaya charge Studaya.storekit à l’exécution depuis Xcode. Trois produits locaux reprennent la structure de Tidiva, mensuel, annuel et achat à vie. Les formules récurrentes ont une offre introductive de sept jours pour les comptes éligibles. Premium déverrouille le bilan Focus sur trente jours, le détail par matière et l’export CSV. Les prix proviennent de StoreKit.

PremiumOptions charge les produits, vérifie les transactions, traite les mises à jour, restaure les achats et ouvre la gestion Apple des abonnements. MembershipTests vérifie le catalogue et l’activation par achat annuel dans la boutique de test. Pour distribuer ces offres, configurer dans App Store Connect les identifiants studaya.premium.monthly, studaya.premium.yearly et studaya.premium.lifetime, le groupe, les tarifs et les essais de production.
