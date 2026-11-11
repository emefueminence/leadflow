-- Restore the server-only Supabase role privileges required by API handlers.
-- RLS remains enabled and continues to govern authenticated/anon requests.
-- The service-role key is used only in server-side API routes and is never
-- included in the browser bundle.
grant select, insert, update, delete on all tables in schema public to service_role;
grant usage, select, update on all sequences in schema public to service_role;
alter default privileges for role postgres in schema public
  grant select, insert, update, delete on tables to service_role;
alter default privileges for role postgres in schema public
  grant usage, select, update on sequences to service_role;
