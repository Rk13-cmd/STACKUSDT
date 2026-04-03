export interface User {
  id: string;
  email: string;
  username: string | null;
  usdt_balance: number;
  total_earned: number;
  total_withdrawn: number;
  created_at: string;
  is_banned: boolean;
  wallet_address: string | null;
  referral_code: string | null;
  mining_xp: number;
  mining_level: number;
  active_skin_id: string | null;
  is_admin: boolean;
}

export interface GameSession {
  id: string;
  user_id: string;
  started_at: string;
  ended_at: string | null;
  duration_seconds: number;
  score: number;
  lines_cleared: number;
  level_reached: number;
  payout_usdt: number;
  is_valid: boolean;
  validation_notes: string | null;
}

export interface Withdrawal {
  id: string;
  user_id: string;
  amount: number;
  fee: number;
  net_amount: number;
  wallet_address: string;
  network: string;
  status: 'pending' | 'processing' | 'completed' | 'failed' | 'cancelled';
  tx_hash: string | null;
  created_at: string;
  processed_at: string | null;
}

export interface LeaderboardEntry {
  user_id: string;
  username: string;
  high_score: number;
  total_lines: number;
  games_played: number;
  max_level: number;
}

export interface SystemConfig {
  key: string;
  value: string;
  description: string | null;
}

export interface GameStartRequest {
  user_id: string;
  device_fingerprint?: string;
}

export interface GameEndRequest {
  session_id: string;
  lines_cleared: number;
  play_time_seconds: number;
  score: number;
}

export interface WithdrawalRequest {
  user_id: string;
  amount: number;
  wallet_address: string;
  network?: string;
}
