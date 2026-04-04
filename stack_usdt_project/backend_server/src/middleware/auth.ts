import { Request, Response, NextFunction } from 'express';
import { createClient } from '@supabase/supabase-js';
import { db } from '../services/supabase';

export async function requireAdmin(req: Request, res: Response, next: NextFunction) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    const token = authHeader.split('Bearer ')[1];
    const supabaseUrl = process.env.SUPABASE_URL!;
    const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return res.status(401).json({ error: 'Invalid or expired token' });
    }

    const profile = await db.getUserById(user.id);
    if (!profile) {
      return res.status(403).json({ error: 'User profile not found' });
    }

    if (!profile.is_admin) {
      await db.createNotification(
        user.id,
        'security_alert',
        'Unauthorized Admin Access Attempt',
        `Your account attempted to access admin endpoints. If this was not you, contact support immediately.`
      );
      return res.status(403).json({ error: 'Admin access required' });
    }

    if (profile.is_banned) {
      return res.status(403).json({ error: 'Account is banned' });
    }

    (req as any).adminUser = profile;
    (req as any).adminUserId = user.id;

    if (!process.env.NO_ADMIN_AUDIT) {
      await db.createAuditLog(
        user.id,
        'admin_access',
        'endpoint',
        req.path,
        { method: req.method, ip: req.ip, userAgent: req.headers['user-agent'] },
        req.ip || 'unknown'
      );
    }

    next();
  } catch (error: any) {
    console.error('Admin middleware error:', error.message);
    res.status(500).json({ error: 'Authentication service error' });
  }
}

export async function optionalAuth(req: Request, res: Response, next: NextFunction) {
  try {
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.split('Bearer ')[1];
      const supabaseUrl = process.env.SUPABASE_URL!;
      const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;
      const supabase = createClient(supabaseUrl, supabaseKey);

      const { data: { user } } = await supabase.auth.getUser(token);
      if (user) {
        (req as any).user = user;
        (req as any).userId = user.id;
      }
    }
    next();
  } catch {
    next();
  }
}
