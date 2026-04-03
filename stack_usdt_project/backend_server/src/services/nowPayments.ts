import axios, { AxiosInstance } from 'axios';
import * as crypto from 'crypto';

export interface InvoiceResult {
  payment_id: string;
  order_id: string;
  payment_address: string;
  amount: number;
  pay_amount: number;
  pay_currency: string;
  invoice_url: string;
  success: boolean;
}

export class NowPaymentsService {
  private client: AxiosInstance;
  private ipnSecret: string;

  constructor() {
    const apiKey = process.env.NOWPAYMENTS_API_KEY || '';
    this.ipnSecret = process.env.NOWPAYMENTS_IPN_SECRET || '';

    this.client = axios.create({
      baseURL: 'https://api.nowpayments.io/v1',
      headers: {
        'x-api-key': apiKey,
        'Content-Type': 'application/json',
      },
      timeout: 15000,
    });
  }

  async createInvoice(
    userId: string,
    amountUsdt: number,
    userEmail: string
  ): Promise<InvoiceResult> {
    const orderId = `stack_${userId}_${Date.now()}`;

    const response = await this.client.post('/invoice', {
      price_amount: amountUsdt,
      price_currency: 'usd',
      pay_currency: 'USDTTRC20',
      order_id: orderId,
      order_description: `STACK USDT Deposit - User ${userId}`,
      ipn_callback_url: `${process.env.BACKEND_URL || 'http://localhost:3001'}/api/deposit/webhook`,
      success_url: `${process.env.FRONTEND_URL || 'http://localhost:3000'}/deposit/success`,
      cancel_url: `${process.env.FRONTEND_URL || 'http://localhost:3000'}/deposit/cancel`,
    });

    return {
      payment_id: response.data.id,
      order_id: response.data.order_id,
      payment_address: response.data.pay_address,
      amount: response.data.price_amount,
      pay_amount: response.data.pay_amount,
      pay_currency: response.data.pay_currency,
      invoice_url: response.data.invoice_url,
      success: true,
    };
  }

  verifyWebhookSignature(payload: string, signature: string): boolean {
    if (!this.ipnSecret) return true;
    const expectedSignature = crypto
      .createHmac('sha512', this.ipnSecret)
      .update(payload)
      .digest('hex');
    return expectedSignature === signature;
  }

  async checkPaymentStatus(paymentId: string): Promise<any> {
    const response = await this.client.get(`/payment/${paymentId}`);
    return response.data;
  }
}

export const nowPayments = new NowPaymentsService();
