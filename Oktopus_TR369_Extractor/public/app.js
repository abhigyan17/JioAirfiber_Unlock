document.addEventListener('DOMContentLoaded', () => {
    const startBtn = document.getElementById('startBtn');
    const downloadBtn = document.getElementById('downloadBtn');
    const usernameInput = document.getElementById('username');
    const passwordInput = document.getElementById('password');
    const headlessInput = document.getElementById('headless');
    const terminal = document.getElementById('terminal');

    let eventSource = null;

    function appendLog(text, type = 'normal') {
        const line = document.createElement('div');
        line.textContent = `> ${text}`;
        if (type !== 'normal') line.classList.add(type);
        terminal.appendChild(line);
        terminal.scrollTop = terminal.scrollHeight;
    }

    startBtn.addEventListener('click', () => {
        const username = usernameInput.value.trim();
        const password = passwordInput.value.trim();
        const headless = headlessInput.checked;

        if (!username || !password) {
            alert('Please enter both username and password.');
            return;
        }

        // Reset UI
        terminal.innerHTML = '';
        startBtn.disabled = true;
        startBtn.textContent = 'Extracting...';
        downloadBtn.style.display = 'none';

        appendLog('Initializing environment...', 'system');

        const params = new URLSearchParams({ username, password, headless: headless.toString() });
        const url = `/api/scrape?${params.toString()}`;

        eventSource = new EventSource(url);

        eventSource.onmessage = (event) => {
            if (event.data === 'DONE') {
                eventSource.close();
                startBtn.disabled = false;
                startBtn.textContent = 'Start Extraction';
                downloadBtn.style.display = 'inline-block';
                appendLog('Extraction complete! File ready for download.', 'system');
            } else if (event.data.startsWith('ERROR:')) {
                appendLog(event.data, 'error');
            } else {
                appendLog(event.data);
            }
        };

        eventSource.onerror = (err) => {
            console.error('SSE Error:', err);
            eventSource.close();
            startBtn.disabled = false;
            startBtn.textContent = 'Start Extraction';
            appendLog('Connection to backend lost.', 'error');
        };
    });
});
