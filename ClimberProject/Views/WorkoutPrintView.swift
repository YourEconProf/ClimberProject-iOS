import SwiftUI

struct WorkoutPrintView: View {
  let workout: Workout
  let athleteName: String?

  private var header: String {
    if let name = workout.name, !name.isEmpty { return name }
    if let a = athleteName { return a }
    return "Workout"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(header).font(.system(size: 22, weight: .bold))
        HStack(spacing: 10) {
          if let a = athleteName, workout.name != nil {
            Text("Athlete: \(a)").font(.system(size: 11))
          }
          Text("Date: \(workout.workoutDate)").font(.system(size: 11))
          if let c = workout.coach?.name {
            Text("Coach: \(c)").font(.system(size: 11))
          }
        }
        .foregroundColor(.secondary)
      }

      ForEach(Array(workout.sortedSets.enumerated()), id: \.element.id) { idx, s in
        let rounds = s.effectiveRoundsCount
        let typeName = (s.setType?.name ?? "").uppercased()
        VStack(alignment: .leading, spacing: 6) {
          HStack {
            Text(typeName.isEmpty ? "SET \(idx + 1)" : "SET \(idx + 1): \(typeName)")
              .font(.system(size: 13, weight: .bold))
            Spacer()
            if let r = s.repeatCount, r > 1 {
              Text("Repeat \(r)×").font(.system(size: 11))
            }
          }
          if rounds > 1 {
            HStack(spacing: 0) {
              Text("Exercise").font(.system(size: 10, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
              ForEach(0..<rounds, id: \.self) { i in
                Text("R\(i + 1) Diff").font(.system(size: 10, weight: .semibold))
                  .frame(maxWidth: .infinity, alignment: .leading)
                Text("R\(i + 1) Reps").font(.system(size: 10, weight: .semibold))
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
            }
            .padding(.vertical, 2)
            .background(Color.gray.opacity(0.15))
            ForEach(s.sortedExercises) { ex in
              let diffs = ex.effectiveDifficulties(roundsCount: rounds)
              let reps = ex.effectiveReps(roundsCount: rounds)
              HStack(spacing: 0) {
                Text(ex.displayName).font(.system(size: 11))
                  .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(0..<rounds, id: \.self) { i in
                  Text(diffs[i]).font(.system(size: 11))
                    .frame(maxWidth: .infinity, alignment: .leading)
                  Text(reps[i]).font(.system(size: 11))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
              }
              .padding(.vertical, 1)
            }
          } else {
            HStack(spacing: 0) {
              Text("Exercise").font(.system(size: 10, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
              Text("Difficulty").font(.system(size: 10, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
              Text("Reps").font(.system(size: 10, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 2)
            .background(Color.gray.opacity(0.15))
            ForEach(s.sortedExercises) { ex in
              HStack(spacing: 0) {
                Text(ex.displayName).font(.system(size: 11))
                  .frame(maxWidth: .infinity, alignment: .leading)
                Text(ex.difficulty ?? "").font(.system(size: 11))
                  .frame(maxWidth: .infinity, alignment: .leading)
                Text(ex.reps ?? "").font(.system(size: 11))
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
              .padding(.vertical, 1)
            }
          }
        }
        .padding(8)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray, lineWidth: 0.5))
      }

      if let notes = workout.notes, !notes.isEmpty {
        VStack(alignment: .leading, spacing: 3) {
          Text("Coach Notes").font(.system(size: 12, weight: .bold))
          Text(notes).font(.system(size: 11))
        }
      }

      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Image(systemName: "square")
          Text("Completed").font(.system(size: 11))
        }
        Text("Athlete Feedback").font(.system(size: 12, weight: .bold))
        ForEach(0..<5, id: \.self) { _ in
          Rectangle().fill(Color.gray.opacity(0.4)).frame(height: 0.5)
            .padding(.vertical, 6)
        }
      }

      Spacer(minLength: 0)
    }
    .padding(36)
    .frame(width: 612, height: 792, alignment: .topLeading)
    .background(Color.white)
    .foregroundColor(.black)
  }
}
