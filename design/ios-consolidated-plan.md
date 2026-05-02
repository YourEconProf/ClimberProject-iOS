# iOS Consolidated Implementation Plan

**Date:** 2026-05-01
**Last updated:** 2026-05-01 — moved unit preference + reach into §0 (shipped in `4152e50`).
**Scope:** Single plan combining `ios-parity-plan.md`, `ios-feature-spec-2026-04-28.md`, `changes-2026-04-30.md`, `ios-2026-05-01.md`, `age-category-rule.md`, plus the metric/imperial + reach work shipped in web commit `6880ba4`.

This plan deduplicates the source design docs and reflects the current state of the iOS codebase. Items already shipped are listed in §0; the work remaining is in §1 onward, ordered by priority.

---

## 0. Already shipped (no action required)

These were specified across the source docs and have landed in iOS:

**From the original parity work and earlier feature specs:**
- **AI Reassess `force=true`** — `AthleteAssessmentViewModel.swift:100`
- **AI note category filtering** — `category != 'ai'` applied to note queries; `'ai'` excluded from category picker (`NoteViewModel.swift:22`, `Note.swift:23-29`)
- **Mental Performance Framework** — model, VM, view, RPC `save_mental_framework`, U17/U19 gating (`MentalFramework.swift`, `MentalFrameworkViewModel.swift:60`, `AthleteDetailView.swift:185`)
- **Athlete-page alerts** — unresolved alerts grouped by severity with acknowledge / resolve buttons (`AlertDashboardViewModel.swift`, `AthleteAssessmentViewModel.swift:42`)
- **Athlete edit form** — height/weight/wingspan inputs already removed (`AddAthleteView.swift`)
- **Check-ins** — `athlete_checkins` model + `CheckinModalView`, U11/U13 reduced fields via `isYouthRestrictedCheckin` (`Athlete.swift`)
- **Athlete denormalised columns** — `experience_level`, `phv_stage`, `full_crimp_ready`, `campus_ready`, `max_hang_kg`, etc. (`Athlete.swift:21-40`)
- **Workout status / planned_for + Approve button** — (`Workout.swift:12-13`, `AthleteWorkoutHistoryView.swift:35`)
- **Program Editor** — three tabs (Details / Plan / Phases) with plan_markdown versioning (`ProgramEditorView.swift:78-82`)
- **Generate practice (⚡)** — `POST /api/generate-practice` (`ProgramViewModel.swift:311-339`)
- **Assessment criteria flag columns** — all 9 flags present (`Evaluation.swift:25-63`)

**Shipped 2026-05-01 (commit `11d66c0`):**
- **Age category — birth-year rule fix** — `Athlete.swift` now uses USAC Youth Series birth-year math (`competitionAge = seasonEndYear − birthYear`). New `competitionAge` and `isFinalYear` properties; `isYouthRestrictedCheckin` tightened from `age < 14` to `competitionAge < 13` (was incorrectly including U-15 athletes).
- **Gym timezone plumbing** — `Gym.timezone` decoded (defaults to `"UTC"`); `AuthViewModel.currentGym` and `gymTimezone` exposed; `loadGym()` runs after `loadCoach()`. Settings has an admin-only `TimeZone` picker over `TimeZone.knownTimeZoneIdentifiers` with optimistic `updateGymTimezone(_:)`.
- **Date formatting convention** — `String+Date.swift` split into two rule sets. `displayDate` etc. format `date` columns in UTC. New `displayDate(in:)` / `displayDateTime(in:)` / `displayTime(in:)` format `timestamptz` instants in the gym's IANA timezone. Sweep covers: `AthleteDetailView` (note, assessment, maxesUpdatedAt), `AthleteAssessmentDetailView`, `AthleteNotesView`, `MentalFrameworkEditorView`, `ProgramEditorView`, `AthleteGoalsView`. Date columns (workout dates, eval dates, dob, competition dates, enrollment) left on UTC formatters.

**Shipped 2026-05-01 (commit `4152e50`):**
- **Unit preference (metric/imperial) + reach** — Storage stays metric. `Coach.unitPreference`, `Athlete.reachCm`, `AssessmentCriteria.isReach` added to models. New `Services/Units.swift` provides cm↔in / kg↔lb conversion plus `displayValue` / `parseInput` / `unitSuffix` helpers branching on the length flags (`isHeight`, `isWingspan`, `isReach`) and weight flag (`isWeight`). `UnitContext` ObservableObject hydrates from `coach.unitPreference` and patches the coaches row optimistically. Injected as `@EnvironmentObject` in app entry. Settings has a Units segmented picker. Sweep applied to: `AthleteDetailView` Physical card (with new Reach row), `AddEvaluationView` (input + suffix + parse), `CriteriaHistoryView`, `EvaluationHistoryView` (including chart Y axis), `AthleteEvaluationsView`. Other criteria (max hang, pull-up load, me-edge, lockoff) keep their stored units.

---

## 1. Athlete-page alerts — also filter acknowledged (MEDIUM)

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

## 2. Gym-wide alert dashboard view (MEDIUM)

The `AlertDashboardViewModel` exists and works, but there is no surface that renders it. Add a dashboard view.

**Suggested placement:** new "Dashboard" tab as the first tab in `MainTabView`, OR a section at the top of `AthletesView` ("Active Alerts" header, hidden when empty).

Each row: severity icon + alert type + athlete name (deep-link to `AthleteDetailView`) + message + Acknowledge + Resolve buttons. Show critical and warn only (info suppressed at gym level).

---

## 3. Phase types (MEDIUM)

`program_phases.phase_type` is a nullable text column constrained to nine values. iOS currently uses free-text `name`.

### 3a. Model

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

### 3b. Display

Wherever a phase name is rendered (program detail, current-phase chip on athlete cards, workout header):

```swift
let displayName = phase.phaseType
    .flatMap { PhaseType(rawValue: $0)?.label }
    ?? phase.name
```

A small chip/badge alongside the week-range label is the web pattern.

`is_deload` stays the source of truth for the deload badge — independent of `phase_type`.

### 3c. Phase creation

`ProgramEditorView` Phases tab — replace the free-text name `TextField` with a `Picker(.menu)` over `PhaseType.allCases` (plus a "Select…" placeholder). On insert, set both `phase_type` and `name = type.label` for backward compatibility with older clients reading `name`.

### 3d. Null handling

Phases created before this migration have `phase_type = null`; the fallback to `phase.name` handles them. Don't crash if `name` is also null — show "Phase \(startWeek)–\(endWeek)".

---

## 4. AI note version history (LOW)

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

## 5. Background reassessment trigger (LOW)

When (and only when) the app re-enters foreground or pulls to refresh, trigger `assess-athlete` (force=false) for an athlete if any of these were created **after** the last assessment's `assessed_at`:

- `notes` row with `category != 'ai'`
- `evaluations` row
- `competition_results` row

Workout rows alone do **not** trigger reassessment.

Implementation sketch: in `AthleteAssessmentViewModel.refresh()`, after fetching the latest assessment, run a count query against each of the three tables filtered by `created_at > assessed_at` and call `reassess(force: false)` if any return ≥ 1.

The reassess call is already idempotent server-side (18-hour cache), so triggering eagerly is safe.

---

## 6. `tags.is_system` flag (LOW)

`tags` table gained `is_system boolean`. System tags have `gym_id IS NULL` and appear for all gyms read-only.

`Models/Tag.swift` — add `isSystem: Bool` (decode missing as false).

In tag-management UI (Settings or wherever tags are CRUD'd), hide the delete swipe action and disable the rename field when `tag.isSystem == true`. Tag-selection UI continues to show system tags alongside gym tags as before.

---

## 7. Inactive option in athletes program filter (LOW)

Source: web commit `88ce7ea`. The athlete list's program filter gained an "Inactive" option — athletes whose `athlete_programs` rows are all in the past (or who have no enrolment).

In `AthletesView` (or wherever the program filter lives), add an "Inactive" entry to the program selector. Selecting it filters to athletes with no currently-active enrolment. Define "active" the same way the web does — easiest path is a one-line check of the athlete's enrolments (`enrolled_at <= today AND (ended_at IS NULL OR ended_at >= today)`).

If the iOS list doesn't currently expose a program filter at all, this is a no-op until that filter ships.

---

## 8. Migrations to run (operational)

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

## Suggested sequencing

1. **§1 athlete-page alert filter** — one-line query change.
2. **§2 gym dashboard view** — UI-only; the VM already exists.
3. **§3 phase types** — model + picker + display swap.
4. **§4 AI note history** — when AthleteDetail has capacity.
5. **§5 background reassessment** — quality-of-life, not parity-blocking.
6. **§6 `tags.is_system`** — trivial; do whenever Tag model is next touched.
7. **§7 inactive filter** — only if/when the program filter exists in iOS.

Total estimated work: half-day for §1 + §2, 1 day for §3, half-day each for §4–§7.
