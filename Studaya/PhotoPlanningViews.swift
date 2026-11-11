import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation
import ImageIO

struct PhotoPlanningGate: View {
    let subject: Subject
    var body: some View {
        NavigationStack {
            PhotoPlanningImporter(subject: subject)
        }
    }
}

struct PhotoPlanningImporter: View {
    let subject: Subject?
    var draftSubjectName: String? = nil
    var draftExamDate: Date? = nil
    var onDraftImport: (([ImportedPlanningEntry], Bool) throws -> Void)? = nil
    private var subjectName: String { subject?.name ?? draftSubjectName ?? "" }
    private var existingExam: Date? { if let subject, subject.hasExam { return subject.exam }; return draftExamDate }
    @Environment(\.modelContext) private var db
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var membership = Membership.shared
    @State private var onlyTD = false
    @State private var photo: PhotosPickerItem?
    @State private var camera = false
    @State private var preview: UIImage?
    @State private var sourceText = ""
    @State private var entries: [ImportedPlanningEntry] = []
    @State private var status = ""
    @State private var busy = false
    @State private var saved = false
    @State private var replaceExam = false
    @State private var message: String?
    @State private var work: Task<Void, Never>?
    @State private var operationID = UUID()
    private var selectedCount: Int { entries.filter(\.selected).count }
    var body: some View {
        Form {
            Section(subjectName) {
                Text("Photographie un planning de cette matière ou sélectionne une image. La photo est analysée sur ton iPhone. Rien n’est ajouté sans ta validation.")
                PhotosPicker(selection: $photo, matching: .images, photoLibrary: .shared()) {
                    Label("Choisir une photo du planning", systemImage: "photo")
                }.disabled(busy)
                Button("Prendre une photo", systemImage: "camera") { takePhoto() }
                    .disabled(busy || !UIImagePickerController.isSourceTypeAvailable(.camera))
                if !UIImagePickerController.isSourceTypeAvailable(.camera) { Text("Appareil photo indisponible ici. Tu peux choisir une image.").font(.footnote).foregroundStyle(.secondary) }
                if let preview { Image(uiImage: preview).resizable().scaledToFit().frame(maxHeight: 220).accessibilityLabel("Photo du planning sélectionnée") }
            }
            if busy { Section { ProgressView("Lecture et analyse du planning…"); Button("Annuler l’analyse") { operationID = UUID(); work?.cancel(); busy = false; status = "Analyse annulée. Aucun élément ajouté." } } }
            if !entries.isEmpty {
                Section("Prévisualisation · \(selectedCount) sélectionné(s)") {
                    Toggle("Afficher uniquement les TD", isOn: $onlyTD)
                    let visible = entries.filter { !onlyTD || $0.kind == .td }.map(\.id)
                    UnitTimeline(ids: visible) { order in
                        let lookup = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
                        var reordered = order.makeIterator()
                        entries = entries.map { row in
                            guard visible.contains(row.id), let next = reordered.next() else { return row }
                            return lookup[next] ?? row
                        }
                    } card: { id in
                        if let i = entries.firstIndex(where: { $0.id == id }) {
                            PhotoPlanningEntryCard(entry: $entries[i]) {
                                entries.removeAll { $0.id == id }
                            }
                        }
                    }
                    Button("Ajouter un élément manuellement", systemImage: "plus") { entries.append(ImportedPlanningEntry()) }
                        .disabled(busy || entries.count >= 50)
                }
                if let existingExam, entries.contains(where: { $0.selected && $0.kind == .exam }) {
                    Section("Examen final existant") {
                        Text(existingExam, format: .dateTime.day().month().year())
                        Toggle("Remplacer cette date par celle de la photo", isOn: $replaceExam)
                    }
                }
                Section {
                    Button(onDraftImport == nil ? "Ajouter les éléments vérifiés au planning" : "Ajouter au Parcours de révision") { save() }
                        .disabled(busy || saved || (try? PhotoPlanning.validate(entries)) == nil)
                    Text("Les cases de vérification sont obligatoires. L’import ne supprime pas les cours ou TD existants.").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .studyScreen()
        .navigationTitle("Importer un planning")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fermer") { dismiss() }
            }
        }
        .sheet(isPresented: $camera) {
            PlanningCamera { image in
                camera = false
                guard let image, let data = image.jpegData(compressionQuality: 0.85) else { return }
                work?.cancel(); let token = UUID(); operationID = token; work = Task { await process(data, token: token) }
            }
        }
        .onChange(of: photo) { _, item in
            guard let item else { return }
            work?.cancel()
            let token = UUID(); operationID = token
            work = Task {
                defer { if operationID == token { photo = nil } }
                do {
                    busy = true
                    guard let data = try await item.loadTransferable(type: Data.self) else { throw StudyError.invalid("Cette photo n’a pas pu être chargée.") }
                    try Task.checkCancellation()
                    await process(data, token: token)
                } catch is CancellationError { if operationID == token { busy = false } }
                catch { if operationID == token { busy = false; message = error.localizedDescription } }
            }
        }
        .onDisappear { work?.cancel() }
        .alert(saved ? "Import terminé" : "Import photo", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button(saved ? (onDraftImport == nil ? "Voir la matière" : "Retour au parcours") : "OK") { if saved { dismiss() } }
            if !saved { Link("Réglages iOS", destination: URL(string: UIApplication.openSettingsURLString)!) }
        } message: { Text(message ?? "") }
    }
    private func takePhoto() {
        work?.cancel()
        work = Task {
            do {
                let authorization = AVCaptureDevice.authorizationStatus(for: .video)
                var allowed = authorization == .authorized
                if authorization == .notDetermined { allowed = await AVCaptureDevice.requestAccess(for: .video) }
                guard allowed else { throw StudyError.invalid("Autorise l’appareil photo dans les réglages iOS de Studaya, ou choisis une photo existante.") }
                try Task.checkCancellation(); camera = true
            } catch is CancellationError {} catch { message = error.localizedDescription }
        }
    }
    private func process(_ data: Data, token: UUID) async {
        guard operationID == token else { return }
        onlyTD = false
        busy = true; saved = false; replaceExam = false
        entries = []; sourceText = ""; status = ""; preview = nil
        do {
            let task = Task.detached(priority: .userInitiated) {
                try Task.checkCancellation()
                let result = try PlanningPhotoOCR.read(data)
                try Task.checkCancellation()
                return result
            }
            let result = try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
            try Task.checkCancellation()
            guard operationID == token else { return }
            if let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
               let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 900, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) {
                preview = UIImage(cgImage: image)
            }
            sourceText = result.text
            let analysis: (entries: [ImportedPlanningEntry], message: String)
            let tableEntries = (try? await PlanningTable.read(data)) ?? []
            try Task.checkCancellation()
            if tableEntries.isEmpty {
                analysis = try await PhotoPlanning.analyze(result.text, layout: result.layoutText, subject: subjectName)
            } else {
                analysis = (tableEntries, "\(tableEntries.count) séances proposées pour \(subjectName) à partir des lignes du tableau. Vérifie les matières, les dates et les extraits avant l’import.")
            }
            try Task.checkCancellation()
            guard operationID == token else { return }
            entries = analysis.entries
            status = (result.lowConfidence ? "Certains mots sont peu lisibles. " : "") + analysis.message
            busy = false
        } catch is CancellationError { if operationID == token { busy = false; status = "Analyse annulée. Aucun élément ajouté." } }
        catch { if operationID == token { busy = false; message = error.localizedDescription } }
    }
    private func save() {
        busy = true
        work = Task {
            do {
                if let onDraftImport {
                    try Task.checkCancellation()
                    let rows = try PhotoPlanning.validate(entries)
                    try onDraftImport(rows, replaceExam)
                    saved = true; busy = false
                    message = "\(rows.count) élément(s) ajoutés au brouillon. Ils seront enregistrés lorsque tu créeras le planning."
                } else if let subject {
                    let missing = try await PhotoPlanning.save(entries, subject: subject, replaceExam: replaceExam, db: db)
                    saved = true; busy = false
                    message = "\(selectedCount) élément(s) ajouté(s)." + (missing > 0 ? " \(missing) séance(s) n’ont pas de créneau avant leur échéance. Ajuste tes disponibilités." : "")
                } else { throw StudyError.invalid("Choisis une matière pour cet import.") }
            } catch { busy = false; message = error.localizedDescription }
        }
    }
}

private struct PhotoPlanningEntryCard: View {
    @Binding var entry: ImportedPlanningEntry
    let onDelete: () -> Void
    private var revision: String { "\(entry.title)|\(entry.kind)|\(String(describing: entry.date))|\(entry.sessions)|\(entry.exercises)" }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                StudyPill(title: entry.kind.rawValue, color: entry.kind == .td ? StudyDesign.mint : StudyDesign.accent)
                Toggle("Importer", isOn: $entry.selected).labelsHidden()
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash").foregroundStyle(.red).font(.subheadline)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Supprimer cet élément")
            }
            TextField("Titre du cours, TD ou échéance", text: $entry.title)
                .textFieldStyle(StudyTextFieldStyle(boxed: true))
            Picker("Type", selection: $entry.kind) {
                ForEach(ImportedKind.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            HStack(spacing: 12) {
                Toggle("Date", isOn: Binding(get: { entry.date != nil }, set: { entry.date = $0 ? Date() : nil }))
                    .fixedSize()
                if entry.date != nil {
                    DatePicker("", selection: Binding(get: { entry.date ?? .now }, set: { entry.date = $0 }), displayedComponents: entry.kind.isUnit ? [.date] : [.date, .hourAndMinute])
                        .labelsHidden()
                } else {
                    Text("Date à préciser").font(.caption).foregroundStyle(.orange)
                }
            }
            if entry.kind != .exam {
                Stepper("Préparation · \(entry.sessions) séances", value: $entry.sessions, in: 1...30)
                    .font(.subheadline)
            }
            if entry.kind == .td {
                Stepper("\(entry.exercises) exercices", value: $entry.exercises, in: 1...100)
                    .font(.subheadline)
            }
            Toggle("J’ai vérifié cet élément", isOn: $entry.verified)
                .font(.footnote)
                .tint(StudyDesign.mint)
        }
        .padding(.vertical, 4)
        .onChange(of: revision) { _, _ in entry.verified = false }
    }
}

private struct PlanningCamera: UIViewControllerRepresentable {
    let completion: (UIImage?) -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController(); picker.sourceType = .camera
        picker.cameraCaptureMode = .photo; picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: (UIImage?) -> Void
        init(completion: @escaping (UIImage?) -> Void) { self.completion = completion }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { completion(nil) }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) { completion(info[.originalImage] as? UIImage) }
    }
}
