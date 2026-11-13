import SwiftUI
import SwiftData
import UserNotifications

struct StudySettings: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var db
    @Query var profiles: [AcademicProfile]
    @AppStorage("studentName") var name = ""
    @AppStorage("weeklyHours") var goal = 5
    @AppStorage("focusMinutes") var focus = 25
    @AppStorage("breakMinutes") var rest = 5
    @State private var edit = false
    @State private var confirm = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    row(String(localized: "Profil étudiant"),"person.crop.circle") {
                        Form { TextField(String(localized: "Prénom"), text: $name); Stepper(String(localized: "Objectif · \(goal) h par semaine"), value: $goal, in: 1...60) }
                    }
                    row(String(localized: "Études et calendrier"),"graduationcap") {
                        Form {
                            if let p = profiles.first {
                                LabeledContent(String(localized: "Formation"), value: p.program)
                                LabeledContent(String(localized: "Niveau"), value: p.level)
                                if !p.institution.isEmpty { LabeledContent(String(localized: "Établissement"), value: p.institution) }
                                LabeledContent(String(localized: "Durée"), value: String(localized: "\(p.years) année(s)"))
                                LabeledContent(String(localized: "Matières"), value: p.courses.joined(separator: ", "))
                            }
                            Button(String(localized: "Revoir ma configuration")) { edit = true }
                        }
                    }
                    row(String(localized: "Emploi du temps et indisponibilités"), "calendar.badge.minus") { UnavailabilitySettings() }
                    row(String(localized: "Sauvegarde et restauration"), "externaldrive") { BackupSettings() }
                    row(String(localized: "Rythme de révision"),"calendar") { RhythmSettings() }
                    row(String(localized: "Concentration"),"timer") {
                        Form {
                            Stepper(String(localized: "Focus · \(focus) min"), value: $focus, in: 5...90, step: 5)
                            Stepper(String(localized: "Pause · \(rest) min"), value: $rest, in: 1...30)
                        }
                    }
                    row(String(localized: "Rappels et notifications"),"bell") { ReminderSettings() }
                    row(String(localized: "Calendrier Apple"), "calendar.badge.clock") { CalendarSyncSettings() }
                }
                Section {
                    row(String(localized: "Abonnement"),"star.circle") { PremiumOptions().padding(.horizontal) }
                    row(String(localized: "Données et confidentialité"),"hand.raised") {
                        Form {
                            Text(String(localized: "Ton profil et tes révisions sont conservés sur cet appareil. Les achats sont gérés par Apple."))
                            Link(String(localized: "Conditions d’utilisation Apple"), destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            Text(String(localized: "Google AdMob diffuse des publicités pour les utilisateurs gratuits majeurs, selon leurs choix de confidentialité."))
                            Link(String(localized: "Données et confidentialité"), destination: URL(string: "https://talinha.com/studaya/privacy/")!)
                            AdvertisingPrivacyOptions()
                            Button(String(localized: "Effacer les données de Studaya"), role: .destructive) { confirm = true }
                        }
                    }
                }
            }.studyScreen().browsingAdvertising(true).navigationTitle(String(localized: "Réglages")).toolbar { Button(String(localized: "Terminé")) { dismiss() } }
        }.sheet(isPresented: $edit) { if let p = profiles.first { AcademicSetup(profile: p) { edit = false } } }
        .alert(String(localized: "Effacer le profil et toutes les révisions ?"), isPresented: $confirm) {
            Button(String(localized: "Annuler"), role: .cancel) {}
            Button(String(localized: "Effacer et recommencer"), role: .destructive) { reset() }
        } message: { Text(String(localized: "Cette action est définitive. Ton abonnement reste géré par Apple.")) }
        .alert(String(localized: "Erreur"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") {} } message: { Text(error ?? "") }
    }
    private func row<V: View>(_ title: String, _ symbol: String, @ViewBuilder content: @escaping () -> V) -> some View {
        NavigationLink { content().studyScreen().navigationTitle(title).navigationBarTitleDisplayMode(.inline) } label: {
            HStack(spacing: 14) {
                StudyBadge(symbol: symbol, size: 40)
                Text(title).font(.headline)
            }.foregroundStyle(Color.navy)
        }
    }
    private func reset() {
        do {
            try StudyBackup.removeAll(db)
            try db.save()
            for key in [StudentNotificationOptions.key,"notificationAnchor","studentName","welcomed","weeklyHours","weekdays","startHour","endHour","sessionMinutes","focusMinutes","breakMinutes","focusSubject","timerEnd","timerRemaining","timerLength","timerRest","reminderHour","reminderEnabled","eventRemindersEnabled","focusChapter","focusSession","focusReview","focusRunID"] { StudyPreferences.current.removeObject(forKey: key) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["studaya.daily"])
            StudyPreferences.current.removeObject(forKey: "dataChangeReason")
            StudyPreferences.current.set(UUID().uuidString, forKey: "dataRevision")
            Task { await EventReminders.shared.refresh(db); await FocusCompanion.shared.sync(db) }
            dismiss()
        } catch { db.rollback(); self.error = error.localizedDescription }
    }
}

struct RhythmSettings: View {
    @Environment(\.modelContext) var db
    @State var rhythm = Availability.saved
    @State var status = ""
    var body: some View {
        Form {
            RhythmFields(rhythm: $rhythm)
            Button(String(localized: "Enregistrer et replanifier")) {
                do {
                    let missing = try Scheduler.rebuild(db, availability: rhythm)
                    rhythm.persist()
                    status = missing == 0 ? String(localized: "Planning mis à jour.") : String(localized: "\(missing) séances d’examen sans créneau.")
                } catch { db.rollback(); status = error.localizedDescription }
            }.disabled(rhythm.weekdays.isEmpty)
            if !status.isEmpty { Text(status) }
        }
    }
}

struct ReminderSettings: View {
    var body: some View {
        Form { EventReminderSettings() }.studyScreen().navigationTitle(String(localized: "Rappels et notifications"))
    }
}
