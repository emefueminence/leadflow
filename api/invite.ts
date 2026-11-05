import { admin, body, json, user, clean } from './_shared.js';
import { getActiveMembership } from './_org.js';

const allowedRoles = new Set(['manager','team_lead','employee','viewer']);
const allowedScopes = new Set(['organization','unit','team','personal']);
export default async function handler(req:any,res:any) {
  if(req.method!=='POST') return json(res,405,{error:'Method not allowed'});
  try {
    const actor=await user(req), input=await body(req);
    const organizationId=String(input.organizationId||'');
    const email=clean(input.email,254).toLowerCase();
    const role=String(input.role||'employee');
    const accessScope=String(input.accessScope||'personal');
    const orgUnitId=accessScope==='unit'?clean(input.orgUnitId,50):'', teamId=accessScope==='team'?clean(input.teamId,50):'';
    if(!/^[0-9a-f-]{36}$/i.test(organizationId)||!/^\S+@\S+\.\S+$/.test(email))
      return json(res,400,{error:'A valid workspace and email address are required'});
    if(!allowedRoles.has(role)||!allowedScopes.has(accessScope))
      return json(res,400,{error:'The selected role or access scope is not permitted'});
    const db=admin();
    const membership=await getActiveMembership(db,actor.id,organizationId);
    if(!membership||!['owner','org_admin'].includes(membership.role))
      return json(res,403,{error:'Only organization owners and admins can invite members'});
    if(accessScope==='unit'&&!orgUnitId)return json(res,400,{error:'Choose the organizational unit for unit-level access'});
    if(accessScope==='team'&&!teamId)return json(res,400,{error:'Choose the team for team-level access'});
    if(orgUnitId){const {data:unit}=await db.from('org_units').select('id').eq('id',orgUnitId).eq('organization_id',organizationId).maybeSingle();if(!unit)return json(res,400,{error:'Selected organizational unit is not part of this workspace'});}
    if(teamId){const {data:team}=await db.from('teams').select('id').eq('id',teamId).eq('organization_id',organizationId).maybeSingle();if(!team)return json(res,400,{error:'Selected team is not part of this workspace'});}
    const {data:invited,error:inviteError}=await db.auth.admin.inviteUserByEmail(email,{data:{invited_to_organization:organizationId}});
    if(inviteError||!invited.user) {
      console.error('invite email error',inviteError?.message);
      return json(res,400,{error:inviteError?.message||'Could not send invitation. The email may already have an account.'});
    }
    const {error:memberError}=await db.from('org_memberships').insert({
      organization_id:organizationId,user_id:invited.user.id,role,access_scope:accessScope,org_unit_id:orgUnitId||null,team_id:teamId||null,status:'active'
    });
    if(memberError) {
      console.error('invite membership error',memberError.message);
      return json(res,500,{error:'Invitation email was sent, but workspace membership could not be completed. Contact support before sending another invitation.'});
    }
    if(teamId){const {error:teamError}=await db.from('team_memberships').insert({organization_id:organizationId,team_id:teamId,user_id:invited.user.id,role:'member'});if(teamError){console.error('invite team membership error',teamError.message);return json(res,500,{error:'Invitation was sent and organization access created, but team assignment failed.'});}}
    return json(res,201,{ok:true,email,userId:invited.user.id});
  } catch(error:any) {
    console.error('invite error',error?.message);
    return json(res,error.message==='Unauthorized'?401:500,{error:error.message||'Invitation failed'});
  }
}
