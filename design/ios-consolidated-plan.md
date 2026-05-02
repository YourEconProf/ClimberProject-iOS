# iOS Consolidated Implementation Plan

**Date:** 2026-05-01
**Scope:** Single plan combining `ios-parity-plan.md`, `ios-feature-spec-2026-04-28.md`, `changes-2026-04-30.md`, `ios-2026-05-01.md`, and `age-category-rule.md`.

This plan deduplicates the five design docs and reflects the current state of the iOS codebase. Items already shipped are listed in §0 for reference; the work to do is in §1 onward, ordered by priority.

---

## 0. Already shipped (no action required)

These were specified across the five docs and have landed:

- **AI Reassess `force=true`** — `AthleteAssessmentViewModel.swift:100`
- **AI note category filtering** — `category != 'ai'` applied to note queries; `'ai'` excluded from category picker (`NoteViewModel.swift:22`, `Note.swift:23-29`)
- **Mental Performance Framework** — model, VM, view, RPC `save_mental_framework`, U17/U19 gating (`MentalFramework.swift`, `MentalFrameworkViewModel.swift:60`, `AthleteDetailView.swift:185`)
- **Athlete-page alerts** — unresolved alerts grouped by severity with acknowledge / resolve buttons (`AlertDashboardViewModel.swift`, `AthleteAssessmentViewModel.swift:42`)
- **Athlete edit form** — height/weight/wingspan inputs already removed (`AddAthleteView.swift`)
- **Check-ins** — `athlete_checkins` model + `CheckinModalView`, U11/U13 reduced fields via `isYouthRestrictedCheckin` (`Athlete.swift:104-118`)
- **Athlete denormalised columns** — `experience_level`, `phv_stage`, `full_crimp_ready`, `campus_ready`, `max_hang_kg`, etc. (`Athlete.swift:21-40`)
- **Workout status / planned_for + Approve button** — (`Workout.swift:12-13`, `AthleteWorkoutHistoryView.swift:35`)
- **Program Editor** — three tabs (Details / Plan / Phases) with plan_markdown versioning (`ProgramEditorView.swift:78-82`)
- **Generate practice (⚡)** — `POST /api/generate-practice` (`ProgramViewModel.swift:311-339`)
- **Assessment criteria flag columns** — all 9 flags present (`Evaluation.swift:25-63`)

---

## 1. Age category — birth-year rule fix (HIGH)

The current `Athlete.ageCategory` uses an **Aug 31 cutoff** with `dateComponents([.year], from: dob, to: cutoff)`. This under-counts by one for athletes born **Sept–Dec** versus the web rule (`competitionAge = seasonEndYear − birthYear`).

**Fix:** replace the date-math with integer math from `age-category-rule.md` §iOS section.

`Athlete.swift` — replace the body of `ageCategory` and `isYouthRestrictedCheckin` with:

```swift
private func competitionAge(for dob: Date, today: Date = Date()) -> Int {
    let cal = Calendar.current
    let month = cal.component(.month, from: today)         // 1-indexed
    let year  = cal.component(.year,  from: today)
    let seasonEndYear = month >= 9 ? year + 1 : year       // Sept–Dec → next year
    let birthYear = cal.component(.year, from: dob)
    return seasonEndYear - birthYear
}
```

Then bucket: `<11 U-11`, `11–12 U-13`, `13–14 U-15`, `15–16 U-17`, `17–18 U-19`, `==19 U-20`, `≥20 Adult`.

**Final-year flag** (`isFinalYear`) — true when `competitionAge ∈ {10, 12, 14, 16, 18, 19}`. Replace the `↑/↓` glyph fallback in `ageCategory` with this rule.

**Youth-restricted check-in** — keep the U11/U13 rule: `competitionAge < 13`.

**Verification cases** (today = 2026-04-30, seasonEndYear = 2026):

| DOB | Expected age | Category | Final year? |
|---|---|---|---|
| 2009-12-15 | 17 | U-19 | no |
| 2009-02-14 | 17 | U-19 | no |
| 2008-09-09 | 18 | U-19 | yes |
| 2007-06-01 | 19 | U-20 | yes |
| 2006-12-31 | 20 | Adult | n/a |

The 2009-12-15 case is the regression vs. current code; verify it lands in U-19.

---

## 2. Gym timezone (HIGH — touches everything below)

Web added `gyms.timezone text not null default 'UTC'`. iOS needs to read it, expose admin editing, and feed it into date formatting.

### 2a. Model + service

`Models/Gym.swift` — add `timezone: String` (decode missing/null as `"UTC"`).

`Services/SupabaseClient.swift` (or a new `GymService`) — fetch the current coach's gym timezone once on session start, cache it on `AuthViewModel` (or a new `GymContext` env object) so all date formatting can read it synchronously.

```swift
@Published var gymTimezone: String = "UTC"
```

### 2b. Admin picker in Settings

`SettingsView` → add a new "General" section above Programs (admin-only). Use a `Picker` populated from `TimeZone.knownTimeZoneIdentifiers`. Optimistic save: PATCH `gyms.timezone` and update `AuthViewModel.gymTimezone` on success.

Gate visibility on `coach.role == "admin"`.

### 2c. Migration

`alter table gyms add column if not exists timezone text not null default 'UTC';` — run once per environment if not already applied via web rollout.

---

## 3. Date formatting convention (HIGH)

Two distinct rules. Diverging from these causes off-by-one days for non-UTC viewers.

### `date` columns — format in **UTC**

Columns: `athletes.dob`, `workouts.workout_date`, `workouts.planned_for`,
`competition_results.competition_date`, `evaluations.evaluated_at`,
`athlete_programs.enrolled_at`.

### `timestamptz` columns — format in **gym timezone**

Columns: every `*_at` instant — `created_at`, `assessed_at`,
`maxes_updated_at`, `acknowledged_at`, `resolved_at`, etc.

### Implementation

`String+Date.swift` — extend with two helpers:

```swift
extension String {
    /// Format a `date` column (e.g. "2026-04-30") in UTC.
    func formattedDate(_ style: DateFormatter.Style = .medium) -> String { ... }

    /// Format a `timestamptz` instant in the gym's timezone.
    func formattedTime(in tz: String, _ style: DateFormatter.Style = .short) -> String { ... }
}
```

Both helpers should set `formatter.timeZone = TimeZone(identifier: tz) ?? .gmt`.

Then sweep all call sites and replace ad-hoc formatting with these helpers, passing `authVM.gymTimezone` for instants. Concrete files to update: `AthleteDetailView`, `AthleteWorkoutHistoryView`, `AthleteAssessmentDetailView`, `EvaluationHistoryView`, `CriteriaHistoryView`, `AthleteCompetitionsView`, `AthleteNotesView`, `AlertDashboardView`.

---

## 4. Athlete-page alerts — also filter acknowledged (MEDIUM)

The athlete profile must hide alerts that have been acknowledged but not yet resolved. The gym-wide dashboard keeps showing them.

`AthleteAssessmentViewModel.swift:42` (or wherever the per-athlete alert query lives) — add `.is("acknowledged_at", value: nil)` alongside the existing `resolved_at IS NULL` filter:

```swift
.from("athlete_alerts")
.select("*")
.eq("athlete_id", value: athleteId)
.is("resolved_at", value: nil)
.is("acknowledged_at", value: nil)
.order("created_at", ascending: false)
```

`AlertDashboardViewModel.swift:20` — leave as-is (already correct: filters only `resolved_at IS NULL`, no acknowledged filter).

---

## 5. Gym-wide alert dashboard view (MEDIUM)

The `AlertDashboardViewModel` exists and works, but there is no surface that renders it. Add a dashboard view.

**Suggested placement:** new "Dashboard" tab as the first tab in `MainTabView`, OR a section at the top of `AthletesView` ("Active Alerts" header, hidden when empty).

Each row: severity icon + alert type + athlete name (deep-link to `AthleteDetailView`) + message + Acknowledge + Resolve buttons. Show critical and warn only (info suppressed at gym level).

---

## 6. Phase types (MEDIUM)

`program_phases.phase_type` is a nullable text column constrained to nine values. iOS currently uses free-text `name`.

### 6a. Model

`Models/ProgramPhase.swift` — add `phaseType: String?` and a Swift enum:

```swift
enum PhaseType: String, CaseIterable, Identifiable {
    case base, skills, strength, power
    case powerEndurance = "power_endurance"
    case competition, peak, transition, deload

    var id: String { rawValue }
    var label: String {
        switch self {
        case .base: "Base"; case .skills: "Skills"; case .strength: "Strength"
        case .power: "Power"; case .powerEndurance: "Power Endurance"
        case .competition: "Competition"; case .peak: "Peak"
        case .transition: "Transition"; case .deload: "Deload"
        }
    }
}
```

### 6b. Display

Wherever a phase name is rendered (program detail, current-phase chip on athlete cards, workout header):

```swift
let displayName = phase.phaseType
    .flatMap { PhaseType(rawValue: $0)?.label }
    ?? phase.name
```

A small chip/badge alongside the week-range label is the web pattern.

`is_deload` stays the source of truth for the deload badge — independent of `phase_type`.

### 6c. Phase creation

`ProgramEditorView` Phases tab — replace the free-text name `TextField` with a `Picker(.menu)` over `PhaseType.allCases` (plus a "Select…" placeholder). On insert, set both `phase_type` and `name = type.label` for backward compatibility with older clients reading `name`.

### 6d. Null handling

Phases created before this migration have `phase_type = null`; the fallback to `phase.name` handles them. Don't crash if `name` is also null — show "Phase \(startWeek)–\(endWeek)".

---

## 7. AI note version history (LOW)

New table `ai_note_versions` archives each AI note before replacement.

| column | description |
|---|---|
| `athlete_id` | FK |
| `version_num` | per-athlete incrementing int |
| `content` | archived note text |
| `model` | model that produced it |
| `prompt_version` | prompt version at generation time |
| `created_at` | when archived (i.e., replaced) |

### iOS work

1. New model `Models/AINoteVersion.swift` (struct, snake_case `CodingKeys`).
2. Add a method to `NoteViewModel` (or new `AINoteHistoryViewModel`):
   ```swift
   supabase.from("ai_note_versions")
     .select("version_num, content, model, created_at")
     .eq("athlete_id", value: athleteId)
     .order("version_num", ascending: false)
     .limit(20)
   ```
3. UI: a "Note History" disclosure or sheet anchored on the AI assessment / AI note view in `AthleteDetailView`. Row format:
   ```
   Nov 3                          Sonnet 4.6
   Athlete showed improved finger comfort…
   ```
   Tap to expand to full text.

**Priority:** low — web hasn't shipped this either; the data accumulates regardless.

---

## 8. Background reassessment trigger (LOW)

When (and only when) the app re-enters foreground or pulls to refresh, trigger `assess-athlete` (force=false) for an athlete if any of these were created **after** the last assessment's `assessed_at`:

- `notes` row with `category != 'ai'`
- `evaluations` row
- `competition_results` row

Workout rows alone do **not** trigger reassessment.

Implementation sketch: in `AthleteAssessmentViewModel.refresh()`, after fetching the latest assessment, run a count query against each of the three tables filtered by `created_at > assessed_at` and call `reassess(force: false)` if any return ≥ 1.

The reassess call is already idempotent server-side (18-hour cache), so triggering eagerly is safe.

---

## 9. `tags.is_system` flag (LOW)

`tags` table gained `is_system boolean`. System tags have `gym_id IS NULL` and appear for all gyms read-only.

`Models/Tag.swift` — add `isSystem: Bool` (decode missing as false).

In tag-management UI (Settings or wherever tags are CRUD'd), hide the delete swipe action and disable the rename field when `tag.isSystem == true`. Tag-selection UI continues to show system tags alongside gym tags as before.

---

## 10. Migrations to run (operational)

```sql
-- Covered by web rollouts; idempotent if re-run:
alter table gyms add column if not exists timezone text not null default 'UTC';
alter table coaches add column if not exists unit_preference text not null default 'metric'
  check (unit_preference in ('metric','imperial'));
alter table athletes add column if not exists reach_cm numeric;
alter table assessment_criteria add column if not exists is_reach boolean not null default false;
```

No iOS-only migrations.

---

## 11. Unit preference (metric/imperial) + reach (HIGH)

Source: web commit `6880ba4` (2026-05-01). Not covered by any of the five design docs but shipped to web. Storage stays metric throughout — conversion happens **only at the UI boundary**.

### 11a. Schema additions (already migrated server-side)

- `coaches.unit_preference text not null default 'metric' check (in 'metric','imperial')`
- `athletes.reach_cm numeric`
- `assessment_criteria.is_reach boolean not null default false`
- A "Reach" criterion is auto-seeded for every gym (`unit = 'cm'`, `is_reach = true`)
- Eval-sync trigger now branches on `is_reach` and writes to `athletes.reach_cm`

### 11b. iOS models

`Models/Coach.swift` — add `unitPreference: String` (default `"metric"`, decode missing as `"metric"`).

`Models/Athlete.swift` — add `reachCm: Double?` (CodingKey `reach_cm`).

`Models/Evaluation.swift` (criteria struct) — add `isReach: Bool` alongside the existing 9 flags.

### 11c. Unit context

New `Services/UnitSystem.swift` (or extend `AuthViewModel`):

```swift
enum UnitSystem: String { case metric, imperial }

@MainActor
final class UnitContext: ObservableObject {
    @Published var system: UnitSystem = .metric

    func setSystem(_ next: UnitSystem, coachId: String) async {
        system = next
        try? await SupabaseService.shared.supabase
            .from("coaches")
            .update(["unit_preference": next.rawValue])
            .eq("id", value: coachId)
            .execute()
    }
}
```

Inject as `@EnvironmentObject` in `ClimberProject_iOSApp`, hydrate from `coach.unitPreference` after `checkSession()`. Optimistic update — UI flips immediately, persistence is fire-and-forget.

### 11d. Conversion helpers

New `Services/Units.swift` mirroring the web `units.js`:

```swift
enum Units {
    static let cmPerIn = 2.54
    static let kgPerLb = 0.45359237

    static func cmToIn(_ cm: Double) -> Double { cm / cmPerIn }
    static func inToCm(_ inches: Double) -> Double { inches * cmPerIn }
    static func kgToLb(_ kg: Double) -> Double { kg / kgPerLb }
    static func lbToKg(_ lb: Double) -> Double { lb * kgPerLb }

    static func formatLength(_ cm: Double?, system: UnitSystem) -> String {
        guard let cm else { return "—" }
        return system == .imperial
            ? String(format: "%.1f in", cmToIn(cm))
            : String(format: "%.1f cm", cm)
    }

    static func formatWeight(_ kg: Double?, system: UnitSystem) -> String {
        guard let kg else { return "—" }
        return system == .imperial
            ? String(format: "%.1f lb", kgToLb(kg))
            : String(format: "%.1f kg", kg)
    }

    static func isLengthCriterion(_ c: AssessmentCriteria) -> Bool {
        c.isHeight || c.isWingspan || c.isReach
    }
    static func isWeightCriterion(_ c: AssessmentCriteria) -> Bool { c.isWeight }

    /// Convert a stored metric value into the value to display in the input field.
    static func displayValue(_ stored: Double, criterion: AssessmentCriteria, system: UnitSystem) -> Double {
        guard system == .imperial else { return stored }
        if isLengthCriterion(criterion) { return cmToIn(stored) }
        if isWeightCriterion(criterion) { return kgToLb(stored) }
        return stored
    }

    /// Convert an input-field value back to the metric value to persist.
    static func parseInput(_ input: Double, criterion: AssessmentCriteria, system: UnitSystem) -> Double {
        guard system == .imperial else { return input }
        if isLengthCriterion(criterion) { return inToCm(input) }
        if isWeightCriterion(criterion) { return lbToKg(input) }
        return input
    }

    static func unitSuffix(for criterion: AssessmentCriteria, system: UnitSystem) -> String {
        if system == .imperial {
            if isLengthCriterion(criterion) { return "in" }
            if isWeightCriterion(criterion) { return "lb" }
        }
        return criterion.unit ?? ""
    }
}
```

### 11e. Settings toggle

`SettingsView` → add a "Units" section (above or alongside the new "General" timezone section from §2b):

```swift
Picker("Measurement units", selection: $unitContext.system) {
    Text("Metric (cm, kg)").tag(UnitSystem.metric)
    Text("Imperial (in, lb)").tag(UnitSystem.imperial)
}
.onChange(of: unitContext.system) { _, new in
    Task { await unitContext.setSystem(new, coachId: authVM.coachId) }
}
```

Available to all coaches (per-coach preference, not gym-scoped).

### 11f. Display + input call sites

Touch every place a height / weight / wingspan / reach value is shown or entered:

- **Athlete profile Physical card** (`AthleteDetailView`) — replace `"\(athlete.heightCm) cm"` style strings with `Units.formatLength(athlete.heightCm, system: unitContext.system)` etc. Add a new "Reach" row (only if `reachCm != nil`).
- **Morpho evaluation entry** (`AddEvaluationView`) — for any criterion where `isHeight || isWeight || isWingspan || isReach`:
  - Show `Units.unitSuffix(for:system:)` next to the input
  - Convert keystroke input via `Units.parseInput(...)` before persisting (so storage stays cm/kg)
  - When pre-filling an existing value, run it through `Units.displayValue(...)` first
- **Evaluation history** (`CriteriaHistoryView`) — apply the same display conversion when rendering rows for length/weight criteria.

Other criteria (max hang in kg, me-edge in mm, lockoff in seconds, etc.) keep their stored units regardless of preference. Only the four flagged length/weight criteria convert.

### 11g. Reach criterion

New "Reach" criterion is auto-seeded server-side. iOS work needed:

1. Surface "Reach" in the Morpho evaluation form alongside Height / Weight / Wingspan.
2. Show a "Reach" row in the Physical card on `AthleteDetailView` driven by `athlete.reachCm`.
3. The denormalisation is handled by the eval-sync trigger; iOS just needs to read `reach_cm`.

---

## 12. Inactive option in athletes program filter (LOW)

Source: web commit `88ce7ea`. The athlete list's program filter gained an "Inactive" option — athletes whose `athlete_programs` rows are all in the past (or who have no enrolment).

In `AthletesView` (or wherever the program filter lives), add an "Inactive" entry to the program selector. Selecting it filters to athletes with no currently-active enrolment. Define "active" the same way the web does — easiest path is a one-line check of the athlete's enrolments (`enrolled_at <= today AND (ended_at IS NULL OR ended_at >= today)`).

If the iOS list doesn't currently expose a program filter at all, this is a no-op until that filter ships.

---

## Suggested sequencing

1. **§1 age category fix** — small, isolated, fixes a real bug.
2. **§2 + §3 gym timezone + date formatting** — block of work; §3 depends on §2's plumbing.
3. **§4 athlete-page alert filter** — one-line change; do alongside §3's sweep.
4. **§11 unit preference + reach** — touches a similar set of files (Athlete model, AddEvaluationView, AthleteDetailView); batch with §3 if convenient.
5. **§5 gym dashboard view** — UI-only.
6. **§6 phase types** — model + picker + display swap.
7. **§7 AI note history** — when AthleteDetail has capacity.
8. **§8 background reassessment** — quality-of-life, not parity-blocking.
9. **§9 `tags.is_system`** — trivial; do whenever Tag model is next touched.
10. **§12 inactive filter** — only if/when the program filter exists in iOS.

Total estimated work: 1–2 days for §1–§5, 1 day for §6, 1 day for §11, half-day each for §7–§9, §12.
