# MSCAS Supabase setup (testing)

Project URL and publishable client key are already configured in `lib/main.dart`.

## 1. Create the database
Open Supabase Dashboard > SQL Editor, paste the complete contents of `supabase/schema.sql`, then Run.

## 2. Authentication
In Authentication > Providers:
- Email: enable for MSCAS email/password testing.
- Azure (Microsoft): enable after creating the Microsoft Entra application.

For Azure, use this callback in Microsoft Entra:
`https://gcpgxrixfslrrooogvef.supabase.co/auth/v1/callback`

In Supabase Authentication > URL Configuration add mobile redirect:
`mscas://login-callback/`

Also add the deployed web URL as an allowed redirect URL before web testing.

## 3. Microsoft test account role
The first Microsoft sign-in creates a safe default `student` MSCAS profile. If the test account must test the instructor web portal, after signing in once run this in SQL Editor, replacing the email:

```sql
update public.users
set data = jsonb_set(data, '{role}', '"instructor"'::jsonb, true)
where lower(data->>'email') = lower('YOUR_TEST_MICROSOFT_EMAIL');
```

For an admin test account, replace `instructor` with `admin`.

## 4. Existing Firebase data
This package changes the live application backend to Supabase. Existing Firestore records are NOT automatically copied. Create test users/classes in Supabase/MSCAS for QA, or migrate the old data separately before production.

## 5. Commands
From the project root:

```powershell
flutter pub get
flutter analyze
flutter run -d chrome
```

Do not deploy until `flutter analyze` and the required QA flows pass.
