-- MSCAS Phase 4: account onboarding support.
-- Safe to run once after the original schema/Phase 3 SQL.

create or replace function public.handle_new_mscas_user()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.users(id, data)
  values (
    new.id::text,
    jsonb_build_object(
      'email', coalesce(new.email,''),
      'first_name', coalesce(new.raw_user_meta_data->>'first_name',''),
      'last_name', coalesce(new.raw_user_meta_data->>'last_name',''),
      'role', coalesce(new.raw_user_meta_data->>'role','student'),
      'student_number', new.raw_user_meta_data->>'student_number',
      'course', new.raw_user_meta_data->>'course',
      'year_level', coalesce((new.raw_user_meta_data->>'year_level')::int, 1),
      'employee_number', new.raw_user_meta_data->>'employee_number',
      'department', new.raw_user_meta_data->>'department',
      'onboarding_pending', coalesce((new.raw_user_meta_data->>'onboarding_required')::boolean, false),
      'active', true,
      'created_at', now()
    )
  ) on conflict (id) do nothing;
  return new;
end;
$$;
