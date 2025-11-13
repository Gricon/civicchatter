-- add_site_settings_column.sql
--
-- Adds a JSONB column `site_settings` to `public.profiles_private` to store
-- per-user site preferences (font size, background, writing mode, etc.).
-- Run this in the Supabase SQL editor (admin/service_role permissions required).

alter table if exists public.profiles_private
  add column if not exists site_settings jsonb;

-- Optionally initialize existing rows with an empty object
-- update public.profiles_private set site_settings = '{}' where site_settings is null;

-- End of add_site_settings_column.sql
