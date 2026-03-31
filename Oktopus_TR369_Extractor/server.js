const express = require('express');
const path = require('path');
const { runScraper } = require('./fetch_devices');
const fs = require('fs');

const app = express();
const PORT = 3000;

app.use(express.static(path.join(__dirname, 'public')));
app.use(express.json());

// SSE endpoint
app.get('/api/scrape', async (req, res) => {
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');

    const username = req.query.username;
    const password = req.query.password;
    const headless = req.query.headless !== 'false';

    if (!username || !password) {
        res.write(`data: Error: Username from UI is missing.\n\n`);
        return res.end();
    }

    const onLog = (msg) => {
        res.write(`data: ${msg}\n\n`);
    };

    try {
        await runScraper(username, password, headless, onLog);
        res.write(`data: DONE\n\n`);
    } catch (e) {
        res.write(`data: ERROR: ${e.message}\n\n`);
        res.write(`data: DONE\n\n`);
    }

    res.end();
});

// Download endpoint
app.get('/api/download', (req, res) => {
    const file = path.join(__dirname, 'output.json');
    if (fs.existsSync(file)) {
        res.setHeader('Content-disposition', 'attachment; filename=output.json');
        res.setHeader('Content-type', 'application/json');
        const filestream = fs.createReadStream(file);
        filestream.pipe(res);
    } else {
        res.status(404).send('output.json not found. Run scraper first.');
    }
});

app.listen(PORT, () => {
    console.log(`GUI Server running on http://localhost:${PORT}`);
    import('open').then(open => open.default(`http://localhost:${PORT}`)).catch(err => console.error("Failed to open browser:", err));
});
