import { admin, body, json, user, clean } from './_shared.js';
import { getActiveMembership } from './_org.js';

const allowedRoles = new Set(['manager','team_lead','employee','viewer']);
const allowedScopes = new Set(['organization','unit','team','personal']);

async function findAuthUserByEmail(db:any,email:string){
  for(let page=1;page<=20;page++){
    const {data,error}=await db.auth.admin.listUsers({page,perPage:500});
    if(error)throw error;
    const users=data?.users||[];
    const found=users.find((x:any)=>String(x.email||'').toLowerCase()===email);
    if(found)return found;
    if(users.length<500)break;
  }
  return null;
}

export default async function handler(req:any,res:any) {
  if(req.method!=='POST') return json(res,405,{error:'Method not allowed'});
  try {
    const actor=await user(req), input=await body(req);
    const organizationId=String(input.organizationId||'');
    const email=clean(input.email,254).toLowerCase();
    const role=String(input.role||'employee');
    const accessScope=String(input.accessScope||'personal');
    const orgUnitId=accessScope==='unit'?clean(input.orgUnitId,50):'';
    const teamId=accessScope==='team'?clean(input.teamId,50):'';
    if(!/^[0-9a-f-]{36}$/i.test(organizationId)||!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))
      return json(res,400,{error:'A valid workspace and email address are required'});
    if(!allowedRoles.has(role)||!allowedScopes.has(accessScope))
      return json(res,400,{error:'The selected role or access scope is not permitted'});
    const db=admin();
    const membership=await getActiveMembership(db,actor.id,organizationId);
    if(!membership||!['owner','org_admin'].includes(membership.role))
      return json(res,403,{error:'Only organization owners and admins can add members'});
    if(accessScope==='unit'&&!orgUnitId)return json(res,400,{error:'Choose the organizational unit for unit-level access'});
    if(accessScope==='team'&&!teamId)return json(res,400,{error:'Choose the team for team-level access'});
    if(orgUnitId){const {data:unit}=await db.from('org_units').select('id').eq('id',orgUnitId).eq('organization_id',organizationId).maybeSingle();if(!unit)return json(res,400,{error:'Selected organizational unit is not part of this workspace'});}
    if(teamId){const {data:team}=await db.from('teams').select('id').eq('id',teamId).eq('organization_id',organizationId).maybeSingle();if(!team)return json(res,400,{error:'Selected team is not part of this workspace'});}
    let target=await findAuthUserByEmail(db,email);
    const existingUser=Boolean(target);
    if(!target){
      const {data:invited,error:inviteError}=await db.auth.admin.inviteUserByEmail(email,{data:{invited_to_organization:organizationId}});
      if(inviteError||!invited.user){
        console.error('invite email error',inviteError?.message);
        return json(res,400,{error:inviteError?.message||'Could not send invitation'});
      }
      target=invited.user;
    }
    const {data:oldMembership,error:lookupError}=await db.from('org_memberships').select('id,status').eq('organization_id',organizationId).eq('user_id',target.id).maybeSingle();
    if(lookupError)throw lookupError;
    if(oldMembership?.status==='active')return json(res,409,{error:'This person is already an active member of this workspace'});
    const memberPayload={organization_id:organizationId,user_id:target.id,role,access_scope:accessScope,org_unit_id:orgUnitId||null,team_id:teamId||null,status:'active',updated_at:new Date().toISOString()};
    const {error:memberError}=oldMembership
      ? await db.from('org_memberships').update(memberPayload).eq('id',oldMembership.id)
      : await db.from('org_memberships').insert(memberPayload);
    if(memberError){
      console.error('invite membership error',memberError.message);
      return json(res,500,{error:'The account was found, but workspace access could not be completed. You can retry without creating another account.'});
    }
    if(teamId){
      const {error:teamError}=await db.from('team_memberships').upsert({organization_id:organizationId,team_id:teamId,user_id:target.id,role:'member'},{onConflict:'team_id,user_id'});
      if(teamError){console.error('invite team membership error',teamError.message);return json(res,500,{error:'Workspace access was added, but team assignment failed. Edit the member assignment and retry.'});}
    }
    return json(res,existingUser?200:201,{ok:true,email,userId:target.id,existingUser,action:existingUser?'member_added':'invitation_sent'});
  } catch(error:any) {
    console.error('invite error',error?.message);
    return json(res,error.message==='Unauthorized'?401:500,{error:error.message||'Member access could not be added'});
  }
}
