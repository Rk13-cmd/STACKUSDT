import { Request, Response, NextFunction } from 'express';

export function ipWhitelist(allowedIPs: string[]) {
  return (req: Request, res: Response, next: NextFunction) => {
    if (allowedIPs.length === 0) return next();

    const clientIP = req.ip || req.connection.remoteAddress || '';
    const normalizedIP = clientIP.replace('::ffff:', '');

    if (allowedIPs.includes(normalizedIP) || allowedIPs.includes(clientIP)) {
      return next();
    }

    console.warn(`[IP Whitelist] Blocked: ${normalizedIP} accessing ${req.path}`);
    res.status(403).json({ error: 'Access denied: IP not whitelisted' });
  };
}

export function ipWhitelistFromEnv() {
  const whitelistStr = process.env.ADMIN_IP_WHITELIST || '';
  const allowedIPs = whitelistStr
    .split(',')
    .map(ip => ip.trim())
    .filter(ip => ip.length > 0);

  return ipWhitelist(allowedIPs);
}
