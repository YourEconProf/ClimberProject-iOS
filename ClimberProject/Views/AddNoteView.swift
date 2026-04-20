import SwiftUI
import PhotosUI

struct AddNoteView: View {
  @ObservedObject var vm: NoteViewModel
  let athleteId: String
  let coachId: String
  @Environment(\.dismiss) private var dismiss

  @State private var text = ""
  @State private var category: NoteCategory = .general
  @State private var isPrivate = false
  @State private var isSubmitting = false
  @State private var isProcessingOCR = false
  @State private var error: String?
  @State private var photoItem: PhotosPickerItem?
  @State private var showingCamera = false
  @State private var cameraImage: UIImage?

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker("Category", selection: $category) {
            ForEach(NoteCategory.allCases, id: \.self) { c in
              Text(c.rawValue.capitalized).tag(c)
            }
          }
          Toggle("Private", isOn: $isPrivate)
        }

        Section("Note") {
          TextField("Write a note…", text: $text, axis: .vertical)
            .lineLimit(4...10)

          HStack(spacing: 16) {
            // Photo library
            PhotosPicker(selection: $photoItem, matching: .images) {
              Label("Photo Library", systemImage: "photo")
                .font(.caption)
            }
            .onChange(of: photoItem) { item in
              guard let item else { return }
              Task { await processPickedPhoto(item) }
            }

            Divider().frame(height: 20)

            // Camera
            Button {
              showingCamera = true
            } label: {
              Label("Camera", systemImage: "camera")
                .font(.caption)
            }

            if isProcessingOCR {
              Spacer()
              ProgressView().scaleEffect(0.8)
            }
          }
          .foregroundColor(.accentColor)
        }

        if let error {
          Section {
            Text(error).foregroundColor(.red).font(.caption)
          }
        }
      }
      .navigationTitle("Add Note")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { Task { await submit() } }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
        }
      }
      .fullScreenCover(isPresented: $showingCamera) {
        CameraView(image: $cameraImage)
          .ignoresSafeArea()
      }
      .onChange(of: cameraImage) { image in
        guard let image else { return }
        Task { await processImage(image) }
      }
    }
  }

  // MARK: - OCR

  private func processPickedPhoto(_ item: PhotosPickerItem) async {
    isProcessingOCR = true
    error = nil
    defer { isProcessingOCR = false }
    do {
      guard let data = try await item.loadTransferable(type: Data.self),
            let image = UIImage(data: data) else { return }
      await processImage(image)
    } catch {
      self.error = "Could not load photo."
    }
  }

  private func processImage(_ image: UIImage) async {
    isProcessingOCR = true
    error = nil
    defer { isProcessingOCR = false }
    do {
      let recognized = try await OCRService.recognizeText(from: image)
      guard !recognized.isEmpty else {
        self.error = "No text found in image."
        return
      }
      text = text.isEmpty ? recognized : text + "\n" + recognized
    } catch {
      self.error = "OCR failed: \(error.localizedDescription)"
    }
  }

  // MARK: - Submit

  private func submit() async {
    isSubmitting = true
    error = nil
    do {
      try await vm.addNote(
        athleteId: athleteId,
        coachId: coachId,
        text: text.trimmingCharacters(in: .whitespacesAndNewlines),
        category: category,
        isPrivate: isPrivate
      )
      dismiss()
    } catch {
      self.error = error.localizedDescription
      isSubmitting = false
    }
  }
}

// MARK: - Camera wrapper

struct CameraView: UIViewControllerRepresentable {
  @Binding var image: UIImage?
  @Environment(\.dismiss) private var dismiss

  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.delegate = context.coordinator
    return picker
  }

  func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let parent: CameraView
    init(_ parent: CameraView) { self.parent = parent }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
      parent.image = info[.originalImage] as? UIImage
      parent.dismiss()
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
      parent.dismiss()
    }
  }
}
