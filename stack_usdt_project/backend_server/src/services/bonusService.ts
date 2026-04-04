import { db } from './supabase';

export class BonusService {
  async createBonus(data: {
    name: string;
    type: string;
    amount_usdt?: number;
    amount_percent?: number;
    description?: string;
    min_deposit?: number;
    max_uses?: number;
    expires_at?: string;
  }): Promise<any> {
    const { supabase } = await import('./supabase');
    const { data: result, error } = await supabase
      .from('bonuses')
      .insert({
        name: data.name,
        type: data.type,
        amount_usdt: data.amount_usdt || 0,
        amount_percent: data.amount_percent,
        description: data.description,
        min_deposit: data.min_deposit || 0,
        max_uses: data.max_uses,
        expires_at: data.expires_at,
        is_active: true,
      })
      .select()
      .single();

    if (error) throw new Error(error.message);
    return result;
  }

  async getAllBonuses(): Promise<any[]> {
    const { supabase } = await import('./supabase');
    const { data, error } = await supabase
      .from('bonuses')
      .select('*')
      .order('created_at', { ascending: false });
    if (error) throw new Error(error.message);
    return data || [];
  }

  async getActiveBonuses(): Promise<any[]> {
    const { supabase } = await import('./supabase');
    const { data, error } = await supabase
      .from('bonuses')
      .select('*')
      .eq('is_active', true)
      .or('expires_at.is.null,expires_at.gt.now()')
      .order('created_at', { ascending: false });
    if (error) throw new Error(error.message);
    return data || [];
  }

  async toggleBonus(bonusId: string, isActive: boolean): Promise<void> {
    const { supabase } = await import('./supabase');
    const { error } = await supabase
      .from('bonuses')
      .update({ is_active: isActive })
      .eq('id', bonusId);
    if (error) throw new Error(error.message);
  }

  async checkAndAwardBonus(userId: string, type: string, depositAmount?: number): Promise<any | null> {
    const { supabase } = await import('./supabase');

    const { data: bonuses } = await supabase
      .from('bonuses')
      .select('*')
      .eq('is_active', true)
      .eq('type', type)
      .or('expires_at.is.null,expires_at.gt.now()');

    if (!bonuses || bonuses.length === 0) return null;

    for (const bonus of bonuses) {
      if (bonus.max_uses && bonus.current_uses >= bonus.max_uses) continue;
      if (bonus.min_deposit && depositAmount && depositAmount < bonus.min_deposit) continue;

      if (type === 'first_deposit') {
        const { data: existingDeposit } = await supabase
          .from('deposits')
          .select('id')
          .eq('user_id', userId)
          .eq('payment_status', 'finished')
          .limit(1);

        if (existingDeposit && existingDeposit.length > 0) continue;
      }

      const bonusAmount = bonus.amount_percent
        ? (depositAmount || 0) * (bonus.amount_percent / 100)
        : bonus.amount_usdt;

      if (bonusAmount <= 0) continue;

      const { data: userBonus, error: insertError } = await supabase
        .from('user_bonuses')
        .insert({
          user_id: userId,
          bonus_id: bonus.id,
          amount_usdt: bonusAmount,
          status: 'pending',
          expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
        })
        .select()
        .single();

      if (insertError) {
        console.error('Error creating user bonus:', insertError.message);
        continue;
      }

      await supabase
        .from('bonuses')
        .update({ current_uses: (bonus.current_uses || 0) + 1 })
        .eq('id', bonus.id);

      await db.createNotification(
        userId,
        'bonus_awarded',
        `Bonus: ${bonus.name}`,
        `You've been awarded a ${bonus.name} bonus of $${bonusAmount.toFixed(2)} USDT! Claim it within 7 days.`
      );

      return userBonus;
    }

    return null;
  }

  async claimBonus(userBonusId: string, userId: string): Promise<any> {
    const { supabase } = await import('./supabase');

    const { data: userBonus, error: fetchError } = await supabase
      .from('user_bonuses')
      .select('*, bonuses(*)')
      .eq('id', userBonusId)
      .eq('user_id', userId)
      .single();

    if (fetchError || !userBonus) throw new Error('Bonus not found');
    if (userBonus.status !== 'pending') throw new Error('Bonus already claimed or expired');
    if (userBonus.expires_at && new Date(userBonus.expires_at) < new Date()) {
      throw new Error('Bonus has expired');
    }

    await db.updateUserBalance(userId, userBonus.amount_usdt, 'add');

    const { data: updated, error: updateError } = await supabase
      .from('user_bonuses')
      .update({ status: 'claimed', claimed_at: new Date().toISOString() })
      .eq('id', userBonusId)
      .select()
      .single();

    if (updateError) throw new Error(updateError.message);
    return updated;
  }

  async getUserBonuses(userId: string): Promise<any[]> {
    const { supabase } = await import('./supabase');
    const { data, error } = await supabase
      .from('user_bonuses')
      .select('*, bonuses(name, type, description)')
      .eq('user_id', userId)
      .order('created_at', { ascending: false });
    if (error) throw new Error(error.message);
    return data || [];
  }

  async getUserPendingBonusValue(userId: string): Promise<number> {
    const { supabase } = await import('./supabase');
    const { data } = await supabase
      .from('user_bonuses')
      .select('amount_usdt')
      .eq('user_id', userId)
      .eq('status', 'pending');
    return data?.reduce((sum: number, b: any) => sum + parseFloat(b.amount_usdt), 0) || 0;
  }
}

export const bonusService = new BonusService();
