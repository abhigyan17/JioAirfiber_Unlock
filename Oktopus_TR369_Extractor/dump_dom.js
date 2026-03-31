const { chromium } = require('playwright');
const fs = require('fs');
require('dotenv').config();

async function dump() {
    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext();
    const page = await context.newPage();
    try {
        await page.goto('https://app.oktopus.app.br/');
        const username = process.env.OKTOPUS_USER;
        const password = process.env.OKTOPUS_PASS;
        await page.waitForSelector('input', { timeout: 10000 });
        const inputs = await page.$$('input');
        await inputs[0].fill(username);
        await inputs[1].fill(password);
        await page.keyboard.press('Enter');
        await page.waitForTimeout(4000);
        
        await page.goto('https://app.oktopus.app.br/devices', { waitUntil: 'networkidle' });
        await page.waitForTimeout(3000);
        
        const rows = await page.$$('tr');
        for (const row of rows) {
            const text = await row.innerText();
            if (text.includes('Online')) {
                const accessBtn = await row.$('button[aria-label="Access the device"]');
                if (accessBtn) {
                    await accessBtn.click();
                    try {
                        await page.waitForURL('**/analysis', { timeout: 15000 });
                    } catch(e) {}
                    await page.waitForTimeout(2000);
                    const tabs = await page.$$('.MuiTab-root');
                    for (const tab of tabs) {
                        const tabText = await tab.innerText();
                        if (tabText.includes('Discovery')) {
                            await tab.click();
                            await page.waitForTimeout(5000); // Wait for tree to render
                            
                            const html = await page.evaluate(() => {
                                const list = document.querySelector('.MuiList-root, .simplebar-content');
                                return list ? list.outerHTML : document.body.innerHTML;
                            });
                            fs.writeFileSync('dom_dump.html', html);
                            
                            const tree = await page.evaluate(() => {
                                let elements = Array.from(document.querySelectorAll('li.MuiListItem-root'));
                                return elements.map(el => {
                                     return {
                                         html: el.outerHTML,
                                         innerText: el.innerText.trim().replace(/\n/g, ' \\n ')
                                     };
                                });
                            });
                            fs.writeFileSync('tree_dump.json', JSON.stringify(tree, null, 2));
                            break;
                        }
                    }
                    break;
                }
            }
        }
    } catch(e) {
        console.error(e);
    } finally {
        await browser.close();
    }
}
dump();
