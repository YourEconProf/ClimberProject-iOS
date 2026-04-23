# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ClimberProject iOS is a native SwiftUI app for climbing coaches to manage athletes, track workouts, log evaluations, and view progress. It uses Supabase as the backend. The companion web app lives at https://github.com/YourEconProf/ClimberProject and shares the same Supabase instance.

## Build & Run

Open `ClimberProject.xcodeproj` in Xcode 16+. The project uses `PBXFileSystemSynchronizedRootGroup` — any `.swift` file placed under `ClimberProject/` is automatically included in the target; no manual target membership step is needed.

The Supabase Swift SDK is added via Swift Package Manager. `SUPABASE_URL` and `SUPABASE_ANON_KEY` are configured in Info.plist via `Config.swift`.

**Requirements:** Xcode 16+, iOS 16+. No tests, no CI.

## Architecture

**MVVM with SwiftUI** — Models are plain `Codable`/`Identifiable` structs; ViewModels are `@MainActor ObservableObject` classes with `@Published` state; Views use `@StateObject` for locally-owned VMs and `@EnvironmentObject` for `AuthViewModel`.

**App entry:** `ClimberProject_iOSApp` injects `AuthViewModel` as an environment object and calls `authVM.checkSession()` on launch. `MainTabView` renders four tabs: Athletes, Workouts, Evaluations, Settings — each in its own `NavigationStack`.

**Services:** `SupabaseService` is a singleton wrapping the Supabase client (named to avoid collision with the SDK's `SupabaseClient` type). All DB calls go through it. RLS at the DB layer enforces gym-scoped access; the app trusts this entirely.

**Signup flow:** (1) look up gym by `code`, (2) create Supabase auth user, (3) insert into `coaches` with the returned auth UID as the primary key.

## Key Data Models

All models are in `Models/`, using `CodingKeys` for snake_case→camelCase mapping.

- **`Workout`** — has `athleteId: String?` (nil = template), `gymId: String?`, `name: String?` (athlete workouts), `templateName: String?` (gym templates). `isTemplate` = `athleteId == nil && gymId != nil`. `displayTitle` prefers `templateName ?? name`.
- **`WorkoutSet`** — `setTypeId`, `repeatCount`, `roundsCount`; nests `set_types(name)` and `workout_set_exercises(*, exercises(name))` via a single deep select.
- **`WorkoutSetExercise`** — `difficultyRounds: [String]?` and `repsRounds: [String]?` hold per-round values; scalar `difficulty`/`reps` mirror round-1 for legacy compatibility. Use `effectiveDifficulties(roundsCount:)` and `effectiveReps(roundsCount:)` to get correctly-sized arrays.
- **`Exercise`** — `id`, `gymId`, `name`; gym-scoped.
- **`AssessmentCriteria`** — `isFm`, `isMorpho`, `isStrength` flags control which evaluation entry forms show this criterion.
- **`Evaluation`** — one row per `(athleteId, criteriaId, evaluatedAt)`; `value: Double`.

## Workout System Details

**Draft types** (`DraftSet`, `DraftExercise` in `WorkoutViewModel.swift`) are used only by the Add/Edit form. Each `DraftExercise.difficulties` and `.reps` array is sized to `set.roundsCount`; when the stepper changes, arrays are resized in lockstep.

**Two workout modes:**
- `.athlete(id:)` — saves with `athlete_id`, stores name in `name` column
- `.template(gymId:)` — saves with `gym_id`, stores name in `template_name` column

**Flash token autocomplete:** When creating an athlete workout, typing a name shows matching named workouts as suggestions. Tapping one loads its sets; the name field shows "Sets loaded from: X" caption and stays populated with the template name.

**Name uniqueness** is enforced only for templates (case-insensitive `ilike` on `template_name`). Athlete workouts allow duplicate names.

**PDF:** `WorkoutPDFRenderer` uses `ImageRenderer` + `CGContext` to produce a US Letter PDF from `WorkoutPrintView`. The `sharePDF()` function must be `@MainActor`. `IdentifiableURL` (in `WorkoutPreviewView.swift`) wraps `URL` for `.sheet(item:)` use.

## Evaluation System Details

**Entry modes** (`EvaluationAddMode`): `.fm`, `.morpho`, `.strength` show only criteria with the matching flag. `.custom` shows a picker over all criteria. Each saves one `Evaluation` row per criteria with `value: Double`.

**Display:** `CriteriaHistoryView` renders a per-criteria timeline. `AthleteDetailView` groups criteria by flag into FM / Morpho / Strength sections, each linking to `CriteriaHistoryView`. `formatValue(_:unit:)` applies the unit suffix (or "—" for nil).

**Criteria CRUD** is in `EvaluationViewModel`. Flag toggles (`toggleFlag(_:for:)`) patch a single boolean column and re-fetch.

## Settings Structure

`SettingsView` manages five sections via their own VMs/methods: Programs (`ProgramViewModel`), Assessment Criteria (`EvaluationViewModel`), Set Types (`SetTypeViewModel`), Exercises (`WorkoutViewModel.addExercise/deleteExercise`), Appearance. Uses a single `@FocusState` enum to dismiss the keyboard across all add fields.

## Common Patterns

- **Delete guards:** PostgREST FK violations return a `23503` Postgres error code. Catch these and map to a readable `WorkoutVMError` case (see `.setTypeInUse`, `.exerciseInUse`).
- **Swipe-to-delete with error display:** `onDelete` runs a `Task`, catches errors, writes to a section-local `@State` error string shown inline — not in a separate alert.
- **Type-check complexity:** If SwiftUI reports "type-check too complex", extract nested `ForEach` bodies into dedicated private sub-views (see `LibrarySetRow`, `LibraryExerciseRow` in `WorkoutsLibraryView.swift`).
