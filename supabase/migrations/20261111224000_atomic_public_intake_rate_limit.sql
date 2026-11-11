-- Make public-intake rate limiting atomic under concurrent submissions.
-- The RPC is callable only by the server-side service role.
create or replace function public.consume_public_intake_rate_limit(
  p_intake_token uuid,
  p_fingerprint text,
  p_limit integer default 5
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_count integer;
begin
  if p_limit is null or p_limit < 1 or p_limit > 20
     or p_fingerprint is null or length(p_fingerprint) < 32 then
    raise exception 'Invalid rate-limit arguments';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_intake_token::text || ':' || p_fingerprint, 0)
  );

  select count(*)::integer
    into v_count
    from public.intake_rate_limits
   where intake_token = p_intake_token
     and fingerprint = p_fingerprint
     and created_at >= pg_catalog.now() - interval '10 minutes';

  if v_count >= p_limit then
    return false;
  end if;

  insert into public.intake_rate_limits (intake_token, fingerprint)
  values (p_intake_token, p_fingerprint);

  return true;
end;
$function$;

revoke all on function public.consume_public_intake_rate_limit(uuid, text, integer)
  from public, anon, authenticated;
grant execute on function public.consume_public_intake_rate_limit(uuid, text, integer)
  to service_role;
