// Read-only API evidence. Credentials are supplied through the environment;
// access/refresh tokens are kept in memory and never written to disk.
import fs from 'node:fs';
const base='https://tradeworks-api-7mobhz4bsq-ue.a.run.app';
const supabase='https://bhtjlxotnegjtiubmyea.supabase.co';
const apikey='sb_publishable_f4hed0gVDVRnAsh-hRyj0A_wwhKISw2';
const dir='reports/app-fixes-2026-10-15';
fs.mkdirSync(dir,{recursive:true});
const captures=[];
let token;
async function read(path,body,host=base,publicOnly=false) {
 const start=Date.now();
 const requestToken=publicOnly?null:token;
 const response=await fetch(host+path,{method:body===undefined?'GET':'POST',headers:{'Content-Type':'application/json',...(host===supabase?{apikey}:{}),...(requestToken?{Authorization:`Bearer ${requestToken}`}:{})},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(30000)});
 const raw=await response.text();let data;try{data=JSON.parse(raw)}catch{data=raw}
 captures.push({path,method:body===undefined?'GET':'POST',authMode:requestToken?'Signed-in customer':'Public catalogue/guest',request:body??null,status:response.status,at:new Date(start).toISOString(),elapsedMs:Date.now()-start,response:data,source:'Direct read-only HTTP probe; not an APK capture'});
 console.log(JSON.stringify({path,status:response.status,keys:Array.isArray(data)?undefined:typeof data==='object'&&data!==null?Object.keys(data):[],rows:Array.isArray(data)?data.length:undefined}));
 return data;
}
await read('/public/zip-coverage-get',{zip:'33602'});
const search = await read('/public/contractor-search',{zip:'33602',categorySlug:'hvac',urgency:'standard'});
const firstPro = search.results?.find(p=>p.slug||p.profileSlug);
if(firstPro) await read('/public/contractor-profile-get',{slug:firstPro.slug??firstPro.profileSlug});
await read('/rest/v1/service_categories?select=*&limit=1000',undefined,supabase);
if(process.env.TW_REVIEW_EMAIL&&process.env.TW_REVIEW_PASSWORD){
 const auth=await fetch(supabase+'/auth/v1/token?grant_type=password',{method:'POST',headers:{apikey,'Content-Type':'application/json'},body:JSON.stringify({email:process.env.TW_REVIEW_EMAIL,password:process.env.TW_REVIEW_PASSWORD})});
 const session=await auth.json();
 if(!auth.ok||!session.access_token) throw Error(`Review sign-in failed (${auth.status}); credentials not logged.`);
 token=session.access_token;
 await read('/rest/v1/service_categories?select=id,category_name,category_slug,subcategory_name,subcategory_slug,is_active,category_sort,sort_order&is_active=eq.true&order=category_sort,sort_order,id&offset=0&limit=500',undefined,supabase);
 await read('/rest/v1/service_categories?select=id,category_name,category_slug,subcategory_name,subcategory_slug,is_active,category_sort,sort_order&is_active=eq.true&order=category_sort,sort_order,id&offset=0&limit=500',undefined,supabase,true);
 const userId=session.user.app_metadata?.legacy_id??session.user.user_metadata?.legacy_id??session.user.id;
 await read('/homeowner/rewards',{});
 const jobs=await read('/homeowner/work-orders-list',{userId});
 await read('/homeowner/profile',{action:'get',userId});
 await read('/homeowner/account');
 await read('/homeowner/account/closure-preflight');
 await read('/homeowner/notifications-list',{limit:10,offset:0});
 const homes=await read('/homeowner/home-profiles');
 for(const home of (homes.homeProfiles??[])) await read(`/homeowner/home-profiles/${encodeURIComponent(home.id)}`);
 console.log(JSON.stringify({jobGroups:Object.fromEntries(Object.entries(jobs.tabs??{}).map(([key,rows])=>[key,Array.isArray(rows)?rows.length:typeof rows]))}));
}
// Customer identity and document URLs are not needed to debug numeric fields.
const redact=(value,key='')=>{
 if(/(token|email|phone|givenName|familyName|userName|name$|street|unit$|address|Url$|body$|text$|description|notes|scope|accessCode)/i.test(key)) return value == null ? null : '[redacted]';
 if(typeof value==='string' && /[?&]token=/.test(value)) return '[redacted signed URL]';
 if(Array.isArray(value)) return value.map(v=>redact(v));
 if(value&&typeof value==='object') return Object.fromEntries(Object.entries(value).map(([k,v])=>[k,redact(v,k)]));
 return value;
};
fs.writeFileSync(`${dir}/read-only-api-captures.json`,JSON.stringify(captures.map(c=>({...c,request:redact(c.request),response:c.path.includes('/rest/')?c.response:redact(c.response)})),null,2));
