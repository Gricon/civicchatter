-- create_trigger_error_table.sql
-- Creates a small admin schema & table for logging trigger errors raised
-- by database trigger functions. Run this in the Supabase SQL editor as an
-- admin (service role) and choose "No limit" for the query results when
-- executing DDL. Ensure each statement ends with a semicolon.

create schema if not exists admin;

-- Table to capture errors raised inside trigger functions so we can inspect
-- the exact Postgres error that caused signups to fail.
create table if not exists admin.trigger_errors (
  id bigserial primary key,
  created_at timestamptz not null default now(),
  auth_uid uuid null,
  source_table text null,
  function_name text null,
  error_message text null,
  payload jsonb null
);

-- Lightweight helper function to insert an error row from trigger code.
-- It intentionally swallows any error on insert to avoid cascading failures
-- from error-logging itself.
create or replace function admin.log_trigger_error(
  p_auth_uid uuid,
  p_source_table text,
  p_function_name text,
  p_error_message text,
  p_payload jsonb
)
returns void
language plpgsql
as $$
begin
  insert into admin.trigger_errors (auth_uid, source_table, function_name, error_message, payload)
  values (p_auth_uid, p_source_table, p_function_name, p_error_message, p_payload);
exception when others then
  -- swallow any errors to avoid making the original problem worse
  perform 1;
end;
$$;

-- Optional: index to make recent lookups fast
create index if not exists trigger_errors_created_idx on admin.trigger_errors (created_at desc);

-- Example usage (run from within another function):
-- PERFORM admin.log_trigger_error(current_setting('jwt.claims', true)::uuid, 'profiles_private', 'handle_new_auth_user', SQLERRM, json_build_object('payload', row_to_json(NEW))::jsonb);

-- End of file
