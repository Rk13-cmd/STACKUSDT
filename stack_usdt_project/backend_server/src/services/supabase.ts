import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { User, GameSession, Withdrawal, LeaderboardEntry, SystemConfig } from '../types';
import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: path.resolve(__dirname, '../../.env') });

// Mock data for testing when Supabase is not configured
const mockUsers: Map<string, User> = new Map([
  ['user_demo_123', {
    id: 'user_demo_123',
    email: 'demo@stackusdt.game',
    username: 'DemoPlayer',
    usdt_balance: 100.00,
    total_earned: 0,
    total_withdrawn: 0,
    created_at: new Date().toISOString(),
    is_banned: false,
    wallet_address: null,
    referral_code: 'DEMO001',
    mining_xp: 0,
    mining_level: 1,
    active_skin_id: null,
    is_admin: false
  }]
]);

let mockSessionId = 0;

export const supabase: SupabaseClient = (() => {
  const supabaseUrl = process.env.SUPABASE_URL || '';
  const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
  
  if (supabaseUrl && supabaseUrl.startsWith('http') && !supabaseUrl.includes('placeholder')) {
    return createClient(supabaseUrl, supabaseKey);
  }
  
  console.log('⚠️ Running in MOCK mode - No Supabase connection');
  return null as any;
})();

export class DatabaseService {
  private useMock = !supabase;

  // Users
  async getUserById(userId: string): Promise<User | null> {
    if (this.useMock) {
      return mockUsers.get(userId) || null;
    }
    
    const { data, error } = await supabase
      .from('users')
      .select('*')
      .eq('id', userId)
      .single();
    
    if (error) throw new Error(error.message);
    return data;
  }

  async getUserByEmail(email: string): Promise<User | null> {
    if (this.useMock) {
      return Array.from(mockUsers.values()).find(u => u.email === email) || null;
    }
    
    const { data, error } = await supabase
      .from('users')
      .select('*')
      .eq('email', email)
      .single();
    
    if (error) return null;
    return data;
  }

  async updateUserBalance(userId: string, amount: number, operation: 'add' | 'subtract'): Promise<void> {
    if (this.useMock) {
      const user = mockUsers.get(userId);
      if (user) {
        user.usdt_balance = operation === 'add' 
          ? user.usdt_balance + amount 
          : user.usdt_balance - amount;
      }
      return;
    }
    
    const user = await this.getUserById(userId);
    if (!user) throw new Error('User not found');
    
    const newBalance = operation === 'add' 
      ? user.usdt_balance + amount 
      : user.usdt_balance - amount;
    
    const { error } = await supabase
      .from('users')
      .update({ usdt_balance: newBalance })
      .eq('id', userId);
    
    if (error) throw new Error(error.message);
  }

  // Game Sessions
  async createGameSession(userId: string, deviceFingerprint?: string): Promise<GameSession> {
    if (this.useMock) {
      const session: GameSession = {
        id: `session_${Date.now()}_${++mockSessionId}`,
        user_id: userId,
        started_at: new Date().toISOString(),
        ended_at: null,
        duration_seconds: 0,
        score: 0,
        lines_cleared: 0,
        level_reached: 1,
        payout_usdt: 0,
        is_valid: true,
        validation_notes: null
      };
      return session;
    }
    
    const { data, error } = await supabase
      .from('game_sessions')
      .insert({
        user_id: userId,
        started_at: new Date().toISOString(),
        device_fingerprint: deviceFingerprint,
      })
      .select()
      .single();
    
    if (error) throw new Error(error.message);
    return data;
  }

  async endGameSession(sessionId: string, data: Partial<GameSession>): Promise<GameSession> {
    if (this.useMock) {
      return {
        id: sessionId,
        user_id: '',
        started_at: new Date().toISOString(),
        ended_at: new Date().toISOString(),
        duration_seconds: data.duration_seconds || 0,
        score: data.score || 0,
        lines_cleared: data.lines_cleared || 0,
        level_reached: data.level_reached || 1,
        payout_usdt: data.payout_usdt || 0,
        is_valid: data.is_valid ?? true,
        validation_notes: data.validation_notes || null
      };
    }
    
    const { data: session, error } = await supabase
      .from('game_sessions')
      .update({
        ...data,
        ended_at: new Date().toISOString(),
      })
      .eq('id', sessionId)
      .select()
      .single();
    
    if (error) throw new Error(error.message);
    return session;
  }

  async getGameSession(sessionId: string): Promise<GameSession | null> {
    if (this.useMock) {
      return null;
    }
    
    const { data, error } = await supabase
      .from('game_sessions')
      .select('*')
      .eq('id', sessionId)
      .single();
    
    if (error) return null;
    return data;
  }

  // Withdrawals
  async createWithdrawal(userId: string, amount: number, walletAddress: string, network: string = 'TRC20'): Promise<Withdrawal> {
    if (this.useMock) {
      return {
        id: `withdrawal_${Date.now()}`,
        user_id: userId,
        amount,
        fee: 1.0,
        net_amount: amount - 1.0,
        wallet_address: walletAddress,
        network,
        status: 'pending',
        tx_hash: null,
        created_at: new Date().toISOString(),
        processed_at: null
      };
    }
    
    const { data: config } = await supabase
      .from('system_config')
      .select('value')
      .eq('key', 'withdrawal_fee')
      .single();
    
    const fee = parseFloat(config?.value || '1.0');
    
    const { data, error } = await supabase
      .from('withdrawals')
      .insert({
        user_id: userId,
        amount,
        fee,
        net_amount: amount - fee,
        wallet_address: walletAddress,
        network,
        status: 'pending',
      })
      .select()
      .single();
    
    if (error) throw new Error(error.message);
    return data;
  }

  // Leaderboard
  async getLeaderboard(limit: number = 50): Promise<any[]> {
    if (this.useMock) {
      return [
        { display_name: 'CryptoKing_7x', total_won: 12450, mmr: 2450, tournaments_played: 342, win_rate: 68.5, is_bot: true },
        { display_name: 'TetrisWhale', total_won: 8900, mmr: 2800, tournaments_played: 520, win_rate: 72.3, is_bot: true },
        { display_name: 'LaserClear', total_won: 6200, mmr: 2650, tournaments_played: 280, win_rate: 70.8, is_bot: true },
      ];
    }
    const { data, error } = await supabase
      .from('leaderboard_cache')
      .select('*')
      .order('total_won', { ascending: false })
      .limit(limit);
    if (error) throw new Error(error.message);
    return data || [];
  }

  // System Config
  async getConfig(key: string): Promise<string | null> {
    if (this.useMock) {
      const configs: Record<string, string> = {
        'house_edge': '0.20',
        'min_withdrawal': '10.00',
        'max_withdrawal': '10000.00',
        'withdrawal_fee': '1.00'
      };
      return configs[key] || null;
    }
    
    const { data, error } = await supabase
      .from('system_config')
      .select('value')
      .eq('key', key)
      .single();
    
    if (error) return null;
    return data?.value;
  }

  async getAllConfig(): Promise<SystemConfig[]> {
    if (this.useMock) {
      return [
        { key: 'house_edge', value: '0.20', description: 'House edge percentage' },
        { key: 'min_withdrawal', value: '10.00', description: 'Minimum withdrawal' },
        { key: 'max_withdrawal', value: '10000.00', description: 'Maximum withdrawal' }
      ];
    }
    
    const { data, error } = await supabase
      .from('system_config')
      .select('*');
    
    if (error) throw new Error(error.message);
    return data || [];
  }

  // Shop & Skins
  async getAllSkins(): Promise<any[]> {
    if (this.useMock) {
      return [
        { id: 'skin_1', name: 'NEON CLASSIC', block_color_hex: '#00E5FF', glow_color_hex: '#4000E5FF', price_usdt: 0, is_premium: false },
        { id: 'skin_2', name: 'CYBER GOLD', block_color_hex: '#FFD700', glow_color_hex: '#40FFD700', price_usdt: 5, is_premium: false },
        { id: 'skin_3', name: 'MATRIX GREEN', block_color_hex: '#39FF14', glow_color_hex: '#4039FF14', price_usdt: 4, is_premium: false },
        { id: 'skin_4', name: 'VOID PURPLE', block_color_hex: '#AA00FF', glow_color_hex: '#40AA00FF', price_usdt: 8, is_premium: true },
        { id: 'skin_5', name: 'DIAMOND DUST', block_color_hex: '#B9F2FF', glow_color_hex: '#40B9F2FF', price_usdt: 15, is_premium: true },
      ];
    }
    const { data, error } = await supabase
      .from('skins')
      .select('*')
      .order('price_usdt', { ascending: true });
    if (error) throw new Error(error.message);
    return data || [];
  }

  async getSkinById(skinId: string): Promise<any | null> {
    if (this.useMock) return null;
    const { data, error } = await supabase
      .from('skins')
      .select('*')
      .eq('id', skinId)
      .single();
    if (error) return null;
    return data;
  }

  async getUserInventory(userId: string): Promise<any[]> {
    if (this.useMock) return [];
    const { data, error } = await supabase
      .from('user_inventory')
      .select('*, skins(*)')
      .eq('user_id', userId);
    if (error) throw new Error(error.message);
    return data || [];
  }

  async getUserActiveSkin(userId: string): Promise<any | null> {
    const user = await this.getUserById(userId);
    if (!user || !user.active_skin_id) return null;
    return this.getSkinById(user.active_skin_id);
  }

  async setUserActiveSkin(userId: string, skinId: string): Promise<void> {
    if (this.useMock) return;
    const { error } = await supabase
      .from('users')
      .update({ active_skin_id: skinId })
      .eq('id', userId);
    if (error) throw new Error(error.message);
  }

  async addToInventory(userId: string, skinId: string): Promise<void> {
    if (this.useMock) return;
    const { error } = await supabase
      .from('user_inventory')
      .insert({ user_id: userId, skin_id: skinId });
    if (error) throw new Error(error.message);
  }

  async updateMiningXP(userId: string, xpGained: number): Promise<{ mining_xp: number; mining_level: number }> {
    const user = await this.getUserById(userId);
    if (!user) throw new Error('User not found');

    const currentXP = user.mining_xp || 0;
    const newXP = currentXP + xpGained;
    const newLevel = Math.floor(newXP / 1000) + 1;

    if (!this.useMock) {
      const { error } = await supabase
        .from('users')
        .update({ mining_xp: newXP, mining_level: newLevel })
        .eq('id', userId);
      if (error) throw new Error(error.message);
    }

    return { mining_xp: newXP, mining_level: newLevel };
  }

  // Deposits
  async createDeposit(
    userId: string,
    amountUsdt: number,
    nowpaymentsPaymentId: string,
    nowpaymentsOrderId: string,
    paymentAddress: string
  ): Promise<any> {
    if (this.useMock) {
      return {
        id: `deposit_${Date.now()}`,
        user_id: userId,
        amount_usdt: amountUsdt,
        nowpayments_payment_id: nowpaymentsPaymentId,
        nowpayments_order_id: nowpaymentsOrderId,
        payment_address: paymentAddress,
        payment_status: 'waiting',
        created_at: new Date().toISOString(),
      };
    }
    const { data, error } = await supabase
      .from('deposits')
      .insert({
        user_id: userId,
        amount_usdt: amountUsdt,
        nowpayments_payment_id: nowpaymentsPaymentId,
        nowpayments_order_id: nowpaymentsOrderId,
        payment_address: paymentAddress,
        payment_status: 'waiting',
      })
      .select()
      .single();
    if (error) throw new Error(error.message);
    return data;
  }

  async updateDepositStatus(
    paymentId: string,
    status: string,
    amountReceived?: number
  ): Promise<void> {
    if (this.useMock) return;
    const updates: any = { payment_status: status, updated_at: new Date().toISOString() };
    if (status === 'finished') {
      updates.confirmed_at = new Date().toISOString();
      if (amountReceived) updates.amount_received = amountReceived;
    }
    const { error } = await supabase
      .from('deposits')
      .update(updates)
      .eq('nowpayments_payment_id', paymentId);
    if (error) throw new Error(error.message);
  }

  async getDepositsByUser(userId: string): Promise<any[]> {
    if (this.useMock) return [];
    const { data, error } = await supabase
      .from('deposits')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false });
    if (error) throw new Error(error.message);
    return data || [];
  }

  async getAllDeposits(limit: number = 100): Promise<any[]> {
    if (this.useMock) return [];
    const { data, error } = await supabase
      .from('deposits')
      .select('*, users(username, email)')
      .order('created_at', { ascending: false })
      .limit(limit);
    if (error) throw new Error(error.message);
    return data || [];
  }

  // Notifications
  async createNotification(
    userId: string,
    type: string,
    title: string,
    message: string
  ): Promise<void> {
    if (this.useMock) return;
    await supabase.from('notifications').insert({
      user_id: userId,
      type,
      title,
      message,
    });
  }

  async getUserNotifications(userId: string, unreadOnly: boolean = false): Promise<any[]> {
    if (this.useMock) return [];
    let query = supabase
      .from('notifications')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false });
    if (unreadOnly) query = query.eq('is_read', false);
    const { data, error } = await query;
    if (error) throw new Error(error.message);
    return data || [];
  }

  async markNotificationRead(notificationId: string): Promise<void> {
    if (this.useMock) return;
    await supabase
      .from('notifications')
      .update({ is_read: true })
      .eq('id', notificationId);
  }

  async markAllNotificationsRead(userId: string): Promise<void> {
    if (this.useMock) return;
    await supabase
      .from('notifications')
      .update({ is_read: true })
      .eq('user_id', userId)
      .eq('is_read', false);
  }

  // Admin: User Management
  async setAdminStatus(userId: string, isBanned: boolean): Promise<void> {
    if (this.useMock) return;
    const { error } = await supabase
      .from('users')
      .update({ is_banned: isBanned })
      .eq('id', userId);
    if (error) throw new Error(error.message);
  }

  async adjustUserBalance(userId: string, amount: number, reason: string): Promise<number> {
    const user = await this.getUserById(userId);
    if (!user) throw new Error('User not found');
    const newBalance = Math.max(0, user.usdt_balance + amount);
    if (!this.useMock) {
      const { error } = await supabase
        .from('users')
        .update({ usdt_balance: newBalance })
        .eq('id', userId);
      if (error) throw new Error(error.message);
    }
    return newBalance;
  }

  async getAllUsers(limit: number = 100): Promise<any[]> {
    if (this.useMock) {
      return Array.from(mockUsers.values());
    }
    const { data, error } = await supabase
      .from('users')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(limit);
    if (error) throw new Error(error.message);
    return data || [];
  }

  // Admin: Withdrawal Management
  async getPendingWithdrawals(): Promise<any[]> {
    if (this.useMock) return [];
    try {
      const { data, error } = await supabase
        .from('withdrawals')
        .select('*')
        .eq('status', 'pending')
        .order('created_at', { ascending: true });
      if (error) {
        console.warn('getPendingWithdrawals error (table may not exist):', error.message);
        return [];
      }
      return data || [];
    } catch (e) {
      console.warn('getPendingWithdrawals failed:', e);
      return [];
    }
  }

  async getWithdrawalById(id: string): Promise<any | null> {
    if (this.useMock) return null;
    const { data, error } = await supabase
      .from('withdrawals')
      .select('*')
      .eq('id', id)
      .single();
    if (error) return null;
    return data;
  }

  async updateWithdrawalStatus(
    withdrawalId: string,
    status: string,
    adminNotes?: string,
    txHash?: string
  ): Promise<void> {
    if (this.useMock) return;
    const updates: any = {
      status,
      processed_at: new Date().toISOString(),
    };
    if (adminNotes) updates.admin_notes = adminNotes;
    if (txHash) updates.tx_hash = txHash;
    const { error } = await supabase
      .from('withdrawals')
      .update(updates)
      .eq('id', withdrawalId);
    if (error) throw new Error(error.message);
  }

  // Admin: Financial Stats
  async getFinancialStats(): Promise<any> {
    if (this.useMock) {
      return {
        total_deposits: 0,
        total_withdrawals: 0,
        pending_withdrawals: 0,
        total_users: mockUsers.size,
        active_sessions: 0,
      };
    }
    try {
      const { data: deposits } = await supabase.from('deposits').select('amount_usdt').eq('payment_status', 'finished');
      const { data: withdrawals } = await supabase.from('withdrawals').select('amount');
      const { data: pendingWithdrawals } = await supabase.from('withdrawals').select('amount').eq('status', 'pending');
      const { count: totalUsers } = await supabase.from('users').select('*', { count: 'exact', head: true });

      const totalDeposits = deposits?.reduce((sum: number, d: any) => sum + parseFloat(d.amount_usdt), 0) || 0;
      const totalWithdrawals = withdrawals?.reduce((sum: number, w: any) => sum + parseFloat(w.amount), 0) || 0;
      const pendingAmount = pendingWithdrawals?.reduce((sum: number, w: any) => sum + parseFloat(w.amount), 0) || 0;

      return {
        total_deposits: totalDeposits,
        total_withdrawals: totalWithdrawals,
        pending_withdrawals: pendingAmount,
        pending_count: pendingWithdrawals?.length || 0,
        total_users: totalUsers || 0,
        net_revenue: totalDeposits - totalWithdrawals,
      };
    } catch (e) {
      console.warn('getFinancialStats failed (tables may not exist):', e);
      return { total_deposits: 0, total_withdrawals: 0, pending_withdrawals: 0, pending_count: 0, total_users: mockUsers.size, net_revenue: 0 };
    }
  }

  // Bots
  async getAllBots(): Promise<any[]> {
    if (this.useMock) return [];
    const { data, error } = await supabase
      .from('bots')
      .select('*')
      .order('balance', { ascending: false });
    if (error) throw new Error(error.message);
    return data || [];
  }

  async getActiveBots(): Promise<any[]> {
    if (this.useMock) return [];
    const { data, error } = await supabase
      .from('bots')
      .select('*')
      .eq('is_active', true);
    if (error) throw new Error(error.message);
    return data || [];
  }

  async getBotById(botId: string): Promise<any | null> {
    if (this.useMock) return null;
    const { data, error } = await supabase
      .from('bots')
      .select('*')
      .eq('id', botId)
      .single();
    if (error) return null;
    return data;
  }

  async updateBot(botId: string, updates: any): Promise<void> {
    if (this.useMock) return;
    const { error } = await supabase
      .from('bots')
      .update(updates)
      .eq('id', botId);
    if (error) throw new Error(error.message);
  }

  async recordBotGame(botId: string, score: number, lines: number, won: boolean, prize: number, mmrChange: number): Promise<void> {
    if (this.useMock) return;
    await supabase.from('tournament_participants').insert({
      bot_id: botId,
      score,
      lines_cleared: lines,
      prize_amount: prize,
      mmr_change: mmrChange,
      placement: won ? 1 : 2,
    });
  }

  async getParticipantMmr(userId?: string, botId?: string): Promise<number> {
    if (userId) {
      const user = await this.getUserById(userId);
      return user?.mining_level ? user.mining_level * 100 : 1000;
    }
    if (botId) {
      const bot = await this.getBotById(botId);
      return bot?.mmr || 1000;
    }
    return 1000;
  }

  // Tournaments
  async createTournament(data: any): Promise<any> {
    if (this.useMock) {
      return { id: `tournament_${Date.now()}`, ...data };
    }
    const { data: result, error } = await supabase
      .from('tournaments')
      .insert(data)
      .select()
      .single();
    if (error) throw new Error(error.message);
    return result;
  }

  async getTournament(id: string): Promise<any | null> {
    if (this.useMock) return null;
    const { data, error } = await supabase
      .from('tournaments')
      .select('*')
      .eq('id', id)
      .single();
    if (error) return null;
    return data;
  }

  async getActiveTournaments(): Promise<any[]> {
    if (this.useMock) return [];
    const { data, error } = await supabase
      .from('tournaments')
      .select('*')
      .in('status', ['waiting', 'active'])
      .order('created_at', { ascending: false });
    if (error) throw new Error(error.message);
    return data || [];
  }

  async updateTournament(id: string, updates: any): Promise<void> {
    if (this.useMock) return;
    const { error } = await supabase
      .from('tournaments')
      .update(updates)
      .eq('id', id);
    if (error) throw new Error(error.message);
  }

  async addParticipant(tournamentId: string, userId: string | null, botId: string | null, score: number, lines: number): Promise<void> {
    if (this.useMock) return;
    await supabase.from('tournament_participants').insert({
      tournament_id: tournamentId,
      user_id: userId,
      bot_id: botId,
      score,
      lines_cleared: lines,
    });
  }

  async updateParticipant(participantId: string, updates: any): Promise<void> {
    if (this.useMock) return;
    const { error } = await supabase
      .from('tournament_participants')
      .update(updates)
      .eq('id', participantId);
    if (error) throw new Error(error.message);
  }

  async getTournamentParticipants(tournamentId: string): Promise<any[]> {
    if (this.useMock) return [];
    const { data, error } = await supabase
      .from('tournament_participants')
      .select('*, users(username), bots(name)')
      .eq('tournament_id', tournamentId)
      .order('placement', { ascending: true });
    if (error) throw new Error(error.message);
    return data || [];
  }

  async getUserTournamentHistory(userId: string, limit: number = 20): Promise<any[]> {
    if (this.useMock) return [];
    const { data, error } = await supabase
      .from('tournament_participants')
      .select('*, tournaments(type, entry_fee, rake), bots(name)')
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .limit(limit);
    if (error) throw new Error(error.message);
    return data || [];
  }

  async updateUserMMR(userId: string, mmr: number): Promise<void> {
    if (this.useMock) return;
    const level = Math.floor(mmr / 1000) + 1;
    const { error } = await supabase
      .from('users')
      .update({ mining_level: level })
      .eq('id', userId);
    if (error) throw new Error(error.message);
  }

  // Leaderboard
  async rebuildLeaderboardCache(): Promise<void> {
    if (this.useMock) return;
    await supabase.from('leaderboard_cache').delete().neq('id', '00000000-0000-0000-0000-000000000000');

    const { data: users } = await supabase
      .from('users')
      .select('id, username, mining_level, total_earned')
      .order('total_earned', { ascending: false })
      .limit(50);

    if (users) {
      for (const u of users) {
        await supabase.from('leaderboard_cache').insert({
          user_id: u.id,
          display_name: u.username || 'Unknown',
          total_won: u.total_earned || 0,
          mmr: (u.mining_level || 1) * 100,
          is_bot: false,
        });
      }
    }

    const { data: bots } = await supabase
      .from('bots')
      .select('id, name, mmr, balance, win_rate')
      .eq('is_active', true)
      .order('balance', { ascending: false })
      .limit(20);

    if (bots) {
      for (const b of bots) {
        await supabase.from('leaderboard_cache').insert({
          bot_id: b.id,
          display_name: b.name,
          total_won: b.balance || 0,
          mmr: b.mmr || 1000,
          win_rate: b.win_rate || 50,
          is_bot: true,
        });
      }
    }
  }

  async getAllEconomyConfig(): Promise<Record<string, any>> {
    if (this.useMock) {
      return {
        rake_config: { quick_duel: 20, standard: 15, premium: 12, elite: 10, freeroll: 0 },
        bot_config: { active_count: 20, global_win_rate: 55, winners_per_8: 4, losers_per_8: 4 },
        tournament_frequency: { quick_duel_minutes: 2, standard_minutes: 10, premium_minutes: 30 },
        vip_config: {
          bronze: { price: 9.99, rake_discount: 3 },
          gold: { price: 24.99, rake_discount: 5 },
          diamond: { price: 49.99, rake_discount: 7 },
        },
        withdrawal_config: { min: 5, max: 10000, fee_percent: 2, fee_minimum: 0.50 },
      };
    }
    const { data, error } = await supabase
      .from('economy_config')
      .select('key, value');
    if (error) throw new Error(error.message);
    const result: Record<string, any> = {};
    for (const row of data || []) {
      result[row.key] = row.value;
    }
    return result;
  }

  async getEconomyConfig(key: string): Promise<any> {
    if (this.useMock) {
      const all = await this.getAllEconomyConfig();
      return all[key] || null;
    }
    const { data, error } = await supabase
      .from('economy_config')
      .select('value')
      .eq('key', key)
      .single();
    if (error) return null;
    return data?.value;
  }

  async updateEconomyConfig(key: string, value: any): Promise<void> {
    if (this.useMock) return;
    const { error } = await supabase
      .from('economy_config')
      .upsert({ key, value, updated_at: new Date().toISOString() });
    if (error) throw new Error(error.message);
  }

  // Audit Logs
  async createAuditLog(
    adminUserId: string,
    action: string,
    targetType: string,
    targetId: string,
    details: any,
    ipAddress: string
  ): Promise<void> {
    if (this.useMock) {
      console.log(`[AUDIT] ${action} by ${adminUserId} on ${targetType}:${targetId}`);
      return;
    }
    await supabase.from('audit_logs').insert({
      admin_user_id: adminUserId,
      action,
      target_type: targetType,
      target_id: targetId,
      details,
      ip_address: ipAddress,
    });
  }

  async getFinancialStatsEnhanced(): Promise<any> {
    if (this.useMock) {
      return {
        total_deposits: 0,
        total_withdrawals: 0,
        pending_withdrawals: 0,
        pending_count: 0,
        total_users: mockUsers.size,
        active_users_24h: 0,
        active_users_7d: 0,
        net_revenue: 0,
        total_fees_collected: 0,
        total_games_played: 0,
        total_tournaments: 0,
        total_payouts: 0,
        house_edge_revenue: 0,
        avg_deposit: 0,
        avg_withdrawal: 0,
        deposit_count: 0,
        withdrawal_count: 0,
        completed_withdrawals: 0,
        failed_withdrawals: 0,
        total_deposited_all_time: 0,
        total_withdrawn_all_time: 0,
        hot_wallet_exposure: 0,
        deposit_conversion_rate: 0,
        avg_user_balance: 0,
        total_user_balances: 0,
        deposits_today: 0,
        withdrawals_today: 0,
        users_today: 0,
        games_today: 0,
        revenue_today: 0,
        revenue_7d: 0,
        revenue_30d: 0,
      };
    }

    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000).toISOString();
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString();

    const [
      { data: deposits },
      { data: depositsToday },
      { data: deposits7d },
      { data: deposits30d },
      { data: withdrawals },
      { data: withdrawalsToday },
      { data: pendingWithdrawals },
      { count: totalUsers },
      { count: activeUsers24h },
      { count: activeUsers7d },
      { data: gamesPlayed },
      { data: gamesToday },
      { data: tournaments },
    ] = await Promise.all([
      supabase.from('deposits').select('amount_usdt').eq('payment_status', 'finished'),
      supabase.from('deposits').select('amount_usdt').eq('payment_status', 'finished').gte('confirmed_at', todayStart),
      supabase.from('deposits').select('amount_usdt').eq('payment_status', 'finished').gte('confirmed_at', sevenDaysAgo),
      supabase.from('deposits').select('amount_usdt').eq('payment_status', 'finished').gte('confirmed_at', thirtyDaysAgo),
      supabase.from('withdrawals').select('amount, fee, status'),
      supabase.from('withdrawals').select('amount').eq('status', 'completed').gte('processed_at', todayStart),
      supabase.from('withdrawals').select('amount').eq('status', 'pending'),
      supabase.from('users').select('*', { count: 'exact', head: true }),
      supabase.from('users').select('*', { count: 'exact', head: true }).gte('last_active_at', new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString()),
      supabase.from('users').select('*', { count: 'exact', head: true }).gte('last_active_at', sevenDaysAgo),
      supabase.from('game_sessions').select('payout_usdt, score').not('payout_usdt', 'is', null),
      supabase.from('game_sessions').select('id').gte('started_at', todayStart),
      supabase.from('tournaments').select('prize_pool, rake, entry_fee').eq('status', 'completed'),
    ]);

    const totalDeposits = deposits?.reduce((s: number, d: any) => s + parseFloat(d.amount_usdt), 0) || 0;
    const depositsTodayAmount = depositsToday?.reduce((s: number, d: any) => s + parseFloat(d.amount_usdt), 0) || 0;
    const deposits7dAmount = deposits7d?.reduce((s: number, d: any) => s + parseFloat(d.amount_usdt), 0) || 0;
    const deposits30dAmount = deposits30d?.reduce((s: number, d: any) => s + parseFloat(d.amount_usdt), 0) || 0;

    const totalWithdrawals = withdrawals?.reduce((s: number, w: any) => s + parseFloat(w.amount), 0) || 0;
    const totalFees = withdrawals?.reduce((s: number, w: any) => s + parseFloat(w.fee || 0), 0) || 0;
    const completedWithdrawals = withdrawals?.filter((w: any) => w.status === 'completed').length || 0;
    const failedWithdrawals = withdrawals?.filter((w: any) => w.status === 'failed' || w.status === 'rejected').length || 0;
    const withdrawalsTodayAmount = withdrawalsToday?.reduce((s: number, w: any) => s + parseFloat(w.amount), 0) || 0;

    const pendingAmount = pendingWithdrawals?.reduce((s: number, w: any) => s + parseFloat(w.amount), 0) || 0;
    const totalPayouts = gamesPlayed?.reduce((s: number, g: any) => s + parseFloat(g.payout_usdt || 0), 0) || 0;
    const tournamentRake = tournaments?.reduce((s: number, t: any) => s + parseFloat(t.rake || 0), 0) || 0;

    const netRevenue = totalDeposits - totalWithdrawals;
    const houseEdgeRevenue = totalPayouts > 0 ? (totalDeposits - totalPayouts) : 0;
    const depositCount = deposits?.length || 0;
    const withdrawalCount = withdrawals?.length || 0;
    const avgDeposit = depositCount > 0 ? totalDeposits / depositCount : 0;
    const avgWithdrawal = completedWithdrawals > 0 ? totalWithdrawals / completedWithdrawals : 0;

    const { data: allUsers } = await supabase.from('users').select('usdt_balance, total_deposited');
    const totalUserBalances = allUsers?.reduce((s: number, u: any) => s + parseFloat(u.usdt_balance || 0), 0) || 0;
    const totalDepositedAllTime = allUsers?.reduce((s: number, u: any) => s + parseFloat(u.total_deposited || 0), 0) || 0;
    const avgUserBalance = (allUsers?.length || 0) > 0 ? totalUserBalances / allUsers!.length : 0;

    const usersWhoDeposited = new Set(deposits?.map((d: any) => d.user_id)).size;
    const depositConversionRate = (totalUsers || 0) > 0 ? (usersWhoDeposited / (totalUsers as number)) * 100 : 0;

    const revenueToday = depositsTodayAmount - withdrawalsTodayAmount;
    const revenue7d = deposits7dAmount - (withdrawals?.filter((w: any) => w.status === 'completed' && w.processed_at >= sevenDaysAgo).reduce((s: number, w: any) => s + parseFloat(w.amount), 0) || 0);
    const revenue30d = deposits30dAmount - (withdrawals?.filter((w: any) => w.status === 'completed' && w.processed_at >= thirtyDaysAgo).reduce((s: number, w: any) => s + parseFloat(w.amount), 0) || 0);

    return {
      total_deposits: totalDeposits,
      total_withdrawals: totalWithdrawals,
      pending_withdrawals: pendingAmount,
      pending_count: pendingWithdrawals?.length || 0,
      total_users: totalUsers || 0,
      active_users_24h: activeUsers24h || 0,
      active_users_7d: activeUsers7d || 0,
      net_revenue: netRevenue,
      total_fees_collected: totalFees,
      total_games_played: gamesPlayed?.length || 0,
      total_tournaments: tournaments?.length || 0,
      total_payouts: totalPayouts,
      house_edge_revenue: houseEdgeRevenue + tournamentRake,
      avg_deposit: avgDeposit,
      avg_withdrawal: avgWithdrawal,
      deposit_count: depositCount,
      withdrawal_count: withdrawalCount,
      completed_withdrawals: completedWithdrawals,
      failed_withdrawals: failedWithdrawals,
      total_deposited_all_time: totalDepositedAllTime,
      total_withdrawn_all_time: totalWithdrawals,
      hot_wallet_exposure: pendingAmount,
      deposit_conversion_rate: depositConversionRate,
      avg_user_balance: avgUserBalance,
      total_user_balances: totalUserBalances,
      deposits_today: depositsTodayAmount,
      withdrawals_today: withdrawalsTodayAmount,
      users_today: activeUsers24h || 0,
      games_today: gamesToday?.length || 0,
      revenue_today: revenueToday,
      revenue_7d: revenue7d,
      revenue_30d: revenue30d,
    };
  }

  async getRevenueByPeriod(days: number = 30): Promise<any[]> {
    if (this.useMock) return [];

    const { data: deposits } = await supabase
      .from('deposits')
      .select('amount_usdt, confirmed_at, created_at')
      .eq('payment_status', 'finished')
      .gte('created_at', new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString())
      .order('created_at', { ascending: true });

    const { data: withdrawals } = await supabase
      .from('withdrawals')
      .select('amount, processed_at, status')
      .eq('status', 'completed')
      .gte('processed_at', new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString())
      .order('processed_at', { ascending: true });

    const dailyData: Record<string, { date: string; deposits: number; withdrawals: number; net: number; games: number; users: number }> = {};

    for (let i = days - 1; i >= 0; i--) {
      const date = new Date(Date.now() - i * 24 * 60 * 60 * 1000);
      const key = date.toISOString().split('T')[0];
      dailyData[key] = { date: key, deposits: 0, withdrawals: 0, net: 0, games: 0, users: 0 };
    }

    deposits?.forEach((d: any) => {
      const key = (d.confirmed_at || d.created_at).split('T')[0];
      if (dailyData[key]) dailyData[key].deposits += parseFloat(d.amount_usdt);
    });

    withdrawals?.forEach((w: any) => {
      const key = w.processed_at.split('T')[0];
      if (dailyData[key]) dailyData[key].withdrawals += parseFloat(w.amount);
    });

    const { data: games } = await supabase
      .from('game_sessions')
      .select('user_id, started_at')
      .gte('started_at', new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString());

    games?.forEach((g: any) => {
      const key = g.started_at.split('T')[0];
      if (dailyData[key]) {
        dailyData[key].games += 1;
      }
    });

    Object.values(dailyData).forEach((d: any) => {
      d.net = d.deposits - d.withdrawals;
    });

    return Object.values(dailyData).sort((a: any, b: any) => a.date.localeCompare(b.date));
  }

  async getAllWithdrawals(limit: number = 100): Promise<any[]> {
    if (this.useMock) return [];
    const { data, error } = await supabase
      .from('withdrawals')
      .select('*, users(username, email)')
      .order('created_at', { ascending: false })
      .limit(limit);
    if (error) throw new Error(error.message);
    return data || [];
  }

  async updateTotalDeposited(userId: string, amount: number): Promise<void> {
    if (this.useMock) return;
    const user = await this.getUserById(userId);
    if (!user) return;
    const newTotal = parseFloat((((user as any).total_deposited || 0) + amount).toFixed(8));
    await supabase.from('users').update({ total_deposited: newTotal }).eq('id', userId);
  }

  async updateLastActive(userId: string): Promise<void> {
    if (this.useMock) return;
    await supabase.from('users').update({ last_active_at: new Date().toISOString() }).eq('id', userId);
  }
}

export const db = new DatabaseService();