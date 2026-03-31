require('dotenv').config();
const { chromium } = require('playwright');
const fs = require('fs');

async function runScraper(username, password, headless = true, onLog = console.log) {
    if (!username || !password) {
        onLog("Error: Username and Password are required.");
        throw new Error("Missing credentials");
    }

    onLog("Launching browser...");
    const browser = await chromium.launch({ headless });
    const context = await browser.newContext({
        ignoreHTTPSErrors: true,
        viewport: { width: 1280, height: 800 }
    });
    const page = await context.newPage();

    try {
        onLog("Navigating to login page...");
        await page.goto('https://app.oktopus.app.br/');

        onLog("Logging in...");
        await page.waitForSelector('input', { timeout: 10000 });
        
        const inputs = await page.$$('input');
        if (inputs.length >= 2) {
            await inputs[0].fill(username);
            await inputs[1].fill(password);
        } else {
            onLog("Error: Could not find login inputs.");
            await browser.close();
            throw new Error("Could not find login inputs");
        }

        await page.keyboard.press('Enter');
        
        onLog("Waiting for login to complete...");
        await page.waitForTimeout(4000); 

        onLog("Navigating to devices page...");
        await page.goto('https://app.oktopus.app.br/devices', { waitUntil: 'networkidle' });
        await page.waitForTimeout(3000); 

        onLog("Fetching the list of devices...");
        
        let allDeviceData = {};
        let processedSerials = new Set();
        
        while (true) {
             onLog("Scanning devices list...");
             await page.goto('https://app.oktopus.app.br/devices', { waitUntil: 'networkidle' });
             await page.waitForTimeout(4000); 
             
             const rows = await page.$$('tr');
             let rowToClick = null;
             let serialStr = "";
             
             for (const row of rows) {
                 const text = await row.innerText();
                 if (text.includes('Online')) {
                      const cells = await row.$$('td');
                      if (cells.length > 0) {
                          const serial = await cells[0].innerText();
                          if (!processedSerials.has(serial)) {
                               rowToClick = row;
                               serialStr = serial;
                               break;
                          }
                      }
                 }
             }
             
             if (!rowToClick) {
                 onLog("No more unprocessed online devices found.");
                 break; 
             }
             
             onLog(`Fetching data for device: ${serialStr}...`);
             processedSerials.add(serialStr);
             
             const accessBtn = await rowToClick.$('button[aria-label="Access the device"]');
             if (accessBtn) {
                 await accessBtn.click();
                 
                 // Explicitly wait for the URL to change to the device analysis dashboard
                 try {
                     await page.waitForURL('**/analysis', { timeout: 15000 });
                 } catch (e) {
                     onLog("  Timeout waiting for analysis page URL, proceeding anyway...");
                 }
                 await page.waitForTimeout(2000); 
                 
                 onLog("  Looking for Discovery tab...");
                 const tabs = await page.$$('.MuiTab-root');
                 for (const tab of tabs) {
                     try {
                         const tabText = await tab.innerText();
                         if (tabText.includes('Discovery')) {
                              await tab.click();
                              onLog("  Clicked Discovery tab, waiting for tree to load...");
                              await page.waitForTimeout(4000); 
                              break;
                         }
                     } catch(e) { 
                         onLog("  (Ignored stale tab element)"); 
                     }
                 }
             } else {
                 onLog(`  No access button found for ${serialStr}.`);
                 continue;
             }

            onLog(`  Extracting JSON data from UI...`);
            
            const deviceData = {};
            const clickedPaths = new Set();
            let previousScrollTop = -1;
            let finalScrollAttempts = 0;
            
            // Re-initialize prefix global just in case
            await page.evaluate(() => { window.TR369Prefix = "Device."; });

            while (true) {
                 // 1. EXTRACT DATA FIRST (to ensure we capture whatever is visible BEFORE any auto-scrolling)
                 const currentData = await page.evaluate(() => {
                      const data = {};
                      window.TR369Prefix = window.TR369Prefix || "Device.";
                      
                      const listItems = document.querySelectorAll('li.MuiListItem-root');
                      for (const li of listItems) {
                          const isFolder = li.querySelector('b') !== null;
                          if (isFolder) {
                              window.TR369Prefix = li.innerText.trim();
                          } else {
                              const keyEl = li.querySelector('.MuiListItemText-root');
                              const valEl = li.querySelector('.MuiListItemSecondaryAction-root');
                              if (keyEl) {
                                  let key = keyEl.innerText.trim();
                                  let val = "";
                                  if (valEl) {
                                      const clone = valEl.cloneNode(true);
                                      clone.querySelectorAll('button, svg').forEach(btn => btn.remove());
                                      val = clone.innerText.trim();
                                      if(val === '""') val = '';
                                      val = val.split('\n').map(v => v.trim()).filter(Boolean).join(' ');
                                  }
                                  
                                  if (key && !key.endsWith('()') && key !== 'Boot!' && !key.endsWith('.')) {
                                      let prefix = window.TR369Prefix;
                                      if (!prefix.endsWith('.')) prefix += '.';
                                      
                                      const fullKey = key.startsWith('Device.') ? key : (prefix + key);
                                      data[fullKey] = val;
                                  }
                              }
                          }
                      }
                      return data;
                 });
                 
                 // Accumulate
                 Object.assign(deviceData, currentData);

                 let clickedAnyOnScreen = false;
                 
                 // 2. Scan for unclicked folders currently STRICTLY visible in the viewport
                 const listItems = await page.$$('li.MuiListItem-root');
                 for (const li of listItems) {
                      const textContent = await li.innerText();
                      const lines = textContent.split('\n').map(l => l.trim()).filter(Boolean);
                      const title = lines[0]; 
                      
                      if (title && title.includes('Device.') && title.endsWith('.') && !clickedPaths.has(title)) {
                           const isVisible = await li.evaluate(node => {
                                const rect = node.getBoundingClientRect();
                                return rect.top >= 0 && rect.bottom <= (window.innerHeight || document.documentElement.clientHeight);
                           });
                           
                           if (isVisible) {
                                onLog(`    Expanding: ${title}`);
                                try {
                                    // Target chevron button if exists, otherwise click the body of the list item!
                                    const btn = await li.$('button');
                                    if (btn) {
                                        await btn.evaluate(node => node.click());
                                    } else {
                                        await li.evaluate(node => node.click());
                                    }
                                    await page.waitForTimeout(1200); // Wait for potential nested API fetches
                                    clickedPaths.add(title);
                                    clickedAnyOnScreen = true;
                                    break;
                                } catch(e) {
                                    clickedPaths.add(title); 
                                }
                           }
                      }
                 }
                 
                 // If we clicked a folder and injected new items, restart loop to extract them!
                 if (clickedAnyOnScreen) {
                      continue; 
                 }
                 
                 // 3. Scroll down exactly one 'page' of parameters safely
                 await page.evaluate(() => {
                      let maxScrollHeight = 0;
                      let targetContainer = null;
                      
                      // Find the single largest scrollable container in the entire DOM
                      document.querySelectorAll('*').forEach(c => {
                           if (c.scrollHeight > c.clientHeight && c.clientHeight > 0) {
                                // Exclude the literal body/html if there are internal scrolling divs
                                if (c !== document.body && c !== document.documentElement) {
                                     if (c.scrollHeight > maxScrollHeight) {
                                          maxScrollHeight = c.scrollHeight;
                                          targetContainer = c;
                                     }
                                }
                           }
                      });
                      
                      if (targetContainer) {
                          targetContainer.scrollBy({ top: 400, behavior: 'instant' });
                          window.___activeScrollContainer = targetContainer; // Cache for scrollTop check
                      } else {
                          window.scrollBy({ top: 400, behavior: 'instant' });
                      }
                 });
                 
                 await page.waitForTimeout(1000); // Safely wait for virtualized chunk loads
                 
                 // 4. Check if we hit the absolute bottom of the list
                 const currentScrollTop = await page.evaluate(() => {
                      if (window.___activeScrollContainer) {
                          return window.___activeScrollContainer.scrollTop;
                      }
                      return window.scrollY;
                 });
                 
                 if (currentScrollTop === previousScrollTop) {
                      finalScrollAttempts++;
                      // Increased retry limit dramatically for infinite scroll chunk loading pauses
                      if (finalScrollAttempts >= 8) {
                          onLog(`    Reached absolute bottom of tree. Exiting scan.`);
                          break;
                      }
                 } else {
                      finalScrollAttempts = 0;
                 }
                 previousScrollTop = currentScrollTop;
                 
                 // Artificial fail-safe limit just in case
                 if (Object.keys(deviceData).length > 20000) {
                      onLog("    Safety limit reached! Tree too large.");
                      break;
                 }
            }
            
            // Scroll back to top for cleanup
            await page.evaluate(() => {
                 document.querySelectorAll('.simplebar-content-wrapper').forEach(c => c.scrollTo(0,0));
                 window.scrollTo(0,0);
            });

            allDeviceData[serialStr] = deviceData;
            onLog(`  Extracted ${Object.keys(deviceData).length} parameters for ${serialStr}.`);
        }

        onLog("Saving results to output.json...");
        fs.writeFileSync('output.json', JSON.stringify(allDeviceData, null, 2));
        onLog("Done! Check output.json for the extracted data.");
        
        return allDeviceData;

    } catch (error) {
        onLog(`Error occurred during scraping: ${error.message}`);
        throw error;
    } finally {
        await browser.close();
    }
}

// Allow CLI execution
if (require.main === module) {
    const username = process.env.OKTOPUS_USER;
    const password = process.env.OKTOPUS_PASS;
    const headless = process.env.HEADLESS !== 'false';
    runScraper(username, password, headless).catch(console.error);
}

module.exports = { runScraper };
