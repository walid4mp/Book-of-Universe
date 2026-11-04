# مكتبة الكون | Kawn Library

Flutter mobile foundation for a multilingual Arabic/French/English literary library, with a Node.js API for Render and Supabase Auth/Postgres as the managed backend.

## Included
- Flutter app with branded generated app icon asset and launcher-icon configuration.
- Email/password sign-up and sign-in, email confirmation screen, resend confirmation, password reset and password update flow.
- Google OAuth initiation through Supabase Auth.
- Reader/writer self-selection. Committee roles are deliberately not self-selectable; they must be granted by trusted administration.
- Profile-based route gating and SQL Row Level Security policies for manuscripts and committee assignments.
- Node.js Express health API, Render Blueprint, GitHub CI workflows and initial SQL schema.

## Required external setup
Authentication cannot work against a real account until you configure Supabase URL/key, email confirmation/SMTP, Google OAuth credentials, and mobile deep links. See `docs/AUTH_SETUP_AR.md` and `docs/DEPLOYMENT_AR.md`.

## Flutter setup
```bash
cd flutter_app
flutter create --platforms=android,ios --org com.kawn.library .
flutter pub get
dart run flutter_launcher_icons
flutter analyze
flutter test
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
```

## Backend / Render
```bash
cd backend
npm install
npm run check
npm start
```

Deploy `render.yaml` through Render Blueprint. Set `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` as Render secrets only. Never expose the service-role key in Flutter, GitHub source, or public build arguments.

## Security model
- New profiles are created by a database trigger. Client signup metadata can request only `reader` or `writer`.
- Client SQL privileges do not permit changing `profiles.role`.
- Committee roles require a trusted administrative action.
- RLS restricts private manuscripts and review records to their owners/assigned reviewers.

## Verification status
This archive is a configured source package, not a deployed service or a signed store release. A Flutter SDK, Supabase project credentials, Google OAuth setup, SMTP configuration, and device-level callback tests are required to complete end-to-end verification. The included CI workflow performs Flutter analysis/tests and Android APK build when run in GitHub Actions.
