/**
 * A sliding window per caller, so one visitor cannot spend the whole budget.
 *
 * Deliberately in memory. An edge runtime keeps an instance alive between
 * requests from the same place for as long as there is traffic, which is
 * enough to stop a script hammering the endpoint — the case this is actually
 * for. It is not a distributed counter: each instance keeps its own tally, so
 * a determined caller spread across regions sees a looser limit than the
 * numbers below suggest. Moving the counts into durable storage is the upgrade
 * when that matters, and `server/README.md` says how.
 */
export class SlidingWindow {
  /**
   * @param {object} options
   * @param {number} options.limit    requests allowed inside the window
   * @param {number} options.windowMs length of the window
   * @param {() => number} [options.now]
   */
  constructor({ limit, windowMs, now = Date.now }) {
    this.limit = limit;
    this.windowMs = windowMs;
    this.now = now;
    /** @type {Map<string, number[]>} caller -> timestamps, oldest first */
    this._hits = new Map();
  }

  /**
   * Records one request and says whether it is allowed.
   *
   * @returns {{allowed: boolean, remaining: number, retryAfterSeconds: number}}
   */
  take(key) {
    const now = this.now();
    const cutoff = now - this.windowMs;

    const hits = (this._hits.get(key) ?? []).filter((at) => at > cutoff);

    if (hits.length >= this.limit) {
      this._hits.set(key, hits);
      const oldest = hits[0];
      return {
        allowed: false,
        remaining: 0,
        retryAfterSeconds: Math.max(1, Math.ceil((oldest + this.windowMs - now) / 1000)),
      };
    }

    hits.push(now);
    this._hits.set(key, hits);
    this._sweep(cutoff);
    return { allowed: true, remaining: this.limit - hits.length, retryAfterSeconds: 0 };
  }

  /**
   * Drops callers who have gone quiet, so the map cannot grow without end on
   * a long-lived instance.
   */
  _sweep(cutoff) {
    if (this._hits.size < 1000) return;
    for (const [key, hits] of this._hits) {
      if (hits.length === 0 || hits[hits.length - 1] <= cutoff) this._hits.delete(key);
    }
  }
}
