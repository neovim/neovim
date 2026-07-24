const statusEl = document.getElementById('status');
const logEl = document.getElementById('log');
const setStatus = s => statusEl.textContent = s;
const log = (...args) => {
  logEl.textContent += args.map(a => typeof a === 'string' ? a : JSON.stringify(a)).join(' ') + '\n';
  console.log(...args);
};

if (!crossOriginIsolated) {
  setStatus('NOT cross-origin isolated -- SharedArrayBuffer unavailable. Serve with COOP/COEP headers.');
} else {
  main();
}

function main() {
  const transport = new WorkerTransport('nvim-worker.js', { cols: 80, rows: 24 });
  transport.onStatus(text => { setStatus(text); log('[status]', text); });

  const nvim = new RpcClient(transport);
  setTimeout(async () => {
    console.log("Auto Request");

    try {
        const r = await nvim.request("nvim_get_api_info", []);
        console.log(r);
    } catch (e) {
        console.error(e);
    }
}, 10000);

  nvim.on('redraw', params => log('Notification redraw', params));

  document.getElementById('apiInfoBtn').addEventListener('click', async () => {
    setStatus('sending nvim_get_api_info...');
    try {
      const result = await nvim.request('nvim_get_api_info', []);
      log('RESPONSE nvim_get_api_info ->', result);
      setStatus('got nvim_get_api_info response');
    } catch (e) {
      log('ERROR nvim_get_api_info ->', e);
      setStatus('nvim_get_api_info failed, see log');
    }
  });

  document.getElementById('attachBtn').addEventListener('click', async () => {
    setStatus('sending nvim_ui_attach...');
    try {
      const result = await nvim.request('nvim_ui_attach', [80, 24, { rgb: true, ext_linegrid: true }]);
      log('RESPONSE nvim_ui_attach ->', result);
      setStatus('UI attached finally. Watching for redraw notifications...');
    } catch (e) {
      log('ERROR nvim_ui_attach ->', e);
      setStatus('nvim_ui_attach failed, see log');
    }
  });

  document.getElementById('persistBtn').addEventListener('click', () => {
    transport.persist();
  });
}
