import { Router } from 'express';
import { createClient } from '@supabase/supabase-js';
import { db } from '../services/supabase';

const router = Router();

function getSupabaseAdmin() {
  return createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  );
}

// GET /api/user/all - Get all users (admin only)
router.get('/all', async (req, res) => {
  try {
    const supabase = getSupabaseAdmin();
    const { data: users, error } = await supabase
      .from('users')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) throw error;

    res.json({
      success: true,
      users: users || [],
    });
  } catch (error: any) {
    console.error('Error fetching users:', error);
    res.status(500).json({ error: 'Failed to fetch users' });
  }
});

// GET /api/user/:id - Obtener perfil de usuario
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const user = await db.getUserById(id);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({
      success: true,
      user: {
        id: user.id,
        email: user.email,
        username: user.username,
        usdt_balance: user.usdt_balance,
        total_earned: user.total_earned,
        total_withdrawn: user.total_withdrawn,
        created_at: user.created_at,
        is_banned: user.is_banned,
        referral_code: user.referral_code
      }
    });
  } catch (error) {
    console.error('Error fetching user:', error);
    res.status(500).json({ error: 'Failed to fetch user' });
  }
});

// GET /api/user/:id/balance - Obtener balance de usuario
router.get('/:id/balance', async (req, res) => {
  try {
    const { id } = req.params;

    const user = await db.getUserById(id);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({
      success: true,
      usdt_balance: user.usdt_balance,
      total_earned: user.total_earned,
      total_withdrawn: user.total_withdrawn
    });
  } catch (error) {
    console.error('Error fetching balance:', error);
    res.status(500).json({ error: 'Failed to fetch balance' });
  }
});

// POST /api/user/create - Crear usuario (para testing)
router.post('/create', async (req, res) => {
  try {
    const { email, username } = req.body;

    if (!email) {
      return res.status(400).json({ error: 'email is required' });
    }

    const existingUser = await db.getUserByEmail(email);
    if (existingUser) {
      return res.status(409).json({ error: 'User already exists' });
    }

    res.status(501).json({ 
      error: 'User creation not implemented. Use Supabase Auth.',
      message: 'Use Supabase Dashboard or Auth to create users'
    });
  } catch (error) {
    console.error('Error creating user:', error);
    res.status(500).json({ error: 'Failed to create user' });
  }
});

// PUT /api/user/:userId/ban - Ban/unban user (admin)
router.put('/:userId/ban', async (req, res) => {
  try {
    const { userId } = req.params;
    const { is_banned } = req.body;

    const user = await db.getUserById(userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    await db.setAdminStatus(userId, is_banned);

    res.json({
      success: true,
      message: `User ${is_banned ? 'banned' : 'unbanned'} successfully`,
    });
  } catch (error: any) {
    console.error('Error banning user:', error);
    res.status(500).json({ error: 'Failed to update user status' });
  }
});

export default router;
