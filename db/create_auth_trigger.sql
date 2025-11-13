-- create_auth_trigger.sql
--
-- Creates a Postgres trigger that runs after a new row is inserted into
-- the auth.users table. The trigger creates three rows for the new user:
--  - public.profiles_public
--  - public.profiles_private
--  - public.debate_pages
--
-- Run this in the Supabase SQL editor (or psql with a service_role key
-- / an account that can create triggers on auth.users).

-- Note: customize the handle-generation logic to suit your naming policy.

create or replace function public.handle_new_auth_user()
returns trigger as $$
declare
  u_email text := new.email;
  display_name text := NULL;
  handle_base text;
  new_handle text;
  suffix int := 0;
begin
  -- Attempt to get a display name from raw_user_meta_data (if present)
  begin
    display_name := (new.raw_user_meta_data->>'full_name')::text;
  exception when others then
    display_name := null;
  end;

  -- Build a safe handle base: prefer display_name, then email localpart, else 'user'
  if display_name is not null and length(trim(display_name)) > 0 then
    handle_base := lower(regexp_replace(display_name, '[^a-z0-9_-]', '', 'g'));
  elsif u_email is not null then
    handle_base := lower(regexp_replace(split_part(u_email, '@', 1), '[^a-z0-9_-]', '', 'g'));
  else
    handle_base := 'user';
  end if;

  if handle_base = '' then
    handle_base := 'user';
  end if;

  new_handle := handle_base;
  -- Ensure handle uniqueness by appending a suffix if needed
  while exists (select 1 from public.profiles_public where handle = new_handle) loop
    suffix := suffix + 1;
    new_handle := handle_base || '_' || suffix;
  end loop;

  -- Insert public profile
  insert into public.profiles_public (
    id, handle, display_name, bio, city, avatar_url, is_private, is_searchable
  ) values (
    new.id,
    new_handle,
    coalesce(display_name, new.email),
    null,
    null,
    null,
    false,
    true
  ) on conflict (id) do nothing;

  -- Insert private profile
  insert into public.profiles_private (
    id, email, phone, address, preferred_contact
  ) values (
    new.id,
    new.email,
    null,
    null,
    'email'
  ) on conflict (id) do nothing;

  -- Insert debate page
  insert into public.debate_pages (
    id, handle, title, description
  ) values (
    new.id,
    new_handle,
    -- Use standard SQL escaping for the apostrophe: '''s Debates represents "'s Debates"
    coalesce(display_name, new_handle) || '''s Debates',
    'Debate topics and positions.'
  ) on conflict (id) do nothing;

  return new;
end;
$$ language plpgsql security definer;

-- Create the trigger on auth.users
-- You may need to run both statements in the same SQL execution block in Supabase.

create trigger auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_auth_user();

-- End of create_auth_trigger.sql
