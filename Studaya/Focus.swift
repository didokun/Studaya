import SwiftUI
import SwiftData

struct Focus: View {
    @Query(sort: \Subject.name) var subjects: [Subject]
    @AppStorage("focusSubject") var subject = ""
    @Environment(\.modelContext) var db
    @AppStorage("focusMinutes") var work = 25
    @AppStorage("breakMinutes") var rest = 5
    @AppStorage("timerEnd") var end = 0.0
    @AppStorage("timerRemaining") var paused = 0
    @AppStorage("timerLength") var length = 0
    @AppStorage("timerRest") var isRest = false
    @State var error: String?
    var duration: Int { length > 0 ? length : (isRest ? rest : work) * 60 }
    func remaining(_ now: Date) -> Int {
        end > 0 ? max(0, Int(ceil(end - now.timeIntervalSince1970))) : (paused > 0 ? paused : duration)
    }
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { clock in
            let seconds = remaining(clock.date)
            VStack(spacing: 26) {
                Text(isRest ? "Pause" : "Concentration").font(.title2.bold())
                Picker("Matière", selection: $subject) {
                    Text("Focus libre").tag("")
                    ForEach(subjects) { Text($0.name).tag($0.id.uuidString) }
                }.disabled(length > 0)
                ZStack {
                    Circle().stroke(Color.navy.opacity(0.09), lineWidth: 12)
                    Circle().trim(from: 0, to: min(1, Double(seconds) / Double(duration))).stroke(Color.mintBrand, style: StrokeStyle(lineWidth: 12, lineCap: .round)).rotationEffect(.degrees(-90))
                    Text(String(format: "%02d:%02d", seconds/60, seconds%60)).font(.system(size: 54, weight: .medium, design: .rounded)).monospacedDigit()
                }.aspectRatio(1, contentMode: .fit).frame(maxWidth: 285).padding()
                Button(end > 0 ? "Mettre en pause" : (paused > 0 ? "Reprendre" : "Commencer")) {
                    if end > 0 {
                        let left = remaining(.now)
                        if left == 0 { finish() } else { paused = left; end = 0 }
                    } else {
                        length = duration
                        end = Date.now.timeIntervalSince1970 + Double(remaining(.now))
                        paused = 0
                    }
                }.buttonStyle(Primary())
                Button("Réinitialiser") { end = 0; paused = 0; length = 0; isRest = false }
                if let error { Text(error).foregroundStyle(.red) }
            }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: seconds, initial: true) { _, seconds in if end > 0 && seconds == 0 { finish() } }
        }
    }
    func finish() {
        if !isRest {
            let log = FocusLog(minutes: duration / 60, date: Date(timeIntervalSince1970: end))
            log.subjectID = UUID(uuidString: subject)
            db.insert(log)
            do { try db.save() } catch { db.delete(log); self.error = error.localizedDescription; return }
        }
        end = 0; paused = 0; length = 0; isRest.toggle()
    }
}
