// Prints the newest runs and their errors into the Railway log at startup.
// RUN_NOW=violet (comma separated, any value change counts as a new request) makes those agents play again right after startup.
import { createClient } from 'redis';
if (process.env.REDIS_URL) {
  try {
    const c = createClient({ url: process.env.REDIS_URL });
    await c.connect();
    const ids = await c.lRange('dq:runs', 0, 9);
    for (const id of ids) {
      const r = JSON.parse((await c.get('dq:run:' + id)) || '{}');
      console.log('RUN ' + id + ' ' + r.doctrine + ' ' + r.agentId + ' ' + r.model + ' ' + r.status + ' started ' + r.started + ' turns ' + r.turns + ' error ' + String(r.error || 'none').slice(0, 200) + ' summary ' + String(r.summary || '').slice(0, 300));
    }
    const now = String(process.env.RUN_NOW || '').trim();
    if (now && !(await c.get('dq:runnow:' + now))) {
      await c.set('dq:runnow:' + now, new Date().toISOString());
      for (const slug of now.split(',').map(s => s.trim()).filter(Boolean)) {
        for (const k of await c.keys('dq:lastauto:*')) if (k === 'dq:lastauto:' + slug || k.startsWith('dq:lastauto:dq-' + slug + '-')) { await c.del(k); console.log('RUN_NOW cleared ' + k); }
      }
    }
    await c.quit();
  } catch (e) { console.log('show-runs failed ' + e.message); }
}
