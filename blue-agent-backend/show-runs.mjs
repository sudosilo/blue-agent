// Prints the newest runs and their errors into the Railway log at startup.
import { createClient } from 'redis';
if (process.env.REDIS_URL) {
  try {
    const c = createClient({ url: process.env.REDIS_URL });
    await c.connect();
    const ids = await c.lRange('dq:runs', 0, 9);
    for (const id of ids) {
      const r = JSON.parse((await c.get('dq:run:' + id)) || '{}');
      const ev = await c.lRange('dq:run:' + id + ':events', -3, -1);
      console.log('RUN ' + id + ' ' + r.doctrine + ' ' + r.agentId + ' ' + r.model + ' ' + r.status + ' started ' + r.started + ' turns ' + r.turns + ' error ' + (r.error || 'none') + ' summary ' + String(r.summary || '').slice(0, 300));
      for (const e of ev) console.log('  EVENT ' + e.slice(0, 600));
    }
    await c.quit();
  } catch (e) { console.log('show-runs failed ' + e.message); }
}
