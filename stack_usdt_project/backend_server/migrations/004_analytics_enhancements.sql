-- ============================================
-- MIGRATION 004: Analytics & Admin Enhancements
-- ============================================

-- Add new columns to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS total_deposited DECIMAL(18,8) DEFAULT 0.00000000;
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Add indexes for analytics queries
CREATE INDEX IF NOT EXISTS idx_users_last_active ON users(last_active_at DESC);
CREATE INDEX IF NOT EXISTS idx_users_total_deposited ON users(total_deposited DESC);

-- Add indexes to deposits for faster analytics
CREATE INDEX IF NOT EXISTS idx_deposits_status ON deposits(payment_status);
CREATE INDEX IF NOT EXISTS idx_deposits_confirmed ON deposits(confirmed_at DESC) WHERE confirmed_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_deposits_user_status ON deposits(user_id, payment_status);

-- Add indexes to withdrawals for analytics
CREATE INDEX IF NOT EXISTS idx_withdrawals_status ON withdrawals(status);
CREATE INDEX IF NOT EXISTS idx_withdrawals_processed ON withdrawals(processed_at DESC) WHERE processed_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_withdrawals_user_status ON withdrawals(user_id, status);

-- Add indexes to game_sessions for analytics
CREATE INDEX IF NOT EXISTS idx_game_sessions_started ON game_sessions(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_game_sessions_user_date ON game_sessions(user_id, started_at DESC);

-- Ensure audit_logs table exists with proper structure
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_user_id UUID REFERENCES users(id),
  action TEXT NOT NULL,
  target_type TEXT,
  target_id TEXT,
  details JSONB,
  ip_address TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_admin ON audit_logs(admin_user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_date ON audit_logs(created_at DESC);

-- Financial daily snapshots table (for historical reporting)
CREATE TABLE IF NOT EXISTS financial_daily_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_date DATE NOT NULL UNIQUE,
  total_deposits DECIMAL(18,8) DEFAULT 0,
  total_withdrawals DECIMAL(18,8) DEFAULT 0,
  net_revenue DECIMAL(18,8) DEFAULT 0,
  active_users INT DEFAULT 0,
  games_played INT DEFAULT 0,
  tournaments_completed INT DEFAULT 0,
  total_fees DECIMAL(18,8) DEFAULT 0,
  new_users INT DEFAULT 0,
  deposit_count INT DEFAULT 0,
  withdrawal_count INT DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_daily_snapshots_date ON financial_daily_snapshots(snapshot_date DESC);

-- Function to create daily snapshot (call via cron or manually)
CREATE OR REPLACE FUNCTION create_daily_snapshot(p_date DATE DEFAULT CURRENT_DATE)
RETURNS VOID AS $$
BEGIN
  INSERT INTO financial_daily_snapshots (
    snapshot_date,
    total_deposits,
    total_withdrawals,
    net_revenue,
    active_users,
    games_played,
    tournaments_completed,
    total_fees,
    new_users,
    deposit_count,
    withdrawal_count
  )
  SELECT
    p_date,
    COALESCE((SELECT SUM(amount_usdt) FROM deposits WHERE payment_status = 'finished' AND DATE(confirmed_at) = p_date), 0),
    COALESCE((SELECT SUM(amount) FROM withdrawals WHERE status = 'completed' AND DATE(processed_at) = p_date), 0),
    0, -- net_revenue calculated after
    COALESCE((SELECT COUNT(DISTINCT user_id) FROM game_sessions WHERE DATE(started_at) = p_date), 0),
    COALESCE((SELECT COUNT(*) FROM game_sessions WHERE DATE(started_at) = p_date), 0),
    COALESCE((SELECT COUNT(*) FROM tournaments WHERE status = 'completed' AND DATE(completed_at) = p_date), 0),
    COALESCE((SELECT SUM(fee) FROM withdrawals WHERE status = 'completed' AND DATE(processed_at) = p_date), 0),
    COALESCE((SELECT COUNT(*) FROM users WHERE DATE(created_at) = p_date), 0),
    COALESCE((SELECT COUNT(*) FROM deposits WHERE payment_status = 'finished' AND DATE(confirmed_at) = p_date), 0),
    COALESCE((SELECT COUNT(*) FROM withdrawals WHERE DATE(created_at) = p_date), 0)
  ON CONFLICT (snapshot_date) DO UPDATE SET
    total_deposits = EXCLUDED.total_deposits,
    total_withdrawals = EXCLUDED.total_withdrawals,
    active_users = EXCLUDED.active_users,
    games_played = EXCLUDED.games_played,
    tournaments_completed = EXCLUDED.tournaments_completed,
    total_fees = EXCLUDED.total_fees,
    new_users = EXCLUDED.new_users,
    deposit_count = EXCLUDED.deposit_count,
    withdrawal_count = EXCLUDED.withdrawal_count;

  UPDATE financial_daily_snapshots
  SET net_revenue = total_deposits - total_withdrawals
  WHERE snapshot_date = p_date;
END;
$$ LANGUAGE plpgsql;

-- RLS policies for audit_logs
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view audit logs" ON audit_logs
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.is_admin = true)
  );

CREATE POLICY "System can insert audit logs" ON audit_logs
  FOR INSERT WITH CHECK (true);

-- RLS for financial_daily_snapshots
ALTER TABLE financial_daily_snapshots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view snapshots" ON financial_daily_snapshots
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.is_admin = true)
  );
