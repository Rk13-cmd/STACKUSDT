import { db } from './supabase';
import { nowPayments } from './nowPayments';

interface SyncResult {
  checked: number;
  updated: number;
  credited: number;
  errors: number;
  stuckPayments: any[];
}

export class PaymentSyncService {
  private isRunning = false;

  async syncPendingPayments(): Promise<SyncResult> {
    if (this.isRunning) {
      return { checked: 0, updated: 0, credited: 0, errors: 0, stuckPayments: [] };
    }

    this.isRunning = true;
    const result: SyncResult = {
      checked: 0,
      updated: 0,
      credited: 0,
      errors: 0,
      stuckPayments: [],
    };

    try {
      const pendingDeposits = await this.getPendingDeposits();
      result.checked = pendingDeposits.length;

      const thirtyMinAgo = new Date(Date.now() - 30 * 60 * 1000);

      for (const deposit of pendingDeposits) {
        try {
          const npStatus = await nowPayments.checkPaymentStatus(deposit.nowpayments_payment_id);
          const newStatus = npStatus.payment_status;

          if (newStatus !== deposit.payment_status) {
            await db.updateDepositStatus(
              deposit.nowpayments_payment_id,
              newStatus,
              parseFloat(npStatus.pay_amount)
            );
            result.updated++;

            if (newStatus === 'finished') {
              const amount = parseFloat(npStatus.price_amount || npStatus.pay_amount);
              await db.updateUserBalance(deposit.user_id, amount, 'add');
              await db.updateTotalDeposited(deposit.user_id, amount);

              await db.createNotification(
                deposit.user_id,
                'deposit_confirmed',
                'Deposit Confirmed',
                `Your deposit of $${amount.toFixed(2)} USDT has been confirmed and added to your balance.`
              );
              result.credited++;
            }
          }

          const createdAt = new Date(deposit.created_at);
          if (deposit.payment_status !== 'finished' && createdAt < thirtyMinAgo) {
            result.stuckPayments.push({
              id: deposit.id,
              payment_id: deposit.nowpayments_payment_id,
              amount: deposit.amount_usdt,
              status: deposit.payment_status,
              age_minutes: Math.round((Date.now() - createdAt.getTime()) / (1000 * 60)),
            });
          }
        } catch (err: any) {
          console.error(`Error syncing deposit ${deposit.nowpayments_payment_id}:`, err.message);
          result.errors++;
        }
      }
    } catch (err: any) {
      console.error('Payment sync failed:', err.message);
    } finally {
      this.isRunning = false;
    }

    return result;
  }

  private async getPendingDeposits(): Promise<any[]> {
    if ((db as any).useMock) return [];

    const { supabase } = await import('./supabase');
    const { data } = await supabase
      .from('deposits')
      .select('*')
      .in('payment_status', ['waiting', 'confirming', 'sending'])
      .order('created_at', { ascending: true });

    return data || [];
  }

  async getStuckPayments(hours: number = 1): Promise<any[]> {
    if ((db as any).useMock) return [];

    const cutoff = new Date(Date.now() - hours * 60 * 60 * 1000).toISOString();
    const { supabase } = await import('./supabase');
    const { data } = await supabase
      .from('deposits')
      .select('*')
      .neq('payment_status', 'finished')
      .neq('payment_status', 'failed')
      .lt('created_at', cutoff)
      .order('created_at', { ascending: true });

    return (data || []).map((d: any) => ({
      id: d.id,
      payment_id: d.nowpayments_payment_id,
      user_id: d.user_id,
      amount: d.amount_usdt,
      status: d.payment_status,
      created_at: d.created_at,
      age_hours: Math.round((Date.now() - new Date(d.created_at).getTime()) / (1000 * 60 * 60)),
    }));
  }
}

export const paymentSync = new PaymentSyncService();
