import { Router } from 'express';
import { db } from '../services/supabase';
import { requireAdmin } from '../middleware/auth';
import { ipWhitelistFromEnv } from '../middleware/ipWhitelist';
import { nowPaymentsStats } from '../services/nowPaymentsStats';
import { paymentSync } from '../services/paymentSync';

const router = Router();

router.use(ipWhitelistFromEnv());
router.use(requireAdmin);

// GET /api/admin/financial-stats - Enhanced stats
router.get('/financial-stats', async (req, res) => {
  try {
    const stats = await db.getFinancialStatsEnhanced();
    res.json({ success: true, stats });
  } catch (error: any) {
    console.error('Error fetching financial stats:', error);
    res.status(500).json({ error: 'Failed to fetch stats' });
  }
});

// GET /api/admin/revenue-chart - Daily revenue data
router.get('/revenue-chart', async (req, res) => {
  try {
    const days = parseInt(req.query.days as string) || 30;
    const data = await db.getRevenueByPeriod(days);
    res.json({ success: true, data });
  } catch (error: any) {
    console.error('Error fetching revenue chart:', error);
    res.status(500).json({ error: 'Failed to fetch revenue data' });
  }
});

// GET /api/admin/nowpayments-stats - Real NOWPayments API stats
router.get('/nowpayments-stats', async (req, res) => {
  try {
    const stats = await nowPaymentsStats.getPaymentStats();
    res.json({ success: true, stats });
  } catch (error: any) {
    console.error('Error fetching NOWPayments stats:', error);
    res.status(500).json({ 
      error: 'Failed to fetch NOWPayments stats',
      details: error.message 
    });
  }
});

// GET /api/admin/nowpayments/currencies
router.get('/nowpayments/currencies', async (req, res) => {
  try {
    const currencies = await nowPaymentsStats.getCurrencies();
    res.json({ success: true, currencies });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to fetch currencies' });
  }
});

// POST /api/admin/payments/sync - Manual sync of pending payments
router.post('/payments/sync', async (req, res) => {
  try {
    const result = await paymentSync.syncPendingPayments();
    res.json({ success: true, result });
  } catch (error: any) {
    console.error('Error syncing payments:', error);
    res.status(500).json({ error: 'Failed to sync payments' });
  }
});

// GET /api/admin/payments/stuck - Payments stuck > N hours
router.get('/payments/stuck', async (req, res) => {
  try {
    const hours = parseInt(req.query.hours as string) || 1;
    const stuck = await paymentSync.getStuckPayments(hours);
    res.json({ success: true, stuck });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to fetch stuck payments' });
  }
});

// GET /api/admin/withdraw/pending
router.get('/withdraw/pending', async (req, res) => {
  try {
    const withdrawals = await db.getPendingWithdrawals();
    res.json({ success: true, withdrawals });
  } catch (error: any) {
    console.error('Error fetching pending withdrawals:', error);
    res.status(500).json({ error: 'Failed to fetch pending withdrawals' });
  }
});

// GET /api/admin/withdraw/all
router.get('/withdraw/all', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit as string) || 100;
    const withdrawals = await db.getAllWithdrawals(limit);
    res.json({ success: true, withdrawals });
  } catch (error: any) {
    console.error('Error fetching withdrawals:', error);
    res.status(500).json({ error: 'Failed to fetch withdrawals' });
  }
});

// PUT /api/admin/withdraw/:id/approve
router.put('/withdraw/:id/approve', async (req, res) => {
  try {
    const { id } = req.params;
    const { admin_notes, tx_hash } = req.body;
    const adminUserId = (req as any).adminUserId;

    await db.updateWithdrawalStatus(id, 'completed', admin_notes, tx_hash);

    const withdrawal = await db.getWithdrawalById(id);
    if (withdrawal) {
      await db.createNotification(
        withdrawal.user_id,
        'withdrawal_approved',
        'Withdrawal Processed',
        `Your withdrawal of $${parseFloat(withdrawal.amount).toFixed(2)} USDT has been processed and sent to your wallet.${tx_hash ? ` TX: ${tx_hash}` : ''}`
      );

      await db.createAuditLog(
        adminUserId,
        'withdrawal_approved',
        'withdrawal',
        id,
        { amount: withdrawal.amount, tx_hash, admin_notes },
        req.ip || 'unknown'
      );
    }

    res.json({ success: true, message: 'Withdrawal approved' });
  } catch (error: any) {
    console.error('Error approving withdrawal:', error);
    res.status(500).json({ error: 'Failed to approve withdrawal' });
  }
});

// PUT /api/admin/withdraw/:id/reject
router.put('/withdraw/:id/reject', async (req, res) => {
  try {
    const { id } = req.params;
    const { reason } = req.body;
    const adminUserId = (req as any).adminUserId;

    if (!reason) {
      return res.status(400).json({ error: 'Rejection reason is required' });
    }

    const withdrawal = await db.getWithdrawalById(id);
    if (!withdrawal) {
      return res.status(404).json({ error: 'Withdrawal not found' });
    }

    await db.updateWithdrawalStatus(id, 'rejected', reason);
    await db.updateUserBalance(withdrawal.user_id, parseFloat(withdrawal.amount), 'add');

    await db.createNotification(
      withdrawal.user_id,
      'withdrawal_rejected',
      'Withdrawal Rejected',
      `Your withdrawal of $${parseFloat(withdrawal.amount).toFixed(2)} USDT was rejected. Reason: ${reason}. The amount has been returned to your balance.`
    );

    await db.createAuditLog(
      adminUserId,
      'withdrawal_rejected',
      'withdrawal',
      id,
      { amount: withdrawal.amount, reason },
      req.ip || 'unknown'
    );

    res.json({ success: true, message: 'Withdrawal rejected and refunded' });
  } catch (error: any) {
    console.error('Error rejecting withdrawal:', error);
    res.status(500).json({ error: 'Failed to reject withdrawal' });
  }
});

// GET /api/admin/users/:id/full-profile
router.get('/users/:id/full-profile', async (req, res) => {
  try {
    const userId = req.params.id;
    const user = await db.getUserById(userId);
    if (!user) return res.status(404).json({ error: 'User not found' });

    const [deposits, withdrawals, gameHistory, tournamentHistory, notifications] = await Promise.all([
      db.getDepositsByUser(userId),
      (async () => {
        const { supabase } = await import('../services/supabase');
        const { data } = await supabase.from('withdrawals').select('*').eq('user_id', userId).order('created_at', { ascending: false }).limit(50);
        return data || [];
      })(),
      (async () => {
        const { supabase } = await import('../services/supabase');
        const { data } = await supabase.from('game_sessions').select('*').eq('user_id', userId).order('started_at', { ascending: false }).limit(50);
        return data || [];
      })(),
      db.getUserTournamentHistory(userId, 20),
      db.getUserNotifications(userId, false),
    ]);

    const totalDeposited = deposits.filter((d: any) => d.payment_status === 'finished').reduce((s: number, d: any) => s + parseFloat(d.amount_usdt), 0);
    const totalWithdrawn = withdrawals.filter((w: any) => w.status === 'completed').reduce((s: number, w: any) => s + parseFloat(w.amount), 0);
    const totalGames = gameHistory.length;
    const avgScore = totalGames > 0 ? gameHistory.reduce((s: number, g: any) => s + (g.score || 0), 0) / totalGames : 0;
    const winRate = totalGames > 0 ? (gameHistory.filter((g: any) => (g.payout_usdt || 0) > 0).length / totalGames) * 100 : 0;

    res.json({
      success: true,
      user,
      stats: {
        total_deposited: totalDeposited,
        total_withdrawn: totalWithdrawn,
        net_position: totalDeposited - totalWithdrawn,
        total_games: totalGames,
        avg_score: Math.round(avgScore),
        win_rate: Math.round(winRate * 100) / 100,
        tournaments_played: tournamentHistory.length,
      },
      recent: {
        deposits: deposits.slice(0, 10),
        withdrawals: withdrawals.slice(0, 10),
        games: gameHistory.slice(0, 10),
        tournaments: tournamentHistory.slice(0, 10),
      },
    });
  } catch (error: any) {
    console.error('Error fetching user profile:', error);
    res.status(500).json({ error: 'Failed to fetch user profile' });
  }
});

// POST /api/admin/users/:id/adjust-balance
router.post('/users/:id/adjust-balance', async (req, res) => {
  try {
    const userId = req.params.id;
    const { amount, reason } = req.body;
    const adminUserId = (req as any).adminUserId;

    if (!amount || !reason) {
      return res.status(400).json({ error: 'amount and reason are required' });
    }

    const newBalance = await db.adjustUserBalance(userId, parseFloat(amount), reason);

    await db.createAuditLog(
      adminUserId,
      'balance_adjusted',
      'user',
      userId,
      { amount, reason, new_balance: newBalance },
      req.ip || 'unknown'
    );

    await db.createNotification(
      userId,
      'balance_adjustment',
      'Balance Adjustment',
      `Your balance has been adjusted by $${parseFloat(amount).toFixed(2)} USDT. Reason: ${reason}. New balance: $${newBalance.toFixed(2)} USDT.`
    );

    res.json({ success: true, new_balance: newBalance });
  } catch (error: any) {
    console.error('Error adjusting balance:', error);
    res.status(500).json({ error: 'Failed to adjust balance' });
  }
});

// GET /api/admin/audit-logs
router.get('/audit-logs', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit as string) || 100;
    const { supabase } = await import('../services/supabase');
    const { data, error } = await supabase
      .from('audit_logs')
      .select('*, users(username, email)')
      .order('created_at', { ascending: false })
      .limit(limit);

    if (error) throw new Error(error.message);
    res.json({ success: true, logs: data || [] });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to fetch audit logs' });
  }
});

export default router;
