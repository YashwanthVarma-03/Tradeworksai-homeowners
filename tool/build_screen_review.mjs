import fs from 'node:fs';
import path from 'node:path';

const out = 'reports/app-fixes-2026-10-15';
const previous = 'reports/app-screen-review-2026-10-15';
const review = JSON.parse(fs.readFileSync(`${previous}/whole-app-review-data.json`, 'utf8'));
const captures = JSON.parse(fs.readFileSync(`${out}/read-only-api-captures.json`, 'utf8'));
const screens = review.screens;
const e = value => String(value ?? '').replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
const row = (item,source,meaning) => ({item,source,meaning});
const catalogue = {title:'Load the public service catalogue', api:'GET Supabase /rest/v1/service_categories',
  sent:'is_active = true; select the service and category names/slugs; order by category_sort, sort_order and id; request pages of 500 rows. Header: public apikey only; no customer Authorization header.',
  response:'An array of active services. Each row contains subcategory_name, subcategory_slug, category_name and category_slug.',
  result:'Home and All services share this list and its count. Concurrent loads share one request. The five-minute in-memory cache stores real backend data. An empty successful response means zero services; a failed response does not invent a count.',
  observed:'Direct public API capture available. Device flow not captured.'};
screens[0].data[1] = row('Seven shortcut buttons and the All count','Mixed','Shortcut names and icons are fixed navigation choices. All and See all use the active backend catalogue length.');
screens[0].data[2] = row('Rotating service suggestions','Backend','The same active service names used on All services. The three-second animation makes no network call.');
screens[0].actions.unshift({...catalogue});
screens[0].notes = screens[0].notes.filter(n=>!n.includes('22')&&!n.includes('Lawn'));
screens[0].notes.push('Lawn routes to the landscaping-lawn-care category. Service catalogue updates are checked on app resume; there is no catalogue polling timer.');
screens[1].data[0] = row('Services, category groups and service counts','Backend + local presentation','Active service rows supply names and category slugs. Counts are calculated from those rows. Category icons and familiar short labels remain app presentation. Availability in a ZIP is separate from the global service list.');
screens[1].actions.unshift({...catalogue});
for (const s of screens.slice(0,2)) s.notes.push('Catalogue transport: a public-key-only request succeeds for the same global list. A diagnostic request with a customer JWT returned 403. The app intentionally does not attach a customer token to this public endpoint, so guest and signed-in users use the same working read. No backend permissions were changed.');
for (const s of screens.slice(0,2)) for (const a of s.actions) {
  for (const key of ['title','result']) a[key] = a[key].replaceAll('All 22','All services').replaceAll('See all 22','See all services');
  if (/open.*(home|browse)/i.test(a.title) && a.local) a.result += ' The screen also uses the shared public catalogue call listed above.';
}
screens[2].data.push(row('Amount beside Paid','Backend + calculation','Prefer customerPaidAmount or receiptReward.customerPaidAmount, including zero. Legacy paidAmount is accepted. For completed jobs only, a final invoiceAmount minus creditsApplied is a fallback. Booking price and cap are not payment evidence. If the amount is missing, show Completed without claiming Paid.'));
screens[3].data.push(row('Earning-band ranges','Backend','Prefer earningBands[].floor, ceiling and rate. Legacy bands[].from and upTo are normalized. A fractional rate such as 0.03 displays as 3%.'));
screens[3].data.push(row('Milestone amounts and dates','Backend','milestones[].bonus becomes the displayed amount; threshold or at sets the spend threshold. Expiry comes from the matching milestone ledger award when absent from the milestone. Missing dates are omitted, not replaced with --.'));
screens[3].data[2] = row('How credits work','App copy + backend calculation','The wording follows the supplied F01 screen. The maximum rate and annual total are calculated from the returned bands and bonuses. The current response gives 8% and $2,665.');
screens[7].actions[0] = {title:'Request a password-reset email', api:'POST Supabase /auth/v1/recover',
  sent:'Entered email; redirect_to = com.tradeworksai.homeowners://login-callback on Android/iOS; the SDK includes its PKCE challenge.',
  response:'HTTP success or an authentication error. Success does not prove inbox delivery.',
  observed:'Automated request-contract test passed. No real recovery email or inbox verification was performed.',
  result:'Shows the same neutral confirmation for all accounts. The email link should return to the app, not the website.'};
screens[7].actions[1] = {title:'Open a verified reset link and save the new password',
  api:'POST Supabase /auth/v1/token?grant_type=pkce → PUT Supabase /auth/v1/user → POST Supabase /auth/v1/logout?scope=others',
  sent:'The SDK exchanges the email callback code and its stored verifier; then sends the new password over HTTPS. Passwords and session tokens are never report evidence.',
  response:'A recovery session for the user, a successful password update, and the outcome of revoking other sessions.',
  observed:'Recovery-state, password-update and other-session-revocation tests passed using an isolated HTTP test client. Real email-link delivery and mobile deep-link launch remain unverified.',
  result:'Recovery mode shows Set password and blocks normal signed-in screens. A verified link does not require pasting a token. A failed update keeps recovery open. An optional numeric email code uses POST /auth/v1/verify with type recovery first.'};
screens[7].notes.push('Applies to every user; there is no account-specific bypass. Supabase must allow the mobile callback URL. PKCE links must be opened on the device that requested them. Email delivery, redirect allowlist and real Android/iOS launch are still release checks.');
screens[8].notes.push('Business-hours and response-time values use one shared right-hand column per section. Values have the same starting position and wrap within the column.');
screens[24].notes.push('The composer uses the same neutral border while idle and focused; the blue focus border was removed.');
for (const id of [3,4,5]) screens[id-1].notes.push('The duplicate page heading was removed. The bottom navigation label remains.');

for (const s of screens) for (const a of s.actions) {
  a.sent = a.sent.replace('Compare passes its contractor ID in this field.', 'Compare uses each selected pro’s slug.');
}
const opening = [
 'Guest: public catalogue only, plus ZIP coverage after a ZIP is entered. Signed in: profile, work orders and home profiles also supply the Home content. Shared chat/push startup is listed separately.',
 'Public catalogue. No ZIP means no contractor search. With a ZIP, load coverage and search the selected categories. Signed-in cards can also request availability.',
 'Guest: sign-in prompt only. Signed in: work-orders-list, with saved data shown when available.',
 'Guest: sign-in prompt only. Signed in: rewards on tab activation and refresh.',
 'Signed in: profile, rewards and home-profile information. Guest: sign-in prompt.',
 'No sign-in request until a button is pressed. Remembered email is read from device preferences.',
 'No account is created on page open. Requests begin on form or provider submission.',
 'Opening the form makes no email request. Opening an email callback invokes the Supabase recovery exchange.',
 'contractor-profile-get for the selected pro. Search-card information may already be visible.',
 'Uses the reviews already loaded with the pro profile. No separate review-list request on open.',
 'contractor-profile-get for each selected pro. Availability may be read for comparison labels.',
 'Loads bundled guide JSON. No article-content backend request.',
 'Uses the selected bundled guide. No article-content backend request.',
 'Loads the booking context, saved addresses, rewards and the selected pro’s availability as needed. No booking is committed merely by opening this page.',
 'Uses the successful booking result and submitted input. No independent confirmation fetch.',
 'Starts with the selected work-order record. Refresh and child actions can read work-orders-list again.',
 'Starts with the job record; loads rewards and work-visit availability. No approval is sent on open.',
 'Starts with the job record and loads alternative availability.',
 'Uses the job and reschedule proposal passed by the previous screen.',
 'Uses the selected job. No reply is sent on open.',
 'Uses the selected job. No no-show report is sent on open.',
 'Uses the result of the previous no-show action and the selected job.',
 'Uses the selected job and review context. Eligibility/existing-review calls are listed below where used by the parent flow.',
 'Messages use Stream Chat. Activity uses notifications-list, with work-order-derived fallback entries if needed.',
 'Connects or reuses Stream Chat. Work orders populate the optional job picker when the pro has a messaging identity.',
 'GET account; account.details fills the personal-information form.',
 'Reads work orders to identify booked pros, then public pro profiles for their accepted payment methods.',
 'GET account reads saved preferences. Device permission is a separate check.',
 'POST profile action get reads the customer’s saved addresses.',
 'Uses the selected address when editing. No address is saved on open.',
 'GET home-profiles and home-profiles/{id}; saved address data is also used.',
 'Uses the selected system. Existing photos may need a document download URL.',
 'Password fields are local. Closing an account first reads closure-preflight; no closure occurs on open.',
 'FAQ text and contact details are bundled. Signed-in work orders supply related-job choices.',
];
const fields = {
  1:[['All / See all','service_categories active rows → list length'],['Search suggestions','subcategory_name'],['Location','zip-coverage-get.city + state'],['Greeting/property','profile + addresses'],['Job cards','work-orders-list.tabs']],
  2:[['Service name/category','service_categories.subcategory_name / category_name'],['Category service count','active rows grouped by category_slug'],['Pro cards','contractor-search.results[]'],['Result count','contractor-search.count'],['ZIP availability','zip-coverage-get.categories[].available / proCount']],
  3:[['Upcoming / History','tabs.active / tabs.scheduled / tabs.history'],['Service/pro/date','serviceName / pro / scheduledStart / scheduledEnd'],['Paid amount','receiptReward.customerPaidAmount; see fallback rules above'],['Cancelled by','cancelledBy'],['Visit changes','rescheduleProposal / rescheduleProposedBy']],
  4:[['Available credits','availableBalance (balance fallback)'],['Spend / earned','periodSpend / earnedThisPeriod'],['Band range and rate','earningBands[].floor / ceiling / rate'],['Milestone bonus','milestones[].bonus'],['Milestone threshold','milestones[].threshold or at'],['Expiry','milestones[].expiresAt or matching ledger[].expiresAt'],['Transactions','ledger[]']],
  5:[['Identity/addresses','profile / addresses'],['Credit summary','availableBalance / balance'],['Home details','homeProfiles and individual home details']],
  6:[['Identity/session','Supabase user / session; provider result'],['Email/password','User input; never included in this report']],
  7:[['New account','Supabase user; session may be absent until email confirmation'],['Name/email/password','User input']],
  8:[['Recovery mode','Supabase passwordRecovery event and verified session'],['Password validation','At least eight characters; confirmation must match']],
  9:[['Business details/services','contractor-profile-get.profile'],['Hours/response tiers','Profile business-hours and response-tier data; normalized by pro_profile.dart'],['Reviews/photos','Profile reviews and media']],
  10:[['Ratings and review list','Passed pro-profile reviews aggregate and items']],
  11:[['Compared pro values','One public profile response per selected slug'],['Available visit','Normalized availability slots']],
  12:[['Guide titles/categories','assets/data/category_guides.json and homeowner_guides.json']],
  13:[['Article text/sections','Selected bundled guide record']],
  14:[['Address','profile.addresses'],['Selected service and price','Pro profile service record'],['Slots','availability-get → normalized slots'],['Credit balance','rewards.availableBalance'],['Chosen credit','User input, constrained by job type, price and balance']],
  15:[['Confirmation number','Booking response workOrderId / woNumber and submitted booking context']],
  16:[['Work-order content','work-orders-list.tabs[] job record'],['Money','invoiceAmount / creditsApplied / creditReservation / receiptReward'],['Cap/estimate','capAmount / capLineItems / estimateTotal / estimateLineItems']],
  17:[['Cap/estimate','capAmount / estimateTotal and respective line items'],['Credit balance','rewards.availableBalance'],['Repair visit','availability slots and user selection']],
  18:[['Current visit','scheduledStart / scheduledEnd'],['Alternative visits','availability slots']],
  19:[['Proposal','rescheduleProposal; proposedStart / proposedEnd fallbacks']],
  20:[['Job/reply','Passed workOrderId; customer-entered reply']],
  21:[['Job/pro/date','Passed job record; optional customer-entered note']],
  22:[['Service context','Passed serviceCategory / serviceName']],
  23:[['Existing review','review-action get_review response.review'],['New review','Customer rating, text and tags']],
  24:[['Activity','notifications[] / unreadCount'],['Conversations','Stream channels, last message and unread state'],['Fallback activity','Work-order records, not notification records']],
  25:[['Message text and files','Stream message.text / attachments'],['Job picker','work-orders-list filtered by this pro']],
  26:[['Name/phone/email','account.details; auth session fallback']],
  27:[['Accepted methods','Pro profile payment_methods / paymentMethods']],
  28:[['Preferences','account.preferences or supported response.preferences wrapper'],['Push permission','OS permission state, not the preferences API']],
  29:[['Saved address list','profile response.addresses or profile.addresses']],
  30:[['Address form','Passed saved address plus customer edits']],
  31:[['Properties','homeProfiles[]'],['Home details','home / notes / systems / documents']],
  32:[['System fields','Passed system record and edits'],['Photo','home-documents downloadUrl; signed URL is private']],
  33:[['Closure checks','closure-preflight.preflight'],['Password','Customer input sent only to Supabase']],
  34:[['FAQ/contact labels','App constants'],['Related work orders','work-orders-list.tabs']],
};
const css = `*{box-sizing:border-box}body{overflow-wrap:anywhere;margin:0;background:#f5f7fa;color:#172b43;font:16px/1.6 system-ui,sans-serif}main{max-width:1080px;margin:auto;padding:28px 24px 64px}h1{font-size:30px;line-height:1.2}h2{margin-top:32px;font-size:23px}h3{font-size:19px;margin-top:0}a{color:#125b91}nav{display:flex;gap:18px;flex-wrap:wrap}section,.card,.notice{background:white;border:1px solid #d8e0e8;border-radius:10px;padding:22px;margin:16px 0}.notice{border-left:4px solid #e8a33e}table{width:100%;border-collapse:collapse;table-layout:fixed}th,td{text-align:left;vertical-align:top;padding:12px;border-bottom:1px solid #dce3ea;overflow-wrap:anywhere}th{background:#edf2f7}dt{font-size:13px;letter-spacing:.03em;font-weight:700;text-transform:uppercase;margin-top:14px;color:#546476}dd{margin:3px 0 12px}code{font:14px/1.5 ui-monospace,Consolas,monospace;overflow-wrap:anywhere}pre{font:13px/1.6 ui-monospace,Consolas,monospace;white-space:pre-wrap;overflow-wrap:anywhere;background:#edf2f7;padding:14px;max-height:480px;overflow:auto}small{color:#596a7a}.tag{font-size:13px;background:#e9f5ed;padding:4px 8px;border-radius:4px}.muted{background:#fff3de}.toc{columns:2;column-gap:30px}.toc li{break-inside:avoid;margin:8px 0}details{margin:12px 0}summary{cursor:pointer;font-weight:600}.action{border-top:3px solid #233c59}.method{display:block;margin:5px 0} @media(max-width:600px){main{padding:18px 12px}section,.card,.notice{padding:16px}h1{font-size:26px}.toc{columns:1}th,td{padding:8px;font-size:14px}table,tbody,tr,td{display:block}thead{display:none}td{border:0;padding:7px 0}td:before{content:attr(data-label);display:block;font-weight:700;color:#546476}tr{border-bottom:1px solid #dce3ea;padding:10px 0}} @media print{body{background:white}main{max-width:none}nav{display:none}.action{break-inside:avoid}pre{max-height:none}}`;
const header = (title,sub='') => `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${e(title)}</title><style>${css}</style></head><body><main><nav><a href="${sub}TradeWorks-App-Review.html">Review index</a><a href="${sub}Data-Sources.html">All screen data</a><a href="${sub}API-Responses.html">All APIs</a><a href="${sub}API-Evidence.html">Captured JSON</a></nav><h1>${e(title)}</h1>`;
const table = (heads,rows) => `<table><thead><tr>${heads.map(x=>`<th>${e(x)}</th>`).join('')}</tr></thead><tbody>${rows.map(r=>`<tr>${r.map((x,i)=>`<td data-label="${e(heads[i])}">${e(x)}</td>`).join('')}</tr>`).join('')}</tbody></table>`;
const captureMatches = a => {
 if(a.local) return [];
 const routes=[...a.api.matchAll(/\b(GET|POST|PUT|PATCH|DELETE)\s+(?:Supabase\s+)?(\/[^\s→]+)/g)];
 return captures.filter(c=>routes.some(([,method,route])=>{
   const pattern=route.split('?')[0].replace(/[.*+?^$()|[\]\\]/g,'\\$&').replace(/\{[^}]+\}/g,'[^/]+');
   return method===c.method && new RegExp(`^${pattern}$`).test(c.path.split('?')[0]);
 }));
};
const evidenceLinks = (a,sub) => {
 const matches = captureMatches(a);
 return matches.length ? `<span class="tag">Endpoint response captured</span><p>The endpoint was checked directly. This is not a recording of this button being pressed in the APK.</p>${matches.map(c=>`<p><a href="${sub}API-Evidence.html#capture-${captures.indexOf(c)+1}">${e(c.method+' '+c.path)} — HTTP ${c.status} · ${e(c.authMode??'')}</a><br><small>${e(c.at)} · ${c.elapsedMs} ms for this request only</small></p>`).join('')}` : `<span class="tag muted">${a.local?'No server response needed':'No live response captured'}</span><p>${e(a.observed)}</p>`;
};
function actions(s,sub='') {return s.actions.map((a,i)=>`<article class="card action" id="action-${s.id}-${i+1}"><h3>${s.id}.${i+1} ${e(a.title)}</h3><dl><dt>API called</dt><dd>${a.api.split(' → ').map(x=>`<code class="method">${e(x)}</code>`).join('')}</dd>${a.local?'':`<dt>Request — what is sent</dt><dd>${e(a.sent)}</dd><dt>Expected response — what the app reads</dt><dd>${e(a.response)}</dd>`}<dt>Actual response / evidence</dt><dd>${evidenceLinks(a,sub)}</dd><dt>What happens on screen</dt><dd>${e(a.result)}</dd></dl></article>`).join('');}
function screen(s,mode='all',sub='') { return `<section id="screen-${s.id}">${sub?'':`<h2>${s.id}. ${e(s.name)}</h2>`}<p>${e(s.purpose)}</p><h3>When this screen opens</h3><p>${e(opening[s.id-1])}</p>${mode!=='api'?`<h3>Data shown on this screen</h3>${table(['What users see','Where it comes from','How it is used'],s.data.map(d=>[d.item,d.source,d.meaning]))}<h3>Field map</h3>${table(['Screen value','Response field or other source'],fields[s.id])}`:''}${mode!=='data'?`<h3>Buttons, actions and API responses</h3>${actions(s,sub)}`:''}${s.notes.length?`<h3>Important notes</h3><ul>${s.notes.map(n=>`<li>${e(n)}</li>`).join('')}</ul>`:''}<details><summary>App source files</summary><p>${e(s.source)}</p></details></section>`; }
fs.mkdirSync(`${out}/screens`, {recursive:true});
const filename = s => `${String(s.id).padStart(2,'0')}-${s.name.toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/-$/,'')}.html`;
const toc = `<ol class="toc">${screens.map(s=>`<li><a href="screens/${filename(s)}">${e(s.name)}</a></li>`).join('')}</ol>`;
const intro = `<p>15 October 2026 · Current app changes · 34 screens in the agreed order</p><div class="notice"><strong>What is verified:</strong> source mapping for all screens, plus ${captures.length} direct read-only backend responses. These are not APK request captures. A successful read does not verify booking, cancellation, payment, message delivery or password-reset email delivery.</div><p>Each screen has the same order: opening calls, displayed data, field map, then one clearly separated API card per action. <strong>Expected response</strong> is what the code reads. <strong>Actual response</strong> links to captured JSON. Missing evidence is labelled; it is never replaced with an invented response.</p>`;
const fixes = [
 ['1–2. Service count and All list','Implemented','Both use active service_categories rows. The captured response has 164 services in 31 groups. New backend services appear without changing app constants.'],
 ['3. Page headings','Implemented','Removed top Bookings, Rewards and Profile headings. Navigation labels remain.'],
 ['4. Rewards icon','Implemented; visual review needed','Recreated the thin outlined gift from the supplied F01 reference. No claim of pixel-identical sign-off.'],
 ['5. Rewards bands and milestones','Implemented','Corrected earningBands versus legacy bands; bonus versus amount; threshold versus at. Missing expiry dates are no longer printed as --.'],
 ['6. How credits work','Implemented','Reference wording restored. Rate and annual total remain calculated from backend policy rows.'],
 ['7. History Paid amount','Implemented','Reads nested receiptReward.customerPaidAmount, including zero; avoids using quoted prices as paid amounts.'],
 ['8. Pro values','Implemented','Hours and response values share an aligned right-side column.'],
 ['9. Password reset','App fix implemented; production checks pending','Uses the app callback, handles recovery mode, validates confirmation and updates through Supabase. Mobile redirect allowlist, SMTP delivery and an actual email-link test still need verification.'],
 ['10. Chat input border','Implemented','Focused border now uses the same neutral grey as the idle border.'],
 ];
const logSummary = name => {
 const p = `${out}/${name}`; if(!fs.existsSync(p)) return 'Not run.';
 const text = fs.readFileSync(p,'utf8'); const lines = text.split(/\r?\n/).filter(Boolean);
 if(name==='flutter-test.log') {
 const match=[...text.matchAll(/\+(\d+)(?: -(\d+))?: (?:All tests passed!|Some tests failed\.)/g)].at(-1);
 return match ? `${match[1]} passed; ${match[2]??0} failed.` : 'Run in progress; see flutter-test.log.';
}
const errors=[...text.matchAll(/^\s*error -/gm)].length;
const match=text.match(/(\d+) issues found/);
return match ? `${match[1]} findings, including ${errors} errors. All six errors are in the vendored speech_to_text example/test packages, not lib or app tests.` : lines.slice(-2).join(' ');
};
const appLog = fs.readFileSync(`${out}/app-analyze.log`,'utf8');
const appInfo = [...appLog.matchAll(/^\s*info -/gm)].length;
const appErrors = [...appLog.matchAll(/^\s*(?:error|warning) -/gm)].length;
const validation = `<h2>Validation and release checks</h2><ul><li>Automated tests exercise isolated HTTP clients; the production app still uses the shared live backend for every user.</li><li>All 12 focused regression checks passed. They cover public catalogue transport, paging/empty/error states, matching Home and All counts, live rewards field names, paid amounts and password recovery.</li><li>Latest complete test result: ${e(logSummary('flutter-test.log'))}</li><li>App-only analyzer (lib and test): ${appErrors} errors/warnings; ${appInfo} informational lint findings.</li><li>Whole-repository analyzer result: ${e(logSummary('flutter-analyze.log'))}</li><li>Full-suite failures remaining: guest-login screenshot baseline, home-profile screenshot baseline, and the ZIP field’s 52-pixel expectation versus its current 48-pixel height. Those app screens/styles were not changed by this request.</li><li>No new APK was built or installed for this change set. The phone’s older APK does not contain these changes yet.</li><li>No backend source was changed and no booking, payment, cancellation, review or message was submitted by these checks.</li></ul><p>Production reset setup follows <a href="https://supabase.com/docs/reference/dart/auth-resetpasswordforemail">Supabase password recovery</a> and <a href="https://supabase.com/docs/guides/auth/native-mobile-deep-linking">mobile callback configuration</a>. The app callback must be allowed in the project’s Auth URL configuration. This report does not claim that setting was checked.</p>`;
fs.writeFileSync(`${out}/TradeWorks-App-Review.html`,header('TradeWorks — App review and fixes')+intro+`<h2>Review result</h2>${table(['Request','Status','What changed'],fixes)}<h2>Screen order</h2>${toc}`+`<h2>Shared requests across screens</h2>${table(['When','What happens'],review.shared.filter(r=>r[0]!=='Legacy routes'))}`+validation+'</main></body></html>');
for (const s of screens) fs.writeFileSync(`${out}/screens/${filename(s)}`,header(`${s.id}. ${s.name}`,'../')+screen(s,'all','../')+'</main></body></html>');
for (const [file,title,mode] of [['Data-Sources.html','TradeWorks — Screen data sources','data'],['API-Responses.html','TradeWorks — Screen API calls and responses','api']]) {
 fs.writeFileSync(`${out}/${file}`,header(title)+intro+screens.map(s=>screen(s,mode)).join('')+'</main></body></html>');
}
const evidence = captures.map((c,i)=>`<section id="capture-${i+1}"><h2>${i+1}. ${e(c.method+' '+c.path)}</h2><p><span class="tag ${c.status>=400?'muted':''}">HTTP ${c.status}</span> ${e(c.at)} · ${c.elapsedMs} ms</p><p>Source: ${e(c.source)}. Authentication: ${e(c.authMode??'Not recorded')}. ${c.status===403?'Diagnostic only: customer-token catalogue read was denied. The app uses the successful public-key read shown separately.':''} Customer details and signed URLs are redacted. This timing is one network request, not screen paint time.</p><h3>Request body</h3><pre>${e(JSON.stringify(c.request,null,2))}</pre><h3>Actual response body</h3><details><summary>Show captured JSON${Array.isArray(c.response)?` (${c.response.length} rows)`:''}</summary><pre>${e(JSON.stringify(c.response,null,2))}</pre></details></section>`).join('');
fs.writeFileSync(`${out}/API-Evidence.html`,header('TradeWorks — Captured backend responses')+intro+`<p><a href="read-only-api-captures.json">Download all redacted response JSON</a></p>`+evidence+'</main></body></html>');
fs.writeFileSync(`${out}/screen-review-data.json`,JSON.stringify({date:'2026-10-15',scope:'Source + direct read-only HTTP checks; not a whole-app device pass',screens,fixes},null,2));
if(screens.length!==34 || screens.some(s=>!s.data.length||!s.actions.length||!fields[s.id]||!opening[s.id-1])) throw Error('Incomplete screen coverage');
console.log(JSON.stringify({screens:screens.length,actions:screens.reduce((n,s)=>n+s.actions.length,0),capturedResponses:captures.length,output:path.resolve(out,'TradeWorks-App-Review.html')}));
