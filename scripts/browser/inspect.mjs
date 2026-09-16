import fs from 'node:fs';
import path from 'node:path';
import readline from 'node:readline/promises';
import { chromium } from 'playwright';

const configPath=process.argv[2];
const profileId=process.argv[3];
const extensionId=process.argv[4];
const executablePath=process.argv[5];
const config=JSON.parse(fs.readFileSync(configPath,'utf8').replace(/^\uFEFF/,''));
const profile=config.profiles[profileId];
if(!profile) throw new Error('Profile not found: '+profileId);
const url=new URL(profile.web.url);
if (!['http:','https:'].includes(url.protocol)) throw new Error('HTTP(S) URL required');
const attached=profile.browser.mode==='cdp';
const browser=attached
  ? await chromium.connectOverCDP(profile.browser.cdp_endpoint)
  : await chromium.launch({headless:false,executablePath});
let context;
try {
  const options={};
  if(profile.web.login_mode==='storage-state') {
    const state=process.env[profile.browser.storage_state_ref];
    if(!state) throw new Error('Storage state reference environment variable is missing');
    options.storageState=state;
  }
  context=await browser.newContext(options);
  const page=await context.newPage();
  await page.goto(url.href,{waitUntil:'domcontentloaded'});
  const rl=readline.createInterface({input:process.stdin,output:process.stdout});
  await rl.question('Complete login/navigation manually; remove sensitive content, then press Enter to capture. ');
  rl.close();
  const workspaceRoot=path.dirname(configPath);
  const out=path.join(workspaceRoot,'runtime','browser',extensionId,new Date().toISOString().replace(/[:.]/g,'-'));
  fs.mkdirSync(out,{recursive:true});
  await page.screenshot({path:path.join(out,'page.png'),fullPage:true});
  fs.writeFileSync(path.join(out,'page.html'),await page.content());
  console.log('Captured in '+out+'. Review/redact before promoting evidence.');
} finally {
  if(context) await context.close();
  if(!attached) await browser.close();
}
process.exit(0);
