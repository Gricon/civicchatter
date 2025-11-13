-- backfill_profiles.sql
--
-- Backfill public/private profiles and debate pages for existing auth.users
-- that do not yet have corresponding rows in public.profiles_public.
-- Run in the Supabase SQL editor.

-- This script is conservative: it inserts rows only when the profiles_public
-- row does not already exist for the auth user id.

with users_to_add as (
  select
    u.id,
    u.email,
    (u.raw_user_meta_data->>'full_name')::text as raw_name
  from auth.users u
  left join public.profiles_public p on p.id = u.id
  where p.id is null
)
-- Insert public profiles
insert into public.profiles_public (id, handle, display_name, bio, city, avatar_url, is_private, is_searchable)
select
  id,
  -- generate a basic handle: email localpart or 'user' with short suffix
  lower(regexp_replace(coalesce(nullif(raw_name, ''), split_part(email, '@', 1), 'user'), '[^a-z0-9_-]', '', 'g')) ||
    case when exists(select 1 from public.profiles_public p2 where p2.handle = lower(regexp_replace(coalesce(nullif(raw_name, ''), split_part(email, '@', 1), 'user'), '[^a-z0-9_-]', '', 'g'))) then '_' || substr(md5(id::text), 1, 6) else '' end as handle,
  coalesce(nullif(raw_name, ''), email) as display_name,
  null as bio,
  null as city,
  null as avatar_url,
  false as is_private,
  true as is_searchable
from users_to_add;

-- Insert private profiles for those users (if missing)
insert into public.profiles_private (id, email, phone, address, preferred_contact)
select id, email, null, null, 'email'
from users_to_add
on conflict (id) do nothing;

-- Insert debate pages for those users (if missing)
insert into public.debate_pages (id, handle, title, description)
select p.id, p.handle, coalesce(p.display_name, p.handle) || '''s Debates', 'Debate topics and positions.'
from public.profiles_public p
left join public.debate_pages d on d.id = p.id
where d.id is null;

-- End of backfill_profiles.sql
