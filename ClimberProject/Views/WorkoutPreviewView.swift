import SwiftUI

struct WorkoutPreviewView: View {
  @ObservedObject var vm: WorkoutViewModel
  let workout: Workout
  var onCopy: () -> Void

  @EnvironmentObject var authVM: AuthViewModel
  @Environment(\.dismiss) private var dismiss

  @State private var editing: Workout?
  @State private var shareURL: URL?

  private var editMode: WorkoutFormMode {
    if let aid = workout.athleteId { return .athlete(id: aid) }
    return .template(gymId: workout.gymId ?? authVM.currentCoach?.gymId ?? "")
  }

  var body: some View {
    NavigationStack {
      List {
        Section {
          VStack(alignment: .leading, spacing: 4) {
            Text(workout.displayTitle).font(.title2).bold()
            Text("\(workout.sortedSets.count) sets • \(workout.totalExerciseCount) exercises")
              .font(.caption).foregroundColor(.secondary)
            if workout.isTemplate {
              Text("Template").font(.caption2)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.15))
                .foregroundColor(.accentColor)
                .clipShape(Capsule())
            } else if let a = workout.athlete {
              Text("Athlete: \(a.displayName)").font(.caption).foregroundColor(.secondary)
            }
          }
        }

        ForEach(Array(workout.sortedSets.enumerated()), id: \.element.id) { idx, s in
          Section {
            let rounds = s.effectiveRoundsCount
            HStack {
              if let t = s.setType?.name, !t.isEmpty {
                Text("Set \(idx + 1): \(t)").font(.headline)
              } else {
                Text("Set \(idx + 1)").font(.headline)
              }
              Spacer()
              if let r = s.repeatCount, r > 1 {
                Text("Repeat ×\(r)").font(.caption).foregroundColor(.secondary)
              }
            }
            if rounds > 1 {
              Text("\(rounds) rounds").font(.caption).foregroundColor(.secondary)
            }
            ForEach(s.sortedExercises) { ex in
              VStack(alignment: .leading, spacing: 4) {
                Text(ex.displayName).font(.subheadline).bold()
                if rounds > 1 {
                  let diffs = ex.effectiveDifficulties(roundsCount: rounds)
                  let reps = ex.effectiveReps(roundsCount: rounds)
                  ForEach(0..<rounds, id: \.self) { i in
                    HStack {
                      Text("Round \(i + 1)").font(.caption).foregroundColor(.secondary)
                        .frame(width: 70, alignment: .leading)
                      if !diffs[i].isEmpty {
                        Text(diffs[i]).font(.caption)
                      }
                      Spacer()
                      if !reps[i].isEmpty {
                        Text("\(reps[i]) reps").font(.caption).foregroundColor(.secondary)
                      }
                    }
                  }
                } else {
                  HStack {
                    if let d = ex.difficulty, !d.isEmpty { Text(d).font(.caption) }
                    Spacer()
                    if let r = ex.reps, !r.isEmpty {
                      Text("\(r) reps").font(.caption).foregroundColor(.secondary)
                    }
                  }
                }
              }
            }
          }
        }

        if let notes = workout.notes, !notes.isEmpty {
          Section("Coach Notes") {
            Text(notes).font(.body)
          }
        }
      }
      .navigationTitle("Preview")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") { dismiss() }
        }
        ToolbarItem(placement: .primaryAction) {
          Menu {
            Button { editing = workout } label: { Label("Edit", systemImage: "pencil") }
            Button { onCopy() } label: { Label("Add to Athlete", systemImage: "person.badge.plus") }
            Button { sharePDF() } label: { Label("Share PDF", systemImage: "square.and.arrow.up") }
          } label: {
            Image(systemName: "ellipsis.circle")
          }
        }
      }
      .sheet(item: $editing) { w in
        AddWorkoutView(
          vm: vm,
          mode: editMode,
          coachId: authVM.currentCoach?.id ?? "",
          gymId: authVM.currentCoach?.gymId ?? "",
          editing: w
        )
      }
      .sheet(item: $shareURL) { url in
        ShareSheet(items: [url])
      }
    }
  }

  private func sharePDF() {
    let athleteName = workout.athlete?.displayName
    if let url = WorkoutPDFRenderer.renderPDF(workout, athleteName: athleteName) {
      shareURL = url
    }
  }
}

extension URL: Identifiable {
  public var id: String { absoluteString }
}

struct ShareSheet: UIViewControllerRepresentable {
  let items: [Any]
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }
  func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
