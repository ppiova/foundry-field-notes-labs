const $ = id => document.getElementById(id);
const scenarios = {
  outage: 'The production portal has been unavailable to all users since 9:15 AM. Opening the dashboard returns error 500. We need access restored to continue operations.',
  access: 'I have been unable to sign in since this morning. After resetting my password, the login page returns to the initial screen without an error message.',
  billing: 'This month we received an invoice with two charges for the same subscription. Could you check for a duplicate charge and explain the details?',
  unknown: 'Something has not worked as expected since yesterday. Can you help me figure out what is happening?'
};
let current = null, runs = 0;
function invalidate() { current = null; $('result').hidden = true; $('empty').hidden = false; $('outputState').textContent = 'WAITING FOR INPUT'; $('error').hidden = true; }
function updateCount() { $('count').textContent = `${$('request').value.length} / 6,000`; }
$('request').value = scenarios.outage; updateCount();
document.querySelectorAll('[data-scenario]').forEach(button => button.addEventListener('click', () => {
  $('request').value = scenarios[button.dataset.scenario];
  document.querySelectorAll('[data-scenario]').forEach(b => b.classList.toggle('active', b === button));
  updateCount(); invalidate();
}));
$('request').addEventListener('input', () => { updateCount(); invalidate(); document.querySelectorAll('[data-scenario]').forEach(b => b.classList.remove('active')); });
$('mode').addEventListener('change', () => {
  invalidate(); const live = $('mode').value === 'foundry';
  $('modeTag').textContent = live ? 'AZURE USAGE' : 'NO CLOUD USAGE';
  $('inferenceOwner').textContent = live ? 'MICROSOFT FOUNDRY' : 'LOCAL SIMULATION';
  $('inferenceStep').textContent = live ? 'Model inference through MAF' : 'Deterministic rules, not a model';
  $('modeHelp').textContent = live ? 'Sends the text to your Foundry deployment through MAF. Charges may apply. Use synthetic data.' : 'Deterministic rules to explore the workflow. This mode does not use an AI model or run MAF.';
});
fetch('/api/status').then(r => { if (!r.ok) throw Error(); return r.json(); }).then(status => {
  if (status.foundryConfigured) { const option = $('mode').options[1]; option.disabled = false; option.textContent = 'Microsoft Foundry · MAF'; }
  $('mode').options[0].disabled = !status.simulationEnabled;
  $('mode').value = status.defaultMode;
  $('mode').dispatchEvent(new Event('change'));
  $('hosting').textContent = status.hosting;
  $('analyze').disabled = false;
}).catch(() => { $('error').textContent = 'Could not connect to the server. Restart the demo and reload the page.'; $('error').hidden = false; });
$('analyze').addEventListener('click', async () => {
  invalidate(); const text = $('request').value.trim();
  if (text.length < 15) { $('error').textContent = 'Enter at least 15 characters to analyze.'; $('error').hidden = false; return; }
  const controls = [$('analyze'), $('request'), $('mode'), ...document.querySelectorAll('[data-scenario]')];
  controls.forEach(x => x.disabled = true); $('analyze').textContent = 'Analyzing…'; $('outputState').textContent = 'RUNNING';
  try {
    const response = await fetch('/api/analyze', {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({text,mode:$('mode').value}), signal:AbortSignal.timeout(65000)});
    const data = await response.json().catch(() => ({error:'The server is busy or returned an invalid response.'}));
    if (!response.ok) throw Error(data.error || 'Could not complete the analysis.');
    current = {...data, input:text, reviewed:false}; runs++;
    const p = data.proposal;
    $('category').textContent = ({Access:'Access',Billing:'Billing',Reliability:'Reliability',General:'General'})[p.category];
    $('priority').textContent = `Priority ${{High:'high',Medium:'medium',Low:'low'}[p.priority]}`;
    $('summary').textContent = p.summary; $('evidence').textContent = p.evidence; $('nextStep').value = p.nextStep; $('reply').value = p.draftReply;
    $('timing').textContent = `${data.elapsedMs} ms · ${data.mode === 'simulation' ? 'simulation processing, not model latency' : 'application processing for this request, not a benchmark'}`;
    $('outputState').textContent = data.mode === 'simulation' ? 'SIMULATION · REVIEW' : 'FOUNDRY · REVIEW';
    $('resultSource').textContent = data.mode === 'simulation' ? 'Source: deterministic local simulation. No model or MAF ran.' : 'Source: Microsoft Foundry inference through MAF. Inspect the proposal before acting.';
    $('originalJson').textContent = JSON.stringify({input:text, ...data}, null, 2);
    $('empty').hidden = true; $('result').hidden = false; $('approve').disabled = false; $('approve').textContent = 'Approve proposal ✓';
    $('reviewStatus').textContent = 'Awaiting human review.';
    $('runLabel').textContent = `${runs} completed run${runs === 1 ? '' : 's'}`;
    $('runDetail').textContent = `${data.model} · ${data.elapsedMs} ms · No messages sent`;
  } catch (error) { $('error').textContent = error.name === 'TimeoutError' ? 'The request timed out. Please try again.' : error.message; $('error').hidden = false; $('outputState').textContent = 'ERROR · RETRY'; }
  finally { controls.forEach(x => x.disabled = false); $('analyze').textContent = 'Analyze request ↗'; }
});
function unapprove() { if (!current) return; current.reviewed = false; delete current.reviewedAt; $('approve').disabled = false; $('approve').textContent = 'Approve proposal ✓'; $('reviewStatus').textContent = 'Proposal edited: review is required again.'; }
['nextStep','reply'].forEach(id => $(id).addEventListener('input', unapprove));
$('approve').addEventListener('click', () => {
  if (!current) return;
  if (!$('nextStep').value.trim() || !$('reply').value.trim()) { $('reviewStatus').textContent = 'The next step and draft response cannot be empty.'; return; }
  current.reviewed = true; current.reviewedAt = new Date().toISOString(); $('approve').disabled = true; $('approve').textContent = 'Reviewed ✓'; $('reviewStatus').textContent = 'Approved locally. No message was sent and no action was executed.';
});
$('export').addEventListener('click', () => {
  if (!current) return;
  const exported = {...current, humanEdits:{nextStep:$('nextStep').value,draftReply:$('reply').value}, exportedAt:new Date().toISOString()};
  const url = URL.createObjectURL(new Blob([JSON.stringify(exported,null,2)],{type:'application/json'}));
  const a = document.createElement('a'); a.href = url; a.download = `support-signal-${current.id}.json`; a.click(); setTimeout(() => URL.revokeObjectURL(url),1000);
});
$('aboutButton').addEventListener('click', () => $('about').showModal());
$('closeAbout').addEventListener('click', () => $('about').close());
