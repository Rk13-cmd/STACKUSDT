import { Router } from 'express';
import { db } from '../services/supabase';

const router = Router();

// GET /api/admin/financial-stats
router.get('/financial-stats', async (req, res) => {
  try {
    const stats = await db.getFinancialStats();
    res.json({ success: true, stats });
  } catch (error: any) {
    console.error('Error fetching financial stats:', error);
    res.status(500).json({ error: 'Failed to fetch stats' });
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

// PUT /api/admin/withdraw/:id/approve
router.put('/withdraw/:id/approve', async (req, res) => {
  try {
    const { id } = req.params;
    const { admin_notes, tx_hash } = req.body;

    await db.updateWithdrawalStatus(id, 'completed', admin_notes, tx_hash);

    const withdrawal = await db.getWithdrawalById(id);
    if (withdrawal) {
      await db.createNotification(
        withdrawal.user_id,
        'withdrawal_approved',
        'Withdrawal Processed',
        `Your withdrawal of $${parseFloat(withdrawal.amount).toFixed(2)} USDT has been processed and sent to your wallet.${tx_hash ? ` TX: ${tx_hash}` : ''}`
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

    res.json({ success: true, message: 'Withdrawal rejected and refunded' });
  } catch (error: any) {
    console.error('Error rejecting withdrawal:', error);
    res.status(500).json({ error: 'Failed to reject withdrawal' });
  }
});

export default router;
