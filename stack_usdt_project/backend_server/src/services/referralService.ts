import { db } from './supabase';

export class ReferralService {
  private readonly LEVEL1_PERCENT = 5.0;
  private readonly LEVEL2_PERCENT = 2.0;

  async getReferralInfo(userId: string): Promise<any> {
    const { supabase } = await import('./supabase');

    const user = await db.getUserById(userId);
    if (!user) throw new Error('User not found');

    const { count: directRefs } = await supabase
      .from('users')
      .select('*', { count: 'exact', head: true })
      .eq('referred_by', userId);

    const { data: level2Users } = await supabase
      .from('users')
      .select('id')
      .eq('referred_by', userId);

    let level2Count = 0;
    if (level2Users && level2Users.length > 0) {
      const level1Ids = level2Users.map((u: any) => u.id);
      const { count: l2 } = await supabase
        .from('users')
        .select('*', { count: 'exact', head: true })
        .in('referred_by', level1Ids);
      level2Count = l2 || 0;
    }

    const { data: earnings } = await supabase
      .from('referral_earnings')
      .select('amount_usdt, level, status, created_at, referred_user_id')
      .eq('referrer_id', userId)
      .order('created_at', { ascending: false });

    const totalEarned = earnings?.filter((e: any) => e.status === 'paid').reduce((s: number, e: any) => s + parseFloat(e.amount_usdt), 0) || 0;
    const pendingEarned = earnings?.filter((e: any) => e.status === 'pending').reduce((s: number, e: any) => s + parseFloat(e.amount_usdt), 0) || 0;

    return {
      referral_code: user.referral_code,
      referral_link: `${process.env.FRONTEND_URL || 'https://stackusdt.game'}/register?ref=${user.referral_code}`,
      direct_referrals: directRefs || 0,
      level2_referrals: level2Count,
      total_referrals: (directRefs || 0) + level2Count,
      total_earned: totalEarned,
      pending_earned: pendingEarned,
      level1_percent: this.LEVEL1_PERCENT,
      level2_percent: this.LEVEL2_PERCENT,
      earnings_history: earnings || [],
    };
  }

  async processReferralDeposit(depositUserId: string, depositAmount: number): Promise<void> {
    const { supabase } = await import('./supabase');

    const user = await db.getUserById(depositUserId);
    if (!user || !(user as any).referred_by) return;

    const referrerId = (user as any).referred_by;
    const level1Reward = depositAmount * (this.LEVEL1_PERCENT / 100);

    await supabase.from('referral_earnings').insert({
      referrer_id: referrerId,
      referred_user_id: depositUserId,
      level: 1,
      amount_usdt: level1Reward,
      source_deposit_id: null,
      status: 'pending',
    });

    await db.updateUserBalance(referrerId, level1Reward, 'add');

    await db.createNotification(
      referrerId,
      'referral_earning',
      'Referral Reward!',
      'Your referral deposited $' + depositAmount.toFixed(2) + '. You earned $' + level1Reward.toFixed(2) + ' USDT (' + this.LEVEL1_PERCENT + '%)!'
    );

    const { data: referrerProfile } = await supabase
      .from('users')
      .select('referred_by')
      .eq('id', referrerId)
      .single();

    if (referrerProfile?.referred_by) {
      const level2Reward = depositAmount * (this.LEVEL2_PERCENT / 100);

      await supabase.from('referral_earnings').insert({
        referrer_id: referrerProfile.referred_by,
        referred_user_id: depositUserId,
        level: 2,
        amount_usdt: level2Reward,
        source_deposit_id: null,
        status: 'pending',
      });

      await db.updateUserBalance(referrerProfile.referred_by, level2Reward, 'add');

      await db.createNotification(
        referrerProfile.referred_by,
        'referral_earning',
        'Level 2 Referral Reward!',
        'A user referred by your referral deposited $' + depositAmount.toFixed(2) + '. You earned $' + level2Reward.toFixed(2) + ' USDT (' + this.LEVEL2_PERCENT + '%)!'
      );
    }
  }

  async getReferralLeaderboard(limit: number = 20): Promise<any[]> {
    const { supabase } = await import('./supabase');

    const { data, error } = await supabase
      .from('users')
      .select('id, username, referral_code')
      .order('created_at', { ascending: false })
      .limit(200);

    if (error || !data) return [];

    const results = [];
    for (const user of data) {
      const { count } = await supabase
        .from('users')
        .select('*', { count: 'exact', head: true })
        .eq('referred_by', user.id);

      const { data: earnings } = await supabase
        .from('referral_earnings')
        .select('amount_usdt')
        .eq('referrer_id', user.id)
        .eq('status', 'paid');

      const totalEarned = earnings?.reduce((s: number, e: any) => s + parseFloat(e.amount_usdt), 0) || 0;

      results.push({
        user_id: user.id,
        username: user.username,
        referral_code: user.referral_code,
        total_referrals: count || 0,
        total_earned: totalEarned,
      });
    }

    return results.sort((a, b) => b.total_referrals - a.total_referrals).slice(0, limit);
  }

  async applyReferralCode(userId: string, code: string): Promise<boolean> {
    const { supabase } = await import('./supabase');

    const { data: referrer } = await supabase
      .from('users')
      .select('id')
      .eq('referral_code', code.toUpperCase())
      .single();

    if (!referrer || referrer.id === userId) return false;

    const { error } = await supabase
      .from('users')
      .update({ referred_by: referrer.id })
      .eq('id', userId);

    if (error) return false;

    await db.createNotification(
      referrer.id,
      'new_referral',
      'New Referral!',
      `Someone joined STACK USDT using your referral code!`
    );

    return true;
  }
}

export const referralService = new ReferralService();
