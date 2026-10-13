const fs = require('node:fs');
const [command, file, unit, phase] = process.argv.slice(2);
function label(actions, completed) {
  const key = actions.join(',');
  if (actions.includes('create') && actions.includes('delete')) return completed ? 'Replaced' : 'Exists — will replace';
  return ({
    'no-op': 'Already exists — unchanged',
    create: completed ? 'Created' : 'Not in state — will create',
    update: completed ? 'Updated' : 'Exists — will update',
    delete: completed ? 'Deleted' : 'Exists — will delete',
    read: completed ? 'Read' : 'Will read',
    forget: completed ? 'Removed from state' : 'Will remove from state',
  })[key] || key;
}
if (command === 'capture') {
  let input = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', chunk => { input += chunk; });
  process.stdin.on('end', () => {
    const plan = JSON.parse(input);
    // Keep addresses/actions only; exclude values, passwords and credentials.
    const changes = (plan.resource_changes || []).map(r => ({
      address: r.address,
      name: r.change.after_sensitive?.name || r.change.before_sensitive?.name ? '' : (r.change.after?.name || r.change.before?.name || ''),
      actions: r.change.actions,
    }));
    fs.writeFileSync(file, JSON.stringify(changes));
  });
} else if (command === 'report') {
  const changes = JSON.parse(fs.readFileSync(file, 'utf8'));
  const escape = value => String(value).replace(/[|\r\n]/g, ' ');
  let report = `#### ${escape(unit)}: ${phase === 'plan' ? 'Plan details' : 'Execution details'}\n\n`;
  if (phase === 'failed') {
    report += 'Execution failed and may have completed some changes. Resource outcomes are unconfirmed; run a fresh plan to reconcile state.\n\n';
  }
  report += '| Terraform resource | Azure name | Status |\n|---|---|---|\n';
  for (const r of changes) {
    const status = phase === 'failed' ? 'Unconfirmed — planned: ' + label(r.actions, false) : label(r.actions, phase === 'completed');
    report += `| ${escape(r.address)} | ${escape(r.name || '—')} | ${escape(status)} |\n`;
  }
  if (!changes.length) report += '| — | — | No resource changes or existing resources reported |\n';
  console.log(report);
  if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, report + '\n');
} else {
  throw new Error('Specify capture or report');
}
