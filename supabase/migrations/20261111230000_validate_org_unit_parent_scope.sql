-- Keep organizational hierarchy inside one tenant and reject parent cycles.
create or replace function private.validate_org_unit_parent()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_parent_org uuid;
  v_cycle boolean;
begin
  if new.parent_id is null then
    return new;
  end if;

  select organization_id
    into v_parent_org
    from public.org_units
   where id = new.parent_id;

  if v_parent_org is null or v_parent_org <> new.organization_id then
    raise exception 'Parent organizational unit must belong to the same workspace';
  end if;

  with recursive ancestors(id, parent_id) as (
    select id, parent_id
      from public.org_units
     where id = new.parent_id
       and organization_id = new.organization_id
    union all
    select parent.id, parent.parent_id
      from public.org_units parent
      join ancestors child on parent.id = child.parent_id
     where parent.organization_id = new.organization_id
  )
  select exists(select 1 from ancestors where id = new.id)
    into v_cycle;

  if v_cycle then
    raise exception 'Organizational units cannot be nested beneath their own descendants';
  end if;

  return new;
end;
$function$;

revoke all on function private.validate_org_unit_parent() from public, anon, authenticated;
drop trigger if exists org_units_validate_parent_scope on public.org_units;
create trigger org_units_validate_parent_scope
before insert or update of parent_id, organization_id
on public.org_units
for each row execute function private.validate_org_unit_parent();
