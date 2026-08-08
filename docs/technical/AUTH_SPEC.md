# AUTH_SPEC.md — Accounts, Authentication & Authorization

## When to read

Read when implementing sign-in, signup, session storage, account migration, roles, RLS, social identity, or account deletion.

## 1. Core UX rule

Authentication is optional until the user requests online features.

```text
Open app
 ├─ Continue locally
 │   └─ recorder/history/analytics/replay/scoring
 └─ Sign in / create account
     └─ sync/social/rankings/Guardian
```

## 2. Provider

Use Supabase Auth rather than custom password/auth server logic unless architecture is explicitly changed.

Initial methods may include:

- email/password or email OTP/magic link;
- Google sign-in on Android;
- Apple sign-in later with iOS.

Phone/SMS auth is not MVP priority because it adds cost/abuse complexity.

## 3. Auth identity vs app profile

Treat Supabase auth identity separately from public application profile.

Concept:

```text
auth.users
   │
   └── profiles
        user_id (FK/PK)
        username
        display_name
        avatar_url
        visibility
        created_at
```

Do not duplicate password hashes or implement password tables.

## 4. Sessions

- store session material using secure platform-backed storage as supported by the auth SDK;
- never store plaintext passwords in preferences;
- support session refresh/revocation;
- log out locally and clear sensitive cached auth state appropriately.

## 5. Roles

Initial conceptual roles:

- user;
- moderator;
- admin.

Authorization role claims must reside in trusted/non-user-editable server-side metadata or tables. Do not trust user-editable profile fields for privilege.

## 6. RLS

Every exposed Supabase table containing user-owned private data requires Row Level Security and explicit policies.

Examples:

- user can read/write own profile-private fields;
- user can read own cloud trip summaries;
- public profile view exposes only public fields;
- leaderboard reads sanitized ranking view/table;
- Guardian connections readable only by involved authorized parties.

Frontend filtering is not security.

## 7. Local→account migration

When a local-only user signs in:

1. preserve local data;
2. ask whether eligible local summaries should sync;
3. associate local owner namespace with account safely;
4. make operation idempotent;
5. raw telemetry remains local unless a separate backup feature says otherwise.

## 8. Account deletion

Provide a path that:

- explains local vs cloud deletion;
- revokes Guardian relationships;
- removes cloud profile/social/ranking data according to policy;
- removes local session credentials;
- does not silently delete local trip history unless the user chooses it.

Exact behavior must be documented in UI.

## 9. Security controls

MVP:

- email verification as appropriate;
- password reset if passwords used;
- rate limits/provider protections;
- RLS;
- session revocation;
- secure credential storage;
- account deletion.

Future optional MFA can be added if useful.
