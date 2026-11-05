import type { SupabaseClient } from '@supabase/supabase-js';

export async function getActiveMembership(db: SupabaseClient, userId: string, organizationId: string) {
  const { data, error } = await db.from('org_memberships')
    .select('organization_id,user_id,role,access_scope,org_unit_id,team_id,status')
    .eq('organization_id', organizationId).eq('user_id', userId).eq('status', 'active').maybeSingle();
  if (error) throw error;
  return data;
}

export async function canAccessLead(db: SupabaseClient, membership: any, lead: any, userId: string) {
  if (!membership || membership.status !== 'active') return false;
  if (membership.role === 'owner' || membership.role === 'org_admin' || membership.access_scope === 'organization') return true;
  if (membership.access_scope === 'personal') return lead.owner_user_id === userId;
  if (membership.access_scope === 'team') {
    if (!lead.team_id) return false;
    const { data, error } = await db.from('team_memberships').select('id')
      .eq('organization_id', membership.organization_id).eq('team_id', lead.team_id).eq('user_id', userId).maybeSingle();
    if (error) throw error;
    return Boolean(data);
  }
  if (membership.access_scope === 'unit') {
    if (!lead.org_unit_id || !membership.org_unit_id) return false;
    const { data, error } = await db.from('org_units').select('id,parent_id')
      .eq('organization_id', membership.organization_id);
    if (error) throw error;
    const visible = new Set<string>([membership.org_unit_id]);
    let changed = true;
    while (changed) {
      changed = false;
      for (const unit of data || []) {
        if (unit.parent_id && visible.has(unit.parent_id) && !visible.has(unit.id)) {
          visible.add(unit.id);
          changed = true;
        }
      }
    }
    return visible.has(lead.org_unit_id);
  }
  return false;
}
