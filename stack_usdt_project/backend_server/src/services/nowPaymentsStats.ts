import axios, { AxiosInstance } from 'axios';

export interface NowPaymentsStats {
  total_volume: number;
  total_payments: number;
  finished_payments: number;
  waiting_payments: number;
  failed_payments: number;
  confirming_payments: number;
  success_rate: number;
  avg_confirmation_time_minutes: number;
  volume_by_currency: Record<string, number>;
  volume_by_status: Record<string, number>;
  recent_payments: any[];
  nowpayments_balance?: number;
}

export class NowPaymentsStatsService {
  private client: AxiosInstance;

  constructor() {
    const apiKey = process.env.NOWPAYMENTS_API_KEY || '';
    this.client = axios.create({
      baseURL: 'https://api.nowpayments.io/v1',
      headers: {
        'x-api-key': apiKey,
        'Content-Type': 'application/json',
      },
      timeout: 15000,
    });
  }

  async getPaymentStats(limit: number = 500): Promise<NowPaymentsStats> {
    try {
      const response = await this.client.get('/payment', {
        params: { limit },
      });

      const payments = response.data.data || response.data || [];

      let totalVolume = 0;
      let finished = 0;
      let waiting = 0;
      let failed = 0;
      let confirming = 0;
      const volumeByCurrency: Record<string, number> = {};
      const volumeByStatus: Record<string, number> = {};
      const confirmationTimes: number[] = [];

      for (const p of payments) {
        const amount = parseFloat(p.price_amount || 0);
        const status = p.payment_status || 'unknown';
        const currency = p.pay_currency || 'UNKNOWN';

        totalVolume += amount;
        volumeByCurrency[currency] = (volumeByCurrency[currency] || 0) + amount;
        volumeByStatus[status] = (volumeByStatus[status] || 0) + amount;

        switch (status) {
          case 'finished':
            finished++;
            if (p.created_at && p.updated_at) {
              const created = new Date(p.created_at).getTime();
              const updated = new Date(p.updated_at).getTime();
              const minutes = (updated - created) / (1000 * 60);
              if (minutes > 0) confirmationTimes.push(minutes);
            }
            break;
          case 'waiting':
            waiting++;
            break;
          case 'failed':
          case 'refunded':
            failed++;
            break;
          case 'confirming':
          case 'sending':
            confirming++;
            break;
        }
      }

      const total = payments.length;
      const avgConfirmationTime = confirmationTimes.length > 0
        ? confirmationTimes.reduce((a, b) => a + b, 0) / confirmationTimes.length
        : 0;

      return {
        total_volume: totalVolume,
        total_payments: total,
        finished_payments: finished,
        waiting_payments: waiting,
        failed_payments: failed,
        confirming_payments: confirming,
        success_rate: total > 0 ? (finished / total) * 100 : 0,
        avg_confirmation_time_minutes: Math.round(avgConfirmationTime * 100) / 100,
        volume_by_currency: volumeByCurrency,
        volume_by_status: volumeByStatus,
        recent_payments: payments.slice(0, 20).map((p: any) => ({
          id: p.id,
          order_id: p.order_id,
          amount: parseFloat(p.price_amount),
          received: parseFloat(p.pay_amount),
          currency: p.pay_currency,
          status: p.payment_status,
          created_at: p.created_at,
          updated_at: p.updated_at,
          pay_address: p.pay_address,
        })),
      };
    } catch (error: any) {
      console.error('Error fetching NOWPayments stats:', error.message);
      throw new Error(`Failed to fetch NOWPayments stats: ${error.message}`);
    }
  }

  async getSinglePayment(paymentId: string): Promise<any> {
    try {
      const response = await this.client.get(`/payment/${paymentId}`);
      return response.data;
    } catch (error: any) {
      console.error(`Error fetching payment ${paymentId}:`, error.message);
      return null;
    }
  }

  async getMinimumPaymentAmount(): Promise<any> {
    try {
      const response = await this.client.get('/min-amount', {
        params: { currency_from: 'usd', currency_to: 'usdttrc20' },
      });
      return response.data;
    } catch {
      return { min_amount: 3 };
    }
  }

  async getCurrencies(): Promise<any[]> {
    try {
      const response = await this.client.get('/currencies', {
        params: { enabled: true },
      });
      return response.data.currencies || [];
    } catch {
      return ['USDTTRC20', 'BTC', 'ETH', 'LTC'];
    }
  }
}

export const nowPaymentsStats = new NowPaymentsStatsService();
