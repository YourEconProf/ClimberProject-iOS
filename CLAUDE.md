# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ClimberProject iOS is a native SwiftUI app for climbing coaches to manage athletes, track evaluations (FM, Morpho, Strength), and view progress. It uses Supabase as the backend. The companion web app lives at https://github.com/YourEconProf/ClimberProject and shares the same Supabase instance and database schema (`supabase/migrations.sql` in that repo).

## Build & Run

This is an early-stage project without an .xcodeproj file yet. To set up:
1. Create a new Xcode App project (SwiftUI, Swift, product name `ClimberProject`, org `com.climbernation`)
2. Import the `.swift` source files into the target
3. Add the Supabase Swift SDK via File → Add Packages: `https://github.com/supabase-community/supabase-swift.git`
4. Configure `SUPABASE_URL` and `SUPABASE_ANON_KEY` in Info.plist or an `.xcconfig` file

**Requirements:** Xcode 15+, iOS 16+

No tests exist yet. No CI/CD pipeline is configured.

## Architecture

**MVVM with SwiftUI** — Models are plain `Codable`/`Identifiable` structs, ViewModels use `@Published` + `ObservableObject`, Views use `@StateObject`/`@EnvironmentObject`.

**Key flow:**
- `ClimberProject_iOSApp` calls `authVM.checkSession()` on launch via `.task`, then routes to `LoginView` or `MainTabView` based on `AuthViewModel.isLoggedIn`
- `MainTabView` is a `TabView` with four tabs: Athletes, Measurements, Evaluations, Settings — each wrapped in its own `NavigationStack`
- `AuthViewModel` is injected as `@EnvironmentObject` from the app root; loading/error state lives on the ViewModel, not in views

**Services layer:** `SupabaseService` (named to avoid collision with the SDK's own `SupabaseClient` type) is a singleton that will wrap all Supabase queries. Config values are read from Info.plist via `Config.swift`. Row Level Security (RLS) at the database layer enforces gym-scoped data access — the iOS app relies on this entirely.

**Signup flow note:** The web app uses a serverless `api/invite-coach.js` function for coach creation (coach rows are linked to `auth.users` by ID). The iOS signup must: (1) look up gym by `code`, (2) create the Supabase auth user, (3) insert into `coaches` with the returned auth UID as the primary key.

**Data models** (all in `Models/`, all snake_case→camelCase via `CodingKeys`):
- `Athlete` — includes `emergencyContacts: [EmergencyContact]?` (JSONB in DB)
- `Coach`, `Gym` — core identity
- `Measurement` — physical measurements (height, wingspan, grip strength, hangboard, etc.)
- `Evaluation`, `AssessmentCriteria` — custom gym criteria with `isFm`/`isMorpho`/`isStrength` flags
- `Note` — coach notes with `NoteCategory` enum; `isPrivate` notes visible only to author (or head_coach/admin)
- `Goal` — athlete goals with `GoalStatus` enum
- `Program`, `AthleteProgram` — training programs; `AthleteProgram` has a composite PK, synthesised `id` for SwiftUI
- `CompetitionResult`

## Current State

Most service methods and all feature views are TODO stubs. Auth (login/signup/logout/session), all `SupabaseService` query methods, and the four main tab views need implementation. The Supabase SDK dependency has not been integrated yet.
