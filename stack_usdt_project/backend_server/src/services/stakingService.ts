import { db } from './supabase';

export class StakingService {
  private readonly DEFAULT_ANNUAL_RATE = 12.0;
  private readonly MIN_STAKE = 10;
  private readonly UNSTAKE_COOLDOWN_HOURS = 24;

  async stake(userId: string, amount: number): Promise<any> {
    const { supabase } = await import('./supabase');

    const user = await db.getUserById(userId);
    if (!user) throw new Error('User not found');
    if (user.usdt_balance < amount) throw new Error('Insufficient balance');
    if (amount < this.MIN_STAKE) throw new Error('Minimum stake is $' + this.MIN_STAKE + ' USDT');

    const { data: existingStake } = await supabase
      .from('user_staking')
      .select('*')
      .eq('user_id', userId)
      .eq('status', 'active')
      .single();

    if (existingStake) {
      const newAmount = parseFloat(existingStake.amount_usdt) + amount;
      await supabase
        .from('user_staking')
        .update({
          amount_usdt: newAmount,
          last_reward_at: new Date().toISOString(),
        })
        .eq('id', existingStake.id);

      await db.updateUserBalance(userId, amount, 'subtract');

      return {
        staking_id: existingStake.id,
        amount: newAmount,
        annual_rate: this.DEFAULT_ANNUAL_RATE,
        message: 'Added $' + amount + ' to existing stake. Total: $' + newAmount.toFixed(2),
      };
    }

    await db.updateUserBalance(userId, amount, 'subtract');

    const { data: staking, error } = await supabase
      .from('user_staking')
      .insert({
        user_id: userId,
        amount_usdt: amount,
        annual_rate: this.DEFAULT_ANNUAL_RATE,
        status: 'active',
      })
      .select()
      .single();

    if (error) throw new Error(error.message);

    await db.createNotification(
      userId,
      'staking_started',
      'Staking Started',
      'You have staked $' + amount.toFixed(2) + ' USDT at ' + this.DEFAULT_ANNUAL_RATE + '% APR. Rewards are distributed daily!'
    );

    return {
      staking_id: staking.id,
      amount,
      annual_rate: this.DEFAULT_ANNUAL_RATE,
      message: 'Staked $' + amount.toFixed(2) + ' USDT at ' + this.DEFAULT_ANNUAL_RATE + '% APR',
    };
  }

  async unstake(userId: string): Promise<any> {
    const { supabase } = await import('./supabase');

    const { data: staking, error: fetchError } = await supabase
      .from('user_staking')
      .select('*')
      .eq('user_id', userId)
      .eq('status', 'active')
      .single();

    if (fetchError || !staking) throw new Error('No active stake found');

    const lastReward = new Date(staking.last_reward_at);
    const cooldownEnd = new Date(lastReward.getTime() + this.UNSTAKE_COOLDOWN_HOURS * 60 * 60 * 1000);
    if (new Date() < cooldownEnd) {
      const hoursLeft = Math.ceil((cooldownEnd.getTime() - Date.now()) / (1000 * 60 * 60));
      throw new Error('Please wait ' + hoursLeft + ' more hours before unstaking');
    }

    await this.distributeReward(userId);

    const totalReturn = parseFloat(staking.amount_usdt) + parseFloat(staking.total_earned_usdt || 0);

    await db.updateUserBalance(userId, totalReturn, 'add');

    await supabase
      .from('user_staking')
      .update({
        status: 'unstaked',
        unstaked_at: new Date().toISOString(),
      })
      .eq('id', staking.id);

    await db.createNotification(
      userId,
      'staking_unstaked',
      'Staking Withdrawn',
      'Your stake of $' + staking.amount_usdt + ' has been unstaked. Total returned: $' + totalReturn.toFixed(2) + ' USDT.'
    );

    return {
      staked_amount: parseFloat(staking.amount_usdt),
      rewards_earned: parseFloat(staking.total_earned_usdt || 0),
      total_returned: totalReturn,
    };
  }

  async distributeReward(userId: string): Promise<number> {
    const { supabase } = await import('./supabase');

    const { data: staking } = await supabase
      .from('user_staking')
      .select('*')
      .eq('user_id', userId)
      .eq('status', 'active')
      .single();

    if (!staking) return 0;

    const lastReward = new Date(staking.last_reward_at);
    const now = new Date();
    const daysElapsed = (now.getTime() - lastReward.getTime()) / (1000 * 60 * 60 * 24);

    if (daysElapsed < 1) return 0;

    const dailyRate = (staking.annual_rate / 100) / 365;
    const reward = parseFloat(staking.amount_usdt) * dailyRate * Math.floor(daysElapsed);

    if (reward <= 0) return 0;

    await db.updateUserBalance(userId, reward, 'add');

    await supabase
      .from('staking_rewards_log')
      .insert({
        staking_id: staking.id,
        user_id: userId,
        amount_usdt: reward,
        reward_date: now.toISOString(),
      });

    await supabase
      .from('user_staking')
      .update({
        total_earned_usdt: parseFloat(staking.total_earned_usdt || 0) + reward,
        last_reward_at: now.toISOString(),
      })
      .eq('id', staking.id);

    return reward;
  }

  async distributeAllRewards(): Promise<number> {
    const { supabase } = await import('./supabase');
    let totalDistributed = 0;

    const { data: activeStakes } = await supabase
      .from('user_staking')
      .select('user_id')
      .eq('status', 'active');

    if (!activeStakes) return 0;

    const userIds = [...new Set(activeStakes.map((s: any) => s.user_id))];

    for (const userId of userIds) {
      try {
        const reward = await this.distributeReward(userId);
        totalDistributed += reward;
      } catch (err) {
        console.error('Error distributing reward for ' + userId + ':', err);
      }
    }

    return totalDistributed;
  }

  async getUserStakingInfo(userId: string): Promise<any> {
    const { supabase } = await import('./supabase');

    const { data: staking } = await supabase
      .from('user_staking')
      .select('*')
      .eq('user_id', userId)
      .eq('status', 'active')
      .single();

    const { data: rewardsHistory } = await supabase
      .from('staking_rewards_log')
      .select('*')
      .eq('user_id', userId)
      .order('reward_date', { ascending: false })
      .limit(30);

    if (!staking) {
      return {
        has_active_stake: false,
        rewards_history: rewardsHistory || [],
        min_stake: this.MIN_STAKE,
        annual_rate: this.DEFAULT_ANNUAL_RATE,
      };
    }

    const dailyReward = parseFloat(staking.amount_usdt) * ((staking.annual_rate / 100) / 365);
    const monthlyReward = dailyReward * 30;
    const yearlyReward = dailyReward * 365;

    return {
      has_active_stake: true,
      staking_id: staking.id,
      amount: parseFloat(staking.amount_usdt),
      annual_rate: staking.annual_rate,
      total_earned: parseFloat(staking.total_earned_usdt || 0),
      started_at: staking.started_at,
      last_reward_at: staking.last_reward_at,
      daily_reward: dailyReward,
      monthly_reward: monthlyReward,
      yearly_reward: yearlyReward,
      rewards_history: rewardsHistory || [],
      can_unstake: new Date() >= new Date(new Date(staking.last_reward_at).getTime() + this.UNSTAKE_COOLDOWN_HOURS * 60 * 60 * 1000),
    };
  }

  async getGlobalStakingStats(): Promise<any> {
    const { supabase } = await import('./supabase');

    const { data: activeStakes } = await supabase
      .from('user_staking')
      .select('amount_usdt, total_earned_usdt')
      .eq('status', 'active');

    const { count: totalStakers } = await supabase
      .from('user_staking')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'active');

    const totalStaked = activeStakes?.reduce((s: number, st: any) => s + parseFloat(st.amount_usdt), 0) || 0;
    const totalEarned = activeStakes?.reduce((s: number, st: any) => s + parseFloat(st.total_earned_usdt || 0), 0) || 0;

    return {
      total_staked: totalStaked,
      total_rewards_paid: totalEarned,
      active_stakers: totalStakers || 0,
      annual_rate: this.DEFAULT_ANNUAL_RATE,
      min_stake: this.MIN_STAKE,
    };
  }
}

export const stakingService = new StakingService();
