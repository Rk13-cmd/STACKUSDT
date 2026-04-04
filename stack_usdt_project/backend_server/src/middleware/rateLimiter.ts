import { Request, Response, NextFunction } from 'express';

interface RateLimitEntry {
  count: number;
  firstRequest: number;
  resetAt: number;
}

class RateLimiter {
  private limits: Map<string, RateLimitEntry> = new Map();
  private cleanupInterval: NodeJS.Timeout;

  constructor() {
    this.cleanupInterval = setInterval(() => this.cleanup(), 60 * 60 * 1000);
  }

  limit(maxRequests: number, windowMs: number) {
    return (req: Request, res: Response, next: NextFunction) => {
      const key = this.getKey(req);
      const now = Date.now();
      let entry = this.limits.get(key);

      if (!entry || now > entry.resetAt) {
        entry = { count: 1, firstRequest: now, resetAt: now + windowMs };
        this.limits.set(key, entry);
        return next();
      }

      entry.count++;

      if (entry.count > maxRequests) {
        const retryAfter = Math.ceil((entry.resetAt - now) / 1000);
        res.set('Retry-After', retryAfter.toString());
        res.set('X-RateLimit-Limit', maxRequests.toString());
        res.set('X-RateLimit-Remaining', '0');
        return res.status(429).json({
          error: 'Too many requests',
          retry_after: retryAfter,
        });
      }

      res.set('X-RateLimit-Limit', maxRequests.toString());
      res.set('X-RateLimit-Remaining', (maxRequests - entry.count).toString());
      next();
    };
  }

  private getKey(req: Request): string {
    const ip = req.ip || req.connection.remoteAddress || 'unknown';
    return `${ip}:${req.path}`;
  }

  private cleanup() {
    const now = Date.now();
    for (const [key, entry] of this.limits.entries()) {
      if (now > entry.resetAt) {
        this.limits.delete(key);
      }
    }
  }

  destroy() {
    clearInterval(this.cleanupInterval);
  }
}

export const rateLimiter = new RateLimiter();

export const rateLimits = {
  auth: rateLimiter.limit(10, 15 * 60 * 1000),
  deposit: rateLimiter.limit(5, 5 * 60 * 1000),
  withdraw: rateLimiter.limit(3, 10 * 60 * 1000),
  game: rateLimiter.limit(60, 60 * 1000),
  api: rateLimiter.limit(100, 60 * 1000),
};
