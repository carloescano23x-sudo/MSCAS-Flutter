# MSCAS Phase 4 - Account Onboarding

Implemented:
- Admin single-user invitation instead of manually copying an Auth UUID.
- Admin CSV bulk invitations.
- Supabase Edge Function performs privileged invitation server-side.
- Invitation email redirects to MSCAS production web site.
- Invited user is marked `onboarding_pending` / `onboarding_required`.
- First visit after invitation opens the MSCAS password-setup screen.
- Password setup changes only the MSCAS/Supabase password, never Microsoft password.
- Microsoft OAuth remains available.

Deployment requirement:
1. Run `supabase/phase4_onboarding.sql` once in Supabase SQL Editor.
2. Deploy `supabase/functions/invite-student/index.ts` as Edge Function `invite-student`.
3. Keep https://mscas-attendance.netlify.app/** in Supabase Auth Redirect URLs.
4. Configure Supabase Auth email/SMTP settings for production-quality delivery.

Never put the Supabase service-role key in Flutter, Netlify client code, or the APK.
