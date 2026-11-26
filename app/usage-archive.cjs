const fs = require('node:fs/promises');
const path = require('node:path');
const os = require('node:os');
const { createHash, randomUUID } = require('node:crypto');
const { Analytics } = require('./analytics.cjs');

function archivePath(codexHome) {
  const identity = path.resolve(codexHome);
  const key = createHash('sha256').update(process.platform === 'win32' ? identity.toLowerCase() : identity).digest('hex').slice(0, 16);
  const localDirectory = process.env.LOCALAPPDATA || path.join(os.homedir(), '.local', 'share');
  return process.env.CODEX_USAGE_ARCHIVE || path.join(localDirectory, 'CodexUsageMonitor', `usage-history-${key}.json`);
}

class UsageArchive {
  constructor(file) {
    this.file = file;
    this.analytics = new Analytics();
    this.metadata = new Map();
    this.seen = new Set();
    this.dirty = false;
  }

  async load() {
    let saved;
    try {
      saved = JSON.parse(await fs.readFile(this.file, 'utf8'));
    } catch (error) {
      if (error.code === 'ENOENT') return;
      throw error;
    }
    if (saved?.version !== 1) throw new Error('Unsupported usage archive version');
    const days = new Map(saved.days.map(([date, rows]) => [date, new Map(rows)]));
    const metadata = new Map(saved.sessions);
    const seen = new Set(saved.seen);
    this.analytics.days = days;
    this.analytics.recoveredDays = new Map(saved.recoveredDays || []);
    this.metadata = metadata;
    this.seen = seen;
  }

  add(event, sessionId, totalTokens) {
    // A replayed or moved log retains its session, timestamp and cumulative counter.
    const id = createHash('sha256')
      .update(JSON.stringify([sessionId, event.at, totalTokens]))
      .digest('base64url');
    if (this.seen.has(id)) return;
    this.analytics.add(event, sessionId);
    this.seen.add(id);
    this.dirty = true;
  }

  updateSession(id, title, model) {
    const previous = this.metadata.get(id);
    const next = { title: title || previous?.title, model: model || previous?.model };
    if (next.title === previous?.title && next.model === previous?.model) return;
    this.metadata.set(id, next);
    this.dirty = true;
  }

  recoverDaily(rows) {
    for (const row of rows) {
      const current = this.analytics.days.get(row.date);
      const recorded = [...(current?.values() || [])].reduce((sum, value) => sum + value.total_tokens, 0);
      const previous = this.analytics.recoveredDays.get(row.date);
      if (row.total_tokens <= Math.max(recorded, previous?.total_tokens || 0)) continue;
      this.analytics.recoveredDays.set(row.date, row);
      this.dirty = true;
    }
  }

  async save() {
    if (!this.dirty) return;
    const body = JSON.stringify({
      version: 1,
      days: [...this.analytics.days].map(([date, rows]) => [date, [...rows]]),
      recoveredDays: [...this.analytics.recoveredDays],
      sessions: [...this.metadata],
      seen: [...this.seen],
    });
    await fs.mkdir(path.dirname(this.file), { recursive: true });
    const temporary = `${this.file}.${randomUUID()}.tmp`;
    try {
      await fs.writeFile(temporary, body, { flag: 'wx', mode: 0o600 });
      await fs.rename(temporary, this.file);
      this.dirty = false;
    } finally {
      await fs.rm(temporary, { force: true }).catch(() => {});
    }
  }
}

module.exports = { UsageArchive, archivePath };
