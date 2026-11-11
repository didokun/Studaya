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
                    row("Profil étudiant","person.crop.circle") {
                        Form { TextField("Prénom", text: $name); Stepper("Objectif · \(goal) h par semaine", value: $goal, in: 1...60) }
                    }
                    row("Études et calendrier","graduationcap") {
                        Form {
                            if let p = profiles.first {
                                LabeledContent("Formation", value: p.program)
                                LabeledContent("Niveau", value: p.level)
                                if !p.institution.isEmpty { LabeledContent("Établissement", value: p.institution) }
                                LabeledContent("Durée", value: "\(p.years) année(s)")
                                LabeledContent("Matières", value: p.courses.joined(separator: ", "))
                            }
                            Button("Revoir ma configuration") { edit = true }
                        }
                    }
                    row("Emploi du temps et indisponibilités", "calendar.badge.minus") { UnavailabilitySettings() }
                    row("Sauvegarde et restauration", "externaldrive") { BackupSettings() }
                    row("Rythme de révision","calendar") { RhythmSettings() }
                    row("Concentration","timer") {
                        Form {
                            Stepper("Focus · \(focus) min", value: $focus, in: 5...90, step: 5)
                            Stepper("Pause · \(rest) min", value: $rest, in: 1...30)
                        }
                    }
                    row("Rappels et notifications","bell") { ReminderSettings() }
                }
                Section {
                    row("Abonnement","star.circle") { PremiumOptions().padding(.horizontal) }
                    row("Données et confidentialité","hand.raised") {
                        Form {
                            Text("Ton profil et tes révisions sont conservés sur cet appareil. Les achats sont gérés par Apple.")
                            Link("Conditions d’utilisation Apple", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            Button("Effacer les données de Studaya", role: .destructive) { confirm = true }
                        }
                    }
                }
            }.studyScreen().navigationTitle("Réglages").toolbar { Button("Terminé") { dismiss() } }
        }.sheet(isPresented: $edit) { if let p = profiles.first { AcademicSetup(profile: p) { edit = false } } }
        .alert("Effacer le profil et toutes les révisions ?", isPresented: $confirm) {
            Button("Annuler", role: .cancel) {}
            Button("Effacer et recommencer", role: .destructive) { reset() }
        } message: { Text("Cette action est définitive. Ton abonnement reste géré par Apple.") }
        .alert("Erreur", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") {} } message: { Text(error ?? "") }
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
            Button("Enregistrer et replanifier") {
                do {
                    let missing = try Scheduler.rebuild(db, availability: rhythm)
                    rhythm.persist()
                    status = missing == 0 ? "Planning mis à jour." : "\(missing) séances d’examen sans créneau."
                } catch { db.rollback(); status = error.localizedDescription }
            }.disabled(rhythm.weekdays.isEmpty)
            if !status.isEmpty { Text(status) }
        }
    }
}

struct ReminderSettings: View {
    var body: some View {
        Form { EventReminderSettings() }.studyScreen().navigationTitle("Rappels et notifications")
    }
}
