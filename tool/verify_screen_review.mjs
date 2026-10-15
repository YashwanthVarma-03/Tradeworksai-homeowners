import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {chromium}=require('C:/Users/yashw/AppData/Local/npm-cache/_npx/e41f203b7505f1fb/node_modules/playwright-core');
const dir=path.resolve('reports/app-fixes-2026-10-15');
const files=[...fs.readdirSync(dir).filter(f=>f.endsWith('.html')), ...fs.readdirSync(path.join(dir,'screens')).filter(f=>f.endsWith('.html')).map(f=>`screens/${f}`)];
const result={screenPages:files.filter(f=>f.startsWith('screens/')).length,htmlFiles:files.length,links:0,viewports:[]};
if(result.screenPages!==34) throw Error('Expected 34 screen pages');
for(const file of files){
 const html=fs.readFileSync(path.join(dir,file),'utf8');
 const ids=[...html.matchAll(/\bid="([^"]+)"/g)].map(m=>m[1]);
 if(new Set(ids).size!==ids.length)throw Error(`Duplicate IDs in ${file}`);
 for(const [,href] of html.matchAll(/href="([^"]+)"/g)){
  if(/^https?:/.test(href))continue;
  const [target,anchor]=href.split('#');
  const resolved=target?path.resolve(dir,path.dirname(file),target):path.join(dir,file);
  if(!fs.existsSync(resolved))throw Error(`Broken link ${file}: ${href}`);
  if(anchor&&!fs.readFileSync(resolved,'utf8').includes(`id="${anchor}"`))throw Error(`Missing anchor ${href}`);
  result.links++;
 }
}
const browser=await chromium.launch({headless:true});
try{
 const page=await browser.newPage();
 await page.route('**/*',r=>r.request().url().startsWith('file:')?r.continue():r.abort());
 for(const width of [1280,390])for(const file of ['TradeWorks-App-Review.html','screens/01-home.html','screens/04-rewards.html','screens/08-password-reset.html','API-Evidence.html']){
  await page.setViewportSize({width,height:1000});
  await page.goto(pathToFileURL(path.join(dir,file)).href);
  const overflow=await page.evaluate(()=>document.documentElement.scrollWidth>document.documentElement.clientWidth+1);
  if(overflow)throw Error(`Horizontal overflow ${file} ${width}`);
  result.viewports.push({file,width,overflow:false});
  if(file==='screens/04-rewards.html')await page.screenshot({path:path.join(dir,`review-rewards-${width}.png`)});
 }
}finally{await browser.close();}
fs.writeFileSync(path.join(dir,'document-validation.json'),JSON.stringify(result,null,2));
console.log(JSON.stringify(result));
