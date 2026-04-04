-- ============================================
-- MIGRATION 005: Bonuses, Referrals, Missions, Staking
-- ============================================

-- BONUSES TABLE
CREATE TABLE IF NOT EXISTS bonuses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  amount_usdt DECIMAL(18,8) NOT NULL,
  amount_percent DECIMAL(5,2),
  description TEXT,
  min_deposit DECIMAL(18,8) DEFAULT 0,
  max_uses INT DEFAULT NULL,
  current_uses INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  starts_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bonuses_active ON bonuses(is_active, expires_at);

-- USER BONUSES TABLE
CREATE TABLE IF NOT EXISTS user_bonuses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  bonus_id UUID REFERENCES bonuses(id) ON DELETE CASCADE,
  amount_usdt DECIMAL(18,8) NOT NULL,
  status TEXT DEFAULT 'pending',
  claimed_at TIMESTAMP WITH TIME ZONE,
  expires_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_bonuses_user ON user_bonuses(user_id, status);
CREATE INDEX IF NOT EXISTS idx_user_bonuses_bonus ON user_bonuses(bonus_id);

-- REFERRAL EARNINGS TABLE
CREATE TABLE IF NOT EXISTS referral_earnings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id UUID REFERENCES users(id) ON DELETE CASCADE,
  referred_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  level INT DEFAULT 1,
  amount_usdt DECIMAL(18,8) NOT NULL,
  source_deposit_id UUID,
  status TEXT DEFAULT 'pending',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_referral_earnings_referrer ON referral_earnings(referrer_id, status);
CREATE INDEX IF NOT EXISTS idx_referral_earnings_referred ON referral_earnings(referred_user_id);

-- MISSIONS TABLE
CREATE TABLE IF NOT EXISTS missions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  description TEXT,
  requirement_value INT DEFAULT 1,
  reward_usdt DECIMAL(18,8) NOT NULL,
  reward_xp INT DEFAULT 0,
  period TEXT DEFAULT 'daily',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_missions_active ON missions(is_active, period);

-- USER MISSION PROGRESS TABLE
CREATE TABLE IF NOT EXISTS user_mission_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  mission_id UUID REFERENCES missions(id) ON DELETE CASCADE,
  progress_value INT DEFAULT 0,
  is_completed BOOLEAN DEFAULT false,
  is_claimed BOOLEAN DEFAULT false,
  period_start DATE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, mission_id, period_start)
);

CREATE INDEX IF NOT EXISTS idx_user_missions_user ON user_mission_progress(user_id, period_start);
CREATE INDEX IF NOT EXISTS idx_user_missions_mission ON user_mission_progress(mission_id, period_start);

-- STAKING TABLE
CREATE TABLE IF NOT EXISTS user_staking (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  amount_usdt DECIMAL(18,8) NOT NULL,
  annual_rate DECIMAL(5,2) DEFAULT 10.00,
  started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_reward_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  total_earned_usdt DECIMAL(18,8) DEFAULT 0,
  status TEXT DEFAULT 'active',
  unstaked_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_staking_user ON user_staking(user_id, status);
CREATE INDEX IF NOT EXISTS idx_staking_active ON user_staking(status) WHERE status = 'active';

-- STAKING REWARDS LOG
CREATE TABLE IF NOT EXISTS staking_rewards_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staking_id UUID REFERENCES user_staking(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  amount_usdt DECIMAL(18,8) NOT NULL,
  reward_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_staking_rewards_user ON staking_rewards_log(user_id, reward_date DESC);

-- SEED DEFAULT BONUSES
INSERT INTO bonuses (name, type, amount_usdt, amount_percent, description, min_deposit, max_uses, expires_at) VALUES
('Welcome Bonus', 'first_deposit', 0, 10.00, '10% extra on your first deposit', 10, NULL, NOW() + INTERVAL '365 days'),
('Reload Bonus', 'reload', 0, 5.00, '5% extra on deposits over $50', 50, NULL, NOW() + INTERVAL '365 days'),
('VIP Welcome', 'vip_bonus', 25.00, 0, '$25 bonus for VIP Diamond members', 0, NULL, NOW() + INTERVAL '365 days')
ON CONFLICT DO NOTHING;

-- SEED DEFAULT MISSIONS
INSERT INTO missions (name, type, description, requirement_value, reward_usdt, reward_xp, period) VALUES
('Play 5 Games', 'games_played', 'Complete 5 games in a day', 5, 0.50, 50, 'daily'),
('Play 20 Games', 'games_played', 'Complete 20 games in a day', 20, 2.00, 200, 'daily'),
('Clear 50 Lines', 'lines_cleared', 'Clear 50 lines in a day', 50, 1.00, 100, 'daily'),
('Clear 200 Lines', 'lines_cleared', 'Clear 200 lines in a day', 200, 5.00, 500, 'daily'),
('Score 1000+', 'high_score', 'Achieve a score over 1000 in one game', 1000, 1.00, 100, 'daily'),
('Score 5000+', 'high_score', 'Achieve a score over 5000 in one game', 5000, 5.00, 500, 'daily'),
('Join 3 Tournaments', 'tournaments_joined', 'Join 3 tournaments in a week', 3, 2.00, 0, 'weekly'),
('Win a Tournament', 'tournament_win', 'Win 1st place in any tournament', 1, 10.00, 1000, 'weekly'),
('Deposit $50+', 'deposit', 'Deposit $50 or more in a week', 50, 3.00, 0, 'weekly'),
('Play 100 Games', 'games_played', 'Complete 100 games in a month', 100, 15.00, 1500, 'monthly')
ON CONFLICT DO NOTHING;

-- RLS Policies
ALTER TABLE bonuses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Bonuses are readable by all" ON bonuses FOR SELECT USING (true);
CREATE POLICY "Only admins can modify bonuses" ON bonuses FOR ALL USING (
  EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.is_admin = true)
);

ALTER TABLE user_bonuses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users see own bonuses" ON user_bonuses FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "System can insert user bonuses" ON user_bonuses FOR INSERT WITH CHECK (true);

ALTER TABLE referral_earnings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users see own referral earnings" ON referral_earnings FOR SELECT USING (auth.uid() = referrer_id);
CREATE POLICY "System can insert referral earnings" ON referral_earnings FOR INSERT WITH CHECK (true);

ALTER TABLE missions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Missions are readable by all" ON missions FOR SELECT USING (true);
CREATE POLICY "Only admins can modify missions" ON missions FOR ALL USING (
  EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.is_admin = true)
);

ALTER TABLE user_mission_progress ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users see own mission progress" ON user_mission_progress FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "System can insert/update mission progress" ON user_mission_progress FOR ALL WITH CHECK (true);

ALTER TABLE user_staking ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users see own staking" ON user_staking FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can manage own staking" ON user_staking FOR ALL USING (auth.uid() = user_id);

ALTER TABLE staking_rewards_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users see own staking rewards" ON staking_rewards_log FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "System can insert staking rewards" ON staking_rewards_log FOR INSERT WITH CHECK (true);
