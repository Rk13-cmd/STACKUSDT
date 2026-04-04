import { db } from './supabase';

export class AMLService {
  async checkStructuring(userId: string, depositAmount: number): Promise<{ flagged: boolean; reason: string }> {
    const { supabase } = await import('./supabase');

    const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();

    const { data: recentDeposits } = await supabase
      .from('deposits')
      .select('amount_usdt')
      .eq('user_id', userId)
      .eq('payment_status', 'finished')
      .gte('confirmed_at', twentyFourHoursAgo);

    if (!recentDeposits || recentDeposits.length === 0) {
      return { flagged: false, reason: '' };
    }

    const totalRecent = recentDeposits.reduce((sum: number, d: any) => sum + parseFloat(d.amount_usdt), 0);
    const newTotal = totalRecent + depositAmount;

    if (recentDeposits.length >= 3 && depositAmount < 100) {
      return {
        flagged: true,
        reason: `Possible structuring: ${recentDeposits.length + 1} deposits in 24h, latest $${depositAmount}`,
      };
    }

    if (newTotal > 5000 && recentDeposits.length >= 2) {
      return {
        flagged: true,
        reason: `Large cumulative deposits: $${newTotal.toFixed(2)} in 24h across ${recentDeposits.length + 1} transactions`,
      };
    }

    return { flagged: false, reason: '' };
  }

  async checkVelocity(userId: string): Promise<{ flagged: boolean; reason: string }> {
    const { supabase } = await import('./supabase');

    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString();

    const { data: recentGames } = await supabase
      .from('game_sessions')
      .select('score, payout_usdt, started_at')
      .eq('user_id', userId)
      .gte('started_at', oneHourAgo);

    if (!recentGames || recentGames.length < 10) {
      return { flagged: false, reason: '' };
    }

    const avgScore = recentGames.reduce((sum: number, g: any) => sum + (g.score || 0), 0) / recentGames.length;
    const consistentScores = recentGames.every((g: any) => {
      const score = g.score || 0;
      return score >= avgScore * 0.8 && score <= avgScore * 1.2;
    });

    if (consistentScores && recentGames.length > 15) {
      return {
        flagged: true,
        reason: `Bot-like behavior: ${recentGames.length} games in 1h with consistent scores (avg: ${Math.round(avgScore)})`,
      };
    }

    return { flagged: false, reason: '' };
  }

  async checkWithdrawalPattern(userId: string, withdrawalAmount: number): Promise<{ flagged: boolean; reason: string }> {
    const { supabase } = await import('./supabase');

    const user = await db.getUserById(userId);
    if (!user) return { flagged: false, reason: '' };

    const totalDeposited = (user as any).total_deposited || 0;
    const totalWithdrawn = user.total_withdrawn || 0;

    if (withdrawalAmount > 1000 && totalDeposited < withdrawalAmount * 0.5) {
      return {
        flagged: true,
        reason: `Large withdrawal ($${withdrawalAmount}) with low deposit history ($${totalDeposited})`,
      };
    }

    if (withdrawalAmount > 5000) {
      return {
        flagged: true,
        reason: `High-value withdrawal: $${withdrawalAmount} (KYC recommended)`,
      };
    }

    return { flagged: false, reason: '' };
  }

  async logAMLAlert(userId: string, alertType: string, reason: string, severity: string = 'medium'): Promise<void> {
    const { supabase } = await import('./supabase');

    try {
      await supabase.from('aml_alerts').insert({
        user_id: userId,
        alert_type: alertType,
        reason,
        severity,
        status: 'pending',
      });
    } catch {
      console.warn('[AML] Alert logged (table may not exist): ' + alertType + ' - ' + reason);
    }

    console.warn('[AML ALERT] ' + severity.toUpperCase() + ': ' + reason + ' (user: ' + userId + ')');
  }
}

export const amlService = new AMLService();
