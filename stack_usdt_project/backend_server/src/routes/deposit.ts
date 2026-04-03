import { Router } from 'express';
import { db } from '../services/supabase';
import { nowPayments } from '../services/nowPayments';

const router = Router();

// POST /api/deposit/create - Create NOWPayments invoice
router.post('/create', async (req, res) => {
  try {
    const { user_id, amount } = req.body;

    if (!user_id || !amount) {
      return res.status(400).json({ error: 'user_id and amount are required' });
    }

    const amountNum = parseFloat(amount);
    if (isNaN(amountNum) || amountNum < 10) {
      return res.status(400).json({
        error: 'Minimum deposit is $10 USDT',
        minimum: 10,
      });
    }

    if (amountNum > 50000) {
      return res.status(400).json({
        error: 'Maximum deposit is $50,000 USDT',
        maximum: 50000,
      });
    }

    const user = await db.getUserById(user_id);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const invoice = await nowPayments.createInvoice(
      user_id,
      amountNum,
      user.email
    );

    await db.createDeposit(
      user_id,
      amountNum,
      invoice.payment_id,
      invoice.order_id,
      invoice.payment_address
    );

    res.json({
      success: true,
      invoice: {
        payment_id: invoice.payment_id,
        payment_address: invoice.payment_address,
        amount: invoice.amount,
        pay_amount: invoice.pay_amount,
        pay_currency: invoice.pay_currency,
        invoice_url: invoice.invoice_url,
      },
    });
  } catch (error: any) {
    console.error('Error creating deposit:', error);
    res.status(500).json({ error: 'Failed to create deposit invoice' });
  }
});

// POST /api/deposit/webhook - NOWPayments IPN
router.post('/webhook', async (req, res) => {
  try {
    const payload = JSON.stringify(req.body);
    const signature = req.headers['x-nowpayments-sig'] as string;

    if (signature && !nowPayments.verifyWebhookSignature(payload, signature)) {
      console.warn('Invalid webhook signature');
      return res.status(401).json({ error: 'Invalid signature' });
    }

    const { payment_id, payment_status, order_id, pay_amount, price_amount } = req.body;

    if (!payment_id || !payment_status) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    await db.updateDepositStatus(payment_id, payment_status, pay_amount);

    if (payment_status === 'finished') {
      const amount = parseFloat(price_amount || pay_amount);

      const deposit = await db.getDepositsByUser('').then(deposits =>
        deposits.find((d: any) => d.nowpayments_payment_id === payment_id)
      );

      if (deposit) {
        await db.updateUserBalance(deposit.user_id, amount, 'add');

        await db.createNotification(
          deposit.user_id,
          'deposit',
          'Deposit Confirmed',
          `Your deposit of $${amount.toFixed(2)} USDT has been confirmed and added to your balance.`
        );
      }
    }

    res.json({ success: true });
  } catch (error: any) {
    console.error('Webhook error:', error);
    res.status(500).json({ error: 'Webhook processing failed' });
  }
});

// GET /api/deposit/history/:userId
router.get('/history/:userId', async (req, res) => {
  try {
    const deposits = await db.getDepositsByUser(req.params.userId);
    res.json({ success: true, deposits });
  } catch (error: any) {
    console.error('Error fetching deposits:', error);
    res.status(500).json({ error: 'Failed to fetch deposit history' });
  }
});

// GET /api/deposit/all (admin)
router.get('/all', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit as string) || 100;
    const deposits = await db.getAllDeposits(limit);
    res.json({ success: true, deposits });
  } catch (error: any) {
    console.error('Error fetching all deposits:', error);
    res.status(500).json({ error: 'Failed to fetch deposits' });
  }
});

export default router;
