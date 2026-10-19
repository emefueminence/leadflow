import { supabase } from './supabase';
async function token(){const{data}=await supabase!.auth.getSession();return data.session?.access_token}
export async function api(path:string,body:any){const t=await token();const r=await fetch(path,{method:'POST',headers:{'content-type':'application/json',...(t?{authorization:'Bearer '+t}:{})},body:JSON.stringify(body)});const j=await r.json().catch(()=>({}));if(!r.ok)throw new Error(j.error||'Request failed');return j}
