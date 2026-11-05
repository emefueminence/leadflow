-- LeadFlow AI: organization-first multi-tenant foundation
-- Additive migration: preserves legacy user_id columns and existing lead data.
-- Apply only after reviewing the existing production schema and taking a backup.

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  industry text,
  business_model text,
  company_size text not null default 'solo'
    check (company_size in ('solo','small','medium','large','enterprise')),
  created_by uuid,
  legacy_owner_user_id uuid unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.org_memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'employee'
    check (role in ('owner','org_admin','manager','team_lead','employee','viewer')),
  access_scope text not null default 'personal'
    check (access_scope in ('organization','unit','team','personal')),
  org_unit_id uuid,
  team_id uuid,
  status text not null default 'active'
    check (status in ('invited','active','suspended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id,user_id),
  unique (organization_id,id)
);

create table if not exists public.org_units (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  parent_id uuid,
  name text not null,
  unit_type text not null default 'department'
    check (unit_type in ('division','department','business_unit','branch','location','other')),
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id,id),
  foreign key (organization_id,parent_id)
    references public.org_units(organization_id,id) on delete restrict
);

create table if not exists public.teams (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  org_unit_id uuid,
  name text not null,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id,id),
  foreign key (organization_id,org_unit_id)
    references public.org_units(organization_id,id) on delete set null
);

create table if not exists public.team_memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  team_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('lead','member','viewer')),
  created_at timestamptz not null default now(),
  unique (team_id,user_id),
  foreign key (organization_id,team_id)
    references public.teams(organization_id,id) on delete cascade
);

create table if not exists public.organization_settings (
  organization_id uuid primary key references public.organizations(id) on delete cascade,
  currency text not null default 'NGN',
  timezone text not null default 'Africa/Lagos',
  locale text not null default 'en',
  preferences jsonb not null default '{}'::jsonb,
  integrations jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.pipelines (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  description text,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id,id)
);

create table if not exists public.pipeline_stages (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  pipeline_id uuid not null,
  name text not null,
  position integer not null default 0,
  outcome text not null default 'open' check (outcome in ('open','won','lost')),
  created_at timestamptz not null default now(),
  unique (pipeline_id,position),
  foreign key (organization_id,pipeline_id)
    references public.pipelines(organization_id,id) on delete cascade
);

create table if not exists public.custom_field_definitions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  entity_type text not null default 'lead'
    check (entity_type in ('lead','contact','opportunity','account')),
  field_key text not null,
  label text not null,
  field_type text not null default 'text'
    check (field_type in ('text','number','date','boolean','select','multi_select','url','email','phone')),
  options jsonb not null default '[]'::jsonb,
  is_required boolean not null default false,
  position integer not null default 0,
  created_at timestamptz not null default now(),
  unique (organization_id,entity_type,field_key)
);

-- Add organization ownership and flexible assignment to the existing lead table.
alter table public.leads
  add column if not exists organization_id uuid,
  add column if not exists owner_user_id uuid,
  add column if not exists org_unit_id uuid,
  add column if not exists team_id uuid,
  add column if not exists pipeline_id uuid,
  add column if not exists stage_id uuid,
  add column if not exists custom_fields jsonb not null default '{}'::jsonb;

-- One legacy workspace per existing user. Existing user-owned leads and settings
-- are backfilled into that workspace without deleting or rewriting legacy fields.
insert into public.organizations (name,slug,created_by,legacy_owner_user_id)
select
  coalesce(nullif(s.business_name,''), 'My workspace'),
  'workspace-' || replace(u.user_id::text,'-',''),
  u.user_id,
  u.user_id
from (
  select user_id from public.leads where user_id is not null
  union
  select user_id from public.settings where user_id is not null
) u
left join public.settings s on s.user_id=u.user_id
on conflict (legacy_owner_user_id) do nothing;

insert into public.org_memberships (organization_id,user_id,role,access_scope,status)
select id,legacy_owner_user_id,'owner','organization','active'
from public.organizations
where legacy_owner_user_id is not null
on conflict (organization_id,user_id) do nothing;

insert into public.organization_settings (organization_id,currency,timezone,preferences,integrations)
select
  o.id,
  coalesce(nullif(s.currency,''),'NGN'),
  coalesce(nullif(s.timezone,''),'Africa/Lagos'),
  jsonb_build_object('business_name',coalesce(s.business_name,o.name),
                     'business_email',coalesce(s.business_email,'')),
  jsonb_build_object('n8n_webhook_url',coalesce(s.n8n_webhook_url,''),
                     'channels',coalesce(s.channels,'{}'::jsonb))
from public.organizations o
left join public.settings s on s.user_id=o.legacy_owner_user_id
where o.legacy_owner_user_id is not null
on conflict (organization_id) do nothing;

update public.leads l
set organization_id=o.id,
    owner_user_id=coalesce(l.owner_user_id,l.user_id)
from public.organizations o
where l.organization_id is null
  and o.legacy_owner_user_id=l.user_id;

create index if not exists leads_organization_created_idx
  on public.leads(organization_id,created_at desc);
create index if not exists leads_organization_owner_idx
  on public.leads(organization_id,owner_user_id);
create index if not exists leads_organization_team_idx
  on public.leads(organization_id,team_id);
create index if not exists leads_organization_unit_idx
  on public.leads(organization_id,org_unit_id);
create index if not exists org_memberships_user_idx
  on public.org_memberships(user_id, status);
create index if not exists org_units_parent_idx
  on public.org_units(organization_id,parent_id);
create index if not exists team_memberships_user_idx
  on public.team_memberships(organization_id,user_id);

alter table public.leads
  add constraint leads_organization_fk
    foreign key (organization_id) references public.organizations(id) on delete cascade,
  add constraint leads_owner_user_fk
    foreign key (owner_user_id) references auth.users(id) on delete set null,
  add constraint leads_org_unit_fk
    foreign key (organization_id,org_unit_id)
    references public.org_units(organization_id,id) on delete set null,
  add constraint leads_team_fk
    foreign key (organization_id,team_id)
    references public.teams(organization_id,id) on delete set null,
  add constraint leads_pipeline_fk
    foreign key (organization_id,pipeline_id)
    references public.pipelines(organization_id,id) on delete set null,
  add constraint leads_stage_fk
    foreign key (stage_id) references public.pipeline_stages(id) on delete set null;

alter table public.leads alter column organization_id set not null;

alter table public.automation_events
  add column if not exists organization_id uuid;
update public.automation_events e
set organization_id=l.organization_id
from public.leads l
where e.organization_id is null and e.lead_id=l.id;
update public.automation_events e
set organization_id=o.id
from public.organizations o
where e.organization_id is null
  and o.legacy_owner_user_id=e.user_id;
alter table public.automation_events
  add constraint automation_events_organization_fk
  foreign key (organization_id) references public.organizations(id) on delete cascade;
create index if not exists automation_events_org_created_idx
  on public.automation_events(organization_id,created_at desc);

-- Authorization helpers live outside exposed schemas. They derive identity
-- exclusively from auth.uid(), never from user-editable user metadata.
create or replace function private.is_org_member(_organization_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.org_memberships m
    where m.organization_id=_organization_id
      and m.user_id=(select auth.uid())
      and m.status='active'
  );
$$;

create or replace function private.is_org_admin(_organization_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.org_memberships m
    where m.organization_id=_organization_id
      and m.user_id=(select auth.uid())
      and m.status='active'
      and m.role in ('owner','org_admin')
  );
$$;

create or replace function private.can_access_lead(
  _organization_id uuid,
  _owner_user_id uuid,
  _org_unit_id uuid,
  _team_id uuid
)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  with recursive member_units(id) as (
    select m.org_unit_id
    from public.org_memberships m
    where m.organization_id=_organization_id
      and m.user_id=(select auth.uid())
      and m.status='active'
      and m.access_scope='unit'
      and m.org_unit_id is not null
    union all
    select child.id
    from public.org_units child
    join member_units parent on child.parent_id=parent.id
    where child.organization_id=_organization_id
  )
  select exists (
    select 1 from public.org_memberships m
    where m.organization_id=_organization_id
      and m.user_id=(select auth.uid())
      and m.status='active'
      and (
        m.role in ('owner','org_admin')
        or m.access_scope='organization'
        or (m.access_scope='personal' and _owner_user_id=(select auth.uid()))
        or (m.access_scope='unit' and _org_unit_id in (select id from member_units))
        or (m.access_scope='team' and _team_id is not null and exists (
          select 1 from public.team_memberships tm
          where tm.organization_id=_organization_id
            and tm.team_id=_team_id
            and tm.user_id=(select auth.uid())
        ))
      )
  );
$$;

revoke all on function private.is_org_member(uuid) from public;
revoke all on function private.is_org_admin(uuid) from public;
revoke all on function private.can_access_lead(uuid,uuid,uuid,uuid) from public;
grant execute on function private.is_org_member(uuid) to authenticated;
grant execute on function private.is_org_admin(uuid) to authenticated;
grant execute on function private.can_access_lead(uuid,uuid,uuid,uuid) to authenticated;

-- RLS: every organization-owned row is tenant-scoped. Admin writes are explicit.
alter table public.organizations enable row level security;
alter table public.org_memberships enable row level security;
alter table public.org_units enable row level security;
alter table public.teams enable row level security;
alter table public.team_memberships enable row level security;
alter table public.organization_settings enable row level security;
alter table public.pipelines enable row level security;
alter table public.pipeline_stages enable row level security;
alter table public.custom_field_definitions enable row level security;
alter table public.leads enable row level security;
alter table public.automation_events enable row level security;

drop policy if exists organizations_member_select on public.organizations;
create policy organizations_member_select on public.organizations
for select to authenticated using (private.is_org_member(id));
drop policy if exists organizations_admin_update on public.organizations;
create policy organizations_admin_update on public.organizations
for update to authenticated using (private.is_org_admin(id))
with check (private.is_org_admin(id));

drop policy if exists org_memberships_self_or_admin_select on public.org_memberships;
create policy org_memberships_self_or_admin_select on public.org_memberships
for select to authenticated
using (user_id=(select auth.uid()) or private.is_org_admin(organization_id));
drop policy if exists org_memberships_admin_manage on public.org_memberships;
create policy org_memberships_admin_manage on public.org_memberships
for all to authenticated
using (private.is_org_admin(organization_id))
with check (private.is_org_admin(organization_id));

drop policy if exists org_units_member_select on public.org_units;
create policy org_units_member_select on public.org_units
for select to authenticated using (private.is_org_member(organization_id));
drop policy if exists org_units_admin_manage on public.org_units;
create policy org_units_admin_manage on public.org_units
for all to authenticated using (private.is_org_admin(organization_id))
with check (private.is_org_admin(organization_id));

drop policy if exists teams_member_select on public.teams;
create policy teams_member_select on public.teams
for select to authenticated using (private.is_org_member(organization_id));
drop policy if exists teams_admin_manage on public.teams;
create policy teams_admin_manage on public.teams
for all to authenticated using (private.is_org_admin(organization_id))
with check (private.is_org_admin(organization_id));

drop policy if exists team_memberships_self_or_admin_select on public.team_memberships;
create policy team_memberships_self_or_admin_select on public.team_memberships
for select to authenticated
using (user_id=(select auth.uid()) or private.is_org_admin(organization_id));
drop policy if exists team_memberships_admin_manage on public.team_memberships;
create policy team_memberships_admin_manage on public.team_memberships
for all to authenticated using (private.is_org_admin(organization_id))
with check (private.is_org_admin(organization_id));

drop policy if exists organization_settings_member_select on public.organization_settings;
create policy organization_settings_member_select on public.organization_settings
for select to authenticated using (private.is_org_member(organization_id));
drop policy if exists organization_settings_admin_manage on public.organization_settings;
create policy organization_settings_admin_manage on public.organization_settings
for all to authenticated using (private.is_org_admin(organization_id))
with check (private.is_org_admin(organization_id));

drop policy if exists pipelines_member_select on public.pipelines;
create policy pipelines_member_select on public.pipelines
for select to authenticated using (private.is_org_member(organization_id));
drop policy if exists pipelines_admin_manage on public.pipelines;
create policy pipelines_admin_manage on public.pipelines
for all to authenticated using (private.is_org_admin(organization_id))
with check (private.is_org_admin(organization_id));

drop policy if exists pipeline_stages_member_select on public.pipeline_stages;
create policy pipeline_stages_member_select on public.pipeline_stages
for select to authenticated using (private.is_org_member(organization_id));
drop policy if exists pipeline_stages_admin_manage on public.pipeline_stages;
create policy pipeline_stages_admin_manage on public.pipeline_stages
for all to authenticated using (private.is_org_admin(organization_id))
with check (private.is_org_admin(organization_id));

drop policy if exists custom_fields_member_select on public.custom_field_definitions;
create policy custom_fields_member_select on public.custom_field_definitions
for select to authenticated using (private.is_org_member(organization_id));
drop policy if exists custom_fields_admin_manage on public.custom_field_definitions;
create policy custom_fields_admin_manage on public.custom_field_definitions
for all to authenticated using (private.is_org_admin(organization_id))
with check (private.is_org_admin(organization_id));

drop policy if exists leads_org_scope_select on public.leads;
create policy leads_org_scope_select on public.leads
for select to authenticated
using (private.can_access_lead(organization_id,owner_user_id,org_unit_id,team_id));
drop policy if exists leads_org_scope_insert on public.leads;
create policy leads_org_scope_insert on public.leads
for insert to authenticated
with check (
  private.is_org_member(organization_id)
  and (owner_user_id is null or owner_user_id=(select auth.uid()) or private.is_org_admin(organization_id))
);
drop policy if exists leads_org_scope_update on public.leads;
create policy leads_org_scope_update on public.leads
for update to authenticated
using (private.can_access_lead(organization_id,owner_user_id,org_unit_id,team_id))
with check (
  private.is_org_member(organization_id)
  and (owner_user_id is null or owner_user_id=(select auth.uid()) or private.is_org_admin(organization_id))
);
drop policy if exists leads_org_scope_delete on public.leads;
create policy leads_org_scope_delete on public.leads
for delete to authenticated
using (private.can_access_lead(organization_id,owner_user_id,org_unit_id,team_id));

drop policy if exists automation_events_org_select on public.automation_events;
create policy automation_events_org_select on public.automation_events
for select to authenticated using (private.is_org_member(organization_id));

-- New signups receive a private default workspace and owner membership.
create or replace function private.create_default_workspace_for_new_user()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  _name text;
  _org_id uuid;
begin
  _name := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'business_name'),''),
    nullif(split_part(coalesce(new.email,''),'@',1),''),
    'My workspace'
  );
  insert into public.organizations(name,slug,created_by)
  values (_name, 'workspace-' || replace(gen_random_uuid()::text,'-',''), new.id)
  returning id into _org_id;

  insert into public.org_memberships(organization_id,user_id,role,access_scope,status)
  values (_org_id,new.id,'owner','organization','active');

  insert into public.organization_settings(organization_id)
  values (_org_id);

  return new;
end;
$$;

revoke all on function private.create_default_workspace_for_new_user() from public;
drop trigger if exists on_auth_user_created_create_workspace on auth.users;
create trigger on_auth_user_created_create_workspace
after insert on auth.users
for each row execute function private.create_default_workspace_for_new_user();

-- Deliberately retain legacy settings and user_id columns during the app migration.
-- Do not remove legacy policies/columns until the new UI and API are fully switched
-- to organization_id and cross-tenant acceptance tests have passed.
