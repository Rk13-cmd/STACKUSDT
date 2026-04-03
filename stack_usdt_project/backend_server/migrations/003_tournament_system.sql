-- ============================================================
-- STACK USDT: Tournament System + Bots + Economy
-- ============================================================

-- 1. Tabla de bots
CREATE TABLE IF NOT EXISTS bots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  mmr INT DEFAULT 1000,
  win_rate NUMERIC(5,2) DEFAULT 50.00,
  balance NUMERIC(10,4) DEFAULT 0,
  tier TEXT DEFAULT 'Bronze',
  is_active BOOLEAN DEFAULT true,
  play_pattern TEXT DEFAULT 'normal',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Tabla de torneos
CREATE TABLE IF NOT EXISTS tournaments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL,
  entry_fee NUMERIC(10,4) NOT NULL,
  rake NUMERIC(5,2) NOT NULL,
  prize_pool NUMERIC(10,4) DEFAULT 0,
  prize_pool_net NUMERIC(10,4) DEFAULT 0,
  max_players INT NOT NULL,
  current_players INT DEFAULT 0,
  status TEXT DEFAULT 'waiting',
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Participantes del torneo
CREATE TABLE IF NOT EXISTS tournament_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id UUID REFERENCES tournaments(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  bot_id UUID REFERENCES bots(id) ON DELETE CASCADE,
  score INT DEFAULT 0,
  lines_cleared INT DEFAULT 0,
  placement INT,
  prize_amount NUMERIC(10,4) DEFAULT 0,
  mmr_change INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Config de economía
CREATE TABLE IF NOT EXISTS economy_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT NOT NULL UNIQUE,
  value JSONB NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Leaderboard cache
CREATE TABLE IF NOT EXISTS leaderboard_cache (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  bot_id UUID REFERENCES bots(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL,
  total_won NUMERIC(10,4) DEFAULT 0,
  mmr INT DEFAULT 1000,
  tournaments_played INT DEFAULT 0,
  win_rate NUMERIC(5,2) DEFAULT 0,
  is_bot BOOLEAN DEFAULT false,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Actualizar tabla users
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS is_bot BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS bot_config_id UUID REFERENCES bots(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS vip_tier TEXT DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS vip_expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS tickets_owned INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS current_streak INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS loss_streak INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS missions_completed JSONB DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS rake_discount NUMERIC(5,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMPTZ DEFAULT NOW();

-- 7. Insertar 20 bots realistas
INSERT INTO bots (name, mmr, win_rate, balance, tier, is_active) VALUES
  ('CryptoKing_7x', 2450, 68.5, 12450.00, 'Diamond', true),
  ('NeonStacker', 1890, 55.2, 3200.00, 'Plat', true),
  ('BlockMaster42', 1200, 42.0, 890.00, 'Gold', true),
  ('TetrisWhale', 2800, 72.3, 45000.00, 'Diamond', true),
  ('StackNinja_99', 1650, 48.7, 1500.00, 'Gold', true),
  ('DiamondHands_T', 2100, 61.4, 8900.00, 'Plat', true),
  ('GridRunner', 950, 38.5, 320.00, 'Silver', true),
  ('MinoCrusher', 1450, 52.1, 2100.00, 'Gold', true),
  ('LaserClear', 2650, 70.8, 28000.00, 'Diamond', true),
  ('PixelStacker', 1100, 44.3, 650.00, 'Silver', true),
  ('TurboDrop_X', 1780, 56.9, 4200.00, 'Plat', true),
  ('NeonTetris', 2200, 63.2, 15600.00, 'Plat', true),
  ('BlockBarron', 800, 35.0, 180.00, 'Bronze', true),
  ('StackOverflow', 1350, 49.8, 1200.00, 'Gold', true),
  ('ClearLine_Pro', 2550, 69.1, 22000.00, 'Diamond', true),
  ('RapidFire_T', 1550, 51.3, 1800.00, 'Gold', true),
  ('GhostPiece', 1950, 58.4, 6700.00, 'Plat', true),
  ('ComboKing', 1050, 41.2, 480.00, 'Silver', true),
  ('MaxClear_24', 2350, 65.7, 18500.00, 'Diamond', true),
  ('SpinMaster', 1700, 53.6, 2800.00, 'Gold', true)
ON CONFLICT (name) DO NOTHING;

-- 8. Config inicial de economía
INSERT INTO economy_config (key, value) VALUES
  ('rake_config', '{"quick_duel": 20, "standard": 15, "premium": 12, "elite": 10, "freeroll": 0}'),
  ('tournament_frequency', '{"quick_duel_minutes": 2, "standard_minutes": 10, "premium_minutes": 30, "elite_per_day": 1, "freeroll_per_day": 2}'),
  ('bot_config', '{"active_count": 20, "global_win_rate": 55, "winners_per_8": 4, "losers_per_8": 4}'),
  ('vip_config', '{"bronze": {"price": 9.99, "rake_discount": 3, "freerolls_per_week": 1}, "gold": {"price": 24.99, "rake_discount": 5, "freerolls_per_week": 3}, "diamond": {"price": 49.99, "rake_discount": 7, "freerolls_per_week": 999}}'),
  ('withdrawal_config', '{"min": 5, "max": 10000, "fee_percent": 2, "fee_minimum": 0.50, "rollover_multiplier": 1}')
ON CONFLICT (key) DO NOTHING;

-- 9. RLS Policies
ALTER TABLE bots ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Bots publicly viewable" ON bots;
CREATE POLICY "Bots publicly viewable" ON bots FOR SELECT USING (true);

ALTER TABLE tournaments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Tournaments publicly viewable" ON tournaments;
CREATE POLICY "Tournaments publicly viewable" ON tournaments FOR SELECT USING (true);

ALTER TABLE tournament_participants ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Participants viewable" ON tournament_participants;
CREATE POLICY "Participants viewable" ON tournament_participants FOR SELECT USING (true);

ALTER TABLE leaderboard_cache ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Leaderboard publicly viewable" ON leaderboard_cache;
CREATE POLICY "Leaderboard publicly viewable" ON leaderboard_cache FOR SELECT USING (true);

ALTER TABLE economy_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Economy config readable" ON economy_config;
CREATE POLICY "Economy config readable" ON economy_config FOR SELECT USING (true);

-- 10. Índices
CREATE INDEX IF NOT EXISTS idx_tournaments_status ON tournaments(status);
CREATE INDEX IF NOT EXISTS idx_tournaments_type ON tournaments(type);
CREATE INDEX IF NOT EXISTS idx_tournament_participants_tournament ON tournament_participants(tournament_id);
CREATE INDEX IF NOT EXISTS idx_tournament_participants_user ON tournament_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_tournament_participants_bot ON tournament_participants(bot_id);
CREATE INDEX IF NOT EXISTS idx_leaderboard_cache_won ON leaderboard_cache(total_won DESC);
CREATE INDEX IF NOT EXISTS idx_leaderboard_cache_bot ON leaderboard_cache(is_bot, total_won DESC);
