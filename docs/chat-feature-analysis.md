# Chat Feature Analysis

## The Core Blocker: Athlete Auth

Athletes currently have no auth accounts — they're data records in the DB with no link to `auth.users`. Coaches log in; athletes don't exist as users at all. How you resolve this determines most of the scope.

### Option A — Add athlete auth accounts
Each athlete gets a Supabase auth user linked to their `athletes` row (same pattern as `coaches`). Full bidirectional chat. Biggest lift: schema migration, new RLS policies for athlete-scoped access, athlete login UI on web and iOS, invite/onboarding flow.

### Option B — Magic link / guest access
Coaches message athletes; athletes receive a link (email/SMS), click it to open a reply-only web view. No persistent athlete account. Avoids the auth overhaul but won't work natively in the iOS app.

### Option C — Coach-to-coach messaging only
Skip athlete auth entirely. Coaches at the same gym can message each other. Much smaller scope — coaches already have auth. Less useful as a feature though.

---

## If You Go With Option A (full chat)

**Backend (Supabase)**
- Add `conversations` and `messages` tables; RLS restricts to gym members
- Link `athletes` to `auth.users` (migration on existing data, or new athletes only)
- Supabase Realtime is already available — subscribe to the `messages` table; no extra infrastructure needed

**Web app**
- Chat UI component (thread list + message view)
- Supabase Realtime subscription via `supabase.channel()` for live updates
- Fits the existing hooks pattern cleanly

**iOS app**
- Chat views in SwiftUI
- Supabase Swift SDK has Realtime support, so live updates work
- **Push notifications are the hard part** — background alerts require APNs certificates, an Xcode entitlement, and a Supabase Edge Function to call the APNs API; multi-day effort, optional for v1

---

## Rough Effort Estimate

| Piece | Option C (coach only) | Option A (full) |
|---|---|---|
| Schema + RLS | 0.5 day | 1.5 days |
| Athlete auth/onboarding | — | 2–3 days |
| Web chat UI | 1–2 days | 1–2 days |
| iOS chat UI + Realtime | 1–2 days | 1–2 days |
| Push notifications | optional / hard | optional / hard |
| **Total (no push)** | **~3 days** | **~7–10 days** |

---

## Recommendation

If the primary users of the iOS app are coaches (which the current design implies), coach-to-coach messaging may cover 80% of the use case with a fraction of the work. Athlete auth can be added later.

**First decisions to make before starting:**
1. Option A, B, or C?
2. Are push notifications in scope for v1?
