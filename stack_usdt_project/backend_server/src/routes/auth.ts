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

// POST /api/auth/register
router.post('/register', async (req, res) => {
  try {
    const { email, password, username } = req.body;

    if (!email || !password || !username) {
      return res.status(400).json({ 
        error: 'email, password, and username are required' 
      });
    }

    if (password.length < 6) {
      return res.status(400).json({ 
        error: 'Password must be at least 6 characters' 
      });
    }

    if (username.length < 3) {
      return res.status(400).json({ 
        error: 'Username must be at least 3 characters' 
      });
    }

    // Check if user already exists in our users table
    const existingUser = await db.getUserByEmail(email);
    if (existingUser) {
      return res.status(409).json({ error: 'Email already registered' });
    }

    // Create user in Supabase Auth
    const supabase = getSupabaseAdmin();
    const { data: authData, error: authError } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { username }
    });

    if (authError) {
      if (authError.message.includes('already registered')) {
        return res.status(409).json({ error: 'Email already registered' });
      }
      return res.status(400).json({ error: authError.message });
    }

    // Generate referral code
    const referralCode = 'STK' + Math.random().toString(36).substring(2, 8).toUpperCase();

    // Create user profile in users table
    const { error: dbError } = await supabase
      .from('users')
      .insert([{
        id: authData.user.id,
        email,
        username,
        usdt_balance: 0,
        total_earned: 0,
        total_withdrawn: 0,
        referral_code: referralCode,
        is_banned: false
      }] as any);

    if (dbError) {
      // Rollback auth user if db insert fails
      await supabase.auth.admin.deleteUser(authData.user.id);
      return res.status(500).json({ error: 'Failed to create user profile' });
    }

    // Get the created user
    const user = await db.getUserById(authData.user.id);

    res.json({
      success: true,
      message: 'Registration successful',
      user: {
        id: user?.id,
        email: user?.email,
        username: user?.username,
        usdt_balance: user?.usdt_balance,
        referral_code: user?.referral_code
      }
    });
  } catch (error: any) {
    console.error('Registration error:', error);
    res.status(500).json({ error: 'Registration failed' });
  }
});

// POST /api/auth/login
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ 
        error: 'email and password are required' 
      });
    }

    // Authenticate with Supabase
    const supabase = getSupabaseAdmin();
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email,
      password
    });

    if (authError) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    // Get user profile
    const user = await db.getUserById(authData.user.id);
    
    if (!user) {
      return res.status(404).json({ error: 'User profile not found' });
    }

    if (user.is_banned) {
      return res.status(403).json({ error: 'Account is banned. Contact support.' });
    }

    res.json({
      success: true,
      message: 'Login successful',
      token: authData.session?.access_token,
      user: {
        id: user.id,
        email: user.email,
        username: user.username,
        usdt_balance: user.usdt_balance,
        total_earned: user.total_earned,
        total_withdrawn: user.total_withdrawn,
        referral_code: user.referral_code,
        wallet_address: user.wallet_address,
        mining_xp: user.mining_xp || 0,
        mining_level: user.mining_level || 1,
        active_skin_id: user.active_skin_id,
        is_admin: user.is_admin || false,
      }
    });
  } catch (error: any) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Login failed' });
  }
});

// GET /api/auth/profile/:userId
router.get('/profile/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const user = await db.getUserById(userId);
    
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    let activeSkin = null;
    if (user.active_skin_id) {
      activeSkin = await db.getSkinById(user.active_skin_id);
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
        referral_code: user.referral_code,
        wallet_address: user.wallet_address,
        mining_xp: user.mining_xp || 0,
        mining_level: user.mining_level || 1,
        active_skin_id: user.active_skin_id,
        active_skin: activeSkin,
      }
    });
  } catch (error: any) {
    console.error('Profile error:', error);
    res.status(500).json({ error: 'Failed to fetch profile' });
  }
});

// PUT /api/auth/profile/:userId
router.put('/profile/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const { username, wallet_address } = req.body;

    const user = await db.getUserById(userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const updates: Record<string, any> = {};
    if (username && username !== user.username) {
      updates.username = username;
    }
    if (wallet_address !== undefined) {
      updates.wallet_address = wallet_address;
    }

    if (Object.keys(updates).length > 0) {
      const supabase = getSupabaseAdmin();
      const { error } = await supabase
        .from('users')
        .update(updates)
        .eq('id', userId);

      if (error) {
        return res.status(500).json({ error: 'Failed to update profile' });
      }
    }

    const updatedUser = await db.getUserById(userId);
    res.json({
      success: true,
      user: {
        id: updatedUser?.id,
        email: updatedUser?.email,
        username: updatedUser?.username,
        wallet_address: updatedUser?.wallet_address
      }
    });
  } catch (error: any) {
    console.error('Update profile error:', error);
    res.status(500).json({ error: 'Failed to update profile' });
  }
});

// POST /api/auth/logout
router.post('/logout', async (req, res) => {
  try {
    const { token } = req.body;
    if (token) {
      const supabase = getSupabaseAdmin();
      await supabase.auth.admin.signOut(token);
    }
    res.json({ success: true, message: 'Logged out' });
  } catch (error: any) {
    console.error('Logout error:', error);
    res.status(500).json({ error: 'Logout failed' });
  }
});

export default router;
