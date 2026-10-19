import{createClient}from'@supabase/supabase-js';
export const url=process.env.SUPABASE_URL||process.env.VITE_SUPABASE_URL!;
export const pub=process.env.SUPABASE_PUBLISHABLE_KEY||process.env.VITE_SUPABASE_PUBLISHABLE_KEY!;
export const secret=process.env.SUPABASE_SECRET_KEY!;
export const admin=()=>createClient(url,secret,{auth:{persistSession:false,autoRefreshToken:false}});
export async function user(req:any){const h=req.headers.authorization||'';if(!h.startsWith('Bearer '))throw new Error('Unauthorized');const c=createClient(url,pub,{global:{headers:{Authorization:h}},auth:{persistSession:false,autoRefreshToken:false}});const{data,error}=await c.auth.getUser(h.slice(7));if(error||!data.user)throw new Error('Unauthorized');return data.user}
export function json(res:any,status:number,data:any){res.status(status).setHeader('content-type','application/json');res.end(JSON.stringify(data))}
export async function body(req:any){if(req.body&&typeof req.body==='object')return req.body;let s='';for await(const c of req)s+=c;return s?JSON.parse(s):{}}
