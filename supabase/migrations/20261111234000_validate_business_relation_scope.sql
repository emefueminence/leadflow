-- Validate business-record relationships against the owning workspace.
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
  v_pipeline uuid;
  v_stage uuid;
  v_account uuid;
  v_contact uuid;
  v_manager uuid;
begin
  v_org := (to_jsonb(new)->>'organization_id')::uuid;
  v_unit := nullif(to_jsonb(new)->>'org_unit_id','')::uuid;
  v_team := nullif(to_jsonb(new)->>'team_id','')::uuid;
  v_scope := to_jsonb(new)->>'access_scope';
  v_pipeline := nullif(to_jsonb(new)->>'pipeline_id','')::uuid;
  v_stage := nullif(to_jsonb(new)->>'stage_id','')::uuid;

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

  if tg_table_name = 'pipeline_stages' or tg_table_name in ('leads','opportunities') then
    if v_pipeline is null and (tg_table_name = 'pipeline_stages' or v_stage is not null) then
      raise exception 'A pipeline stage must belong to a pipeline';
    end if;
    if v_pipeline is not null and not exists (
      select 1 from public.pipelines p
       where p.id = v_pipeline and p.organization_id = v_org
    ) then
      raise exception 'Pipeline must belong to the same workspace';
    end if;
    if v_stage is not null and not exists (
      select 1 from public.pipeline_stages s
       where s.id = v_stage and s.organization_id = v_org
         and s.pipeline_id = v_pipeline
    ) then
      raise exception 'Pipeline stage must belong to the selected workspace and pipeline';
    end if;
  end if;

  if tg_table_name = 'contacts' then
    v_account := nullif(to_jsonb(new)->>'account_id','')::uuid;
    if v_account is not null and not exists (
      select 1 from public.accounts a
       where a.id = v_account and a.organization_id = v_org
    ) then
      raise exception 'Contact account must belong to the same workspace';
    end if;
  elsif tg_table_name = 'opportunities' then
    v_account := nullif(to_jsonb(new)->>'account_id','')::uuid;
    v_contact := nullif(to_jsonb(new)->>'contact_id','')::uuid;
    if v_account is not null and not exists (
      select 1 from public.accounts a
       where a.id = v_account and a.organization_id = v_org
    ) then
      raise exception 'Opportunity account must belong to the same workspace';
    end if;
    if v_contact is not null and not exists (
      select 1 from public.contacts c
       where c.id = v_contact and c.organization_id = v_org
    ) then
      raise exception 'Opportunity contact must belong to the same workspace';
    end if;
  elsif tg_table_name = 'employee_profiles' then
    v_manager := nullif(to_jsonb(new)->>'manager_user_id','')::uuid;
    if v_manager is not null and not exists (
      select 1 from public.org_memberships m
       where m.organization_id = v_org and m.user_id = v_manager
         and m.status = 'active'
    ) then
      raise exception 'Employee manager must be an active member of the same workspace';
    end if;
  end if;

  return new;
end;
$function$;
