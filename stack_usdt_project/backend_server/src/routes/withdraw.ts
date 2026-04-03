import { Router } from 'express';
import { db } from '../services/supabase';

const router = Router();

// POST /api/withdraw - Solicitar retiro
router.post('/', async (req, res) => {
  try {
    const { user_id, amount, wallet_address, network } = req.body;

    if (!user_id || !amount || !wallet_address) {
      return res.status(400).json({ 
        error: 'user_id, amount, and wallet_address are required' 
      });
    }

    const user = await db.getUserById(user_id);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    if (user.is_banned) {
      return res.status(403).json({ error: 'User is banned' });
    }

    const minWithdrawal = parseFloat(await db.getConfig('min_withdrawal') || '10.0');
    const maxWithdrawal = parseFloat(await db.getConfig('max_withdrawal') || '10000.0');

    if (amount < minWithdrawal) {
      return res.status(400).json({ 
        error: `Minimum withdrawal is ${minWithdrawal} USDT` 
      });
    }

    if (amount > maxWithdrawal) {
      return res.status(400).json({ 
        error: `Maximum withdrawal is ${maxWithdrawal} USDT` 
      });
    }

    if (user.usdt_balance < amount) {
      return res.status(400).json({ 
        error: 'Insufficient balance',
        available: user.usdt_balance,
        requested: amount
      });
    }

    if (wallet_address.length < 20 || wallet_address.length > 44) {
      return res.status(400).json({ 
        error: 'Invalid wallet address format' 
      });
    }

    const withdrawal = await db.createWithdrawal(
      user_id,
      amount,
      wallet_address,
      network || 'TRC20'
    );

    await db.updateUserBalance(user_id, amount, 'subtract');

    res.json({
      success: true,
      withdrawal_id: withdrawal.id,
      amount: withdrawal.amount,
      fee: withdrawal.fee,
      net_amount: withdrawal.net_amount,
      status: withdrawal.status,
      message: 'Withdrawal request submitted successfully'
    });
  } catch (error) {
    console.error('Error processing withdrawal:', error);
    res.status(500).json({ error: 'Failed to process withdrawal' });
  }
});

// GET /api/withdraw/:id
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { user_id } = req.query;

    const { supabase } = await import('./../services/supabase');
    const { data: withdrawal, error } = await supabase
      .from('withdrawals')
      .select('*')
      .eq('id', id)
      .single();

    if (error || !withdrawal) {
      return res.status(404).json({ error: 'Withdrawal not found' });
    }

    if (user_id && withdrawal.user_id !== user_id) {
      return res.status(403).json({ error: 'Access denied' });
    }

    res.json({ success: true, withdrawal });
  } catch (error) {
    console.error('Error fetching withdrawal:', error);
    res.status(500).json({ error: 'Failed to fetch withdrawal' });
  }
});

// GET /api/withdraw/user/:userId
router.get('/user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const limit = parseInt(req.query.limit as string) || 20;

    const { supabase } = await import('./../services/supabase');
    const { data: withdrawals, error } = await supabase
      .from('withdrawals')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .limit(limit);

    if (error) throw error;

    res.json({ success: true, withdrawals: withdrawals || [] });
  } catch (error) {
    console.error('Error fetching withdrawals:', error);
    res.status(500).json({ error: 'Failed to fetch withdrawals' });
  }
});

export default router;
