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
    if(!/^[0-9a-f-]{36}$/i.test(organizationId)||!/^\S+@\S+\.\S+$/.test(email))
      return json(res,400,{error:'A valid workspace and email address are required'});
    if(!allowedRoles.has(role)||!allowedScopes.has(accessScope))
      return json(res,400,{error:'The selected role or access scope is not permitted'});
    const db=admin();
    const membership=await getActiveMembership(db,actor.id,organizationId);
    if(!membership||!['owner','org_admin'].includes(membership.role))
      return json(res,403,{error:'Only organization owners and admins can invite members'});
    const {data:invited,error:inviteError}=await db.auth.admin.inviteUserByEmail(email,{data:{invited_to_organization:organizationId}});
    if(inviteError||!invited.user) {
      console.error('invite email error',inviteError?.message);
      return json(res,400,{error:inviteError?.message||'Could not send invitation. The email may already have an account.'});
    }
    const {error:memberError}=await db.from('org_memberships').insert({
      organization_id:organizationId,user_id:invited.user.id,role,access_scope:accessScope,status:'active'
    });
    if(memberError) {
      console.error('invite membership error',memberError.message);
      return json(res,500,{error:'Invitation email was sent, but workspace membership could not be completed. Contact support before sending another invitation.'});
    }
    return json(res,201,{ok:true,email,userId:invited.user.id});
  } catch(error:any) {
    console.error('invite error',error?.message);
    return json(res,error.message==='Unauthorized'?401:500,{error:error.message||'Invitation failed'});
  }
}
