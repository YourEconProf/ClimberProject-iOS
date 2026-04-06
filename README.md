# ClimberProject iOS

Native iOS app for the Climber Project, built with SwiftUI and Supabase.

## Overview

Coaches can manage athletes, track evaluations (FM, Morpho, Strength), record measurements, and view athlete progress on their gym's data.

**Stack:**
- SwiftUI + iOS 16+
- Supabase Swift SDK
- Native authentication

## Setup

### Requirements
- Xcode 15+
- iOS 16+

### Environment Variables

Copy `.env.example` to `.env` in the project root:

```
SUPABASE_URL=<your-supabase-url>
SUPABASE_ANON_KEY=<your-anon-key>
```

These are the same as the web app's public keys.

### Installation

```bash
# Open in Xcode
open ClimberProject-iOS.xcodeproj
```

Then run on simulator or device.

## Architecture

**Auth:** Supabase Auth with password-based login and magic links. Auth state managed via an `AuthViewModel`.

**Data:** Direct queries to Supabase Postgres via `supabase-swift` SDK. Row Level Security (RLS) enforces gym-scoped access at the database layer.

**Navigation:** SwiftUI TabView with sections for Athletes, Evaluations, Measurements, etc.

## Related

- **Web app:** https://github.com/YourEconProf/ClimberProject
- **Database schema:** See web repo's `supabase/migrations.sql`
