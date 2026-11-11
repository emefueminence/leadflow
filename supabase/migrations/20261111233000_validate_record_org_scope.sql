-- Enforce same-workspace organizational and team references at the database boundary.
create or replace function private.validate_record_org_scope()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_org uuid;
  v_unit uuid;
  v_team uuid;
  v_team_org uuid;
  v_team_unit uuid;
  v_scope text;
begin
  v_org := (to_jsonb(new)->>'organization_id')::uuid;
  v_unit := nullif(to_jsonb(new)->>'org_unit_id','')::uuid;
  v_team := nullif(to_jsonb(new)->>'team_id','')::uuid;
  v_scope := to_jsonb(new)->>'access_scope';

  if v_unit is not null and not exists (
    select 1 from public.org_units u
     where u.id = v_unit and u.organization_id = v_org
  ) then
    raise exception 'Organizational unit must belong to the same workspace';
  end if;

  if v_team is not null then
    select t.organization_id, t.org_unit_id
      into v_team_org, v_team_unit
      from public.teams t
     where t.id = v_team;

    if not found or v_team_org <> v_org then
      raise exception 'Team must belong to the same workspace';
    end if;

    if v_unit is not null and v_team_unit is not null and v_unit <> v_team_unit then
      raise exception 'Selected team must belong to the selected organizational unit';
    end if;
  end if;

  if v_scope = 'unit' and v_unit is null then
    raise exception 'Unit-scoped membership requires an organizational unit';
  end if;
  if v_scope = 'team' and v_team is null then
    raise exception 'Team-scoped membership requires a team';
  end if;

  return new;
end;
$function$;

revoke all on function private.validate_record_org_scope() from public, anon, authenticated;

drop trigger if exists teams_validate_record_org_scope on public.teams;
create trigger teams_validate_record_org_scope
before insert or update on public.teams
for each row execute function private.validate_record_org_scope();

drop trigger if exists team_memberships_validate_record_org_scope on public.team_memberships;
create trigger team_memberships_validate_record_org_scope
before insert or update on public.team_memberships
for each row execute function private.validate_record_org_scope();

drop trigger if exists org_memberships_validate_record_org_scope on public.org_memberships;
create trigger org_memberships_validate_record_org_scope
before insert or update on public.org_memberships
for each row execute function private.validate_record_org_scope();

drop trigger if exists leads_validate_record_org_scope on public.leads;
create trigger leads_validate_record_org_scope
before insert or update on public.leads
for each row execute function private.validate_record_org_scope();

drop trigger if exists contacts_validate_record_org_scope on public.contacts;
create trigger contacts_validate_record_org_scope
before insert or update on public.contacts
for each row execute function private.validate_record_org_scope();

drop trigger if exists opportunities_validate_record_org_scope on public.opportunities;
create trigger opportunities_validate_record_org_scope
before insert or update on public.opportunities
for each row execute function private.validate_record_org_scope();

drop trigger if exists tasks_validate_record_org_scope on public.tasks;
create trigger tasks_validate_record_org_scope
before insert or update on public.tasks
for each row execute function private.validate_record_org_scope();

drop trigger if exists activities_validate_record_org_scope on public.activities;
create trigger activities_validate_record_org_scope
before insert or update on public.activities
for each row execute function private.validate_record_org_scope();

drop trigger if exists employee_profiles_validate_record_org_scope on public.employee_profiles;
create trigger employee_profiles_validate_record_org_scope
before insert or update on public.employee_profiles
for each row execute function private.validate_record_org_scope();

drop trigger if exists finance_transactions_validate_record_org_scope on public.finance_transactions;
create trigger finance_transactions_validate_record_org_scope
before insert or update on public.finance_transactions
for each row execute function private.validate_record_org_scope();

drop trigger if exists finance_budgets_validate_record_org_scope on public.finance_budgets;
create trigger finance_budgets_validate_record_org_scope
before insert or update on public.finance_budgets
for each row execute function private.validate_record_org_scope();

drop trigger if exists projects_validate_record_org_scope on public.projects;
create trigger projects_validate_record_org_scope
before insert or update on public.projects
for each row execute function private.validate_record_org_scope();
