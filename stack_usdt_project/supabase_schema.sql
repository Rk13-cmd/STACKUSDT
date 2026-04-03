-- ============================================
-- STACK USDT - Supabase Database Schema
-- Ejecuta este script en el SQL Editor de Supabase
-- ============================================

-- ============================================
-- TABLA DE USUARIOS
-- ============================================
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  username TEXT,
  usdt_balance DECIMAL(18,8) DEFAULT 0.00000000,
  total_earned DECIMAL(18,8) DEFAULT 0.00000000,
  total_withdrawn DECIMAL(18,8) DEFAULT 0.00000000,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_banned BOOLEAN DEFAULT FALSE,
  wallet_address TEXT,
  referral_code TEXT UNIQUE,
  referred_by UUID REFERENCES users(id)
);

-- Índice para búsquedas rápidas
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_referral ON users(referral_code);

-- ============================================
-- TABLA DE SESIONES DE JUEGO
-- ============================================
CREATE TABLE IF NOT EXISTS game_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  ended_at TIMESTAMP WITH TIME ZONE,
  duration_seconds INTEGER DEFAULT 0,
  score INTEGER DEFAULT 0,
  lines_cleared INTEGER DEFAULT 0,
  level_reached INTEGER DEFAULT 1,
  payout_usdt DECIMAL(18,8) DEFAULT 0.00000000,
  is_valid BOOLEAN DEFAULT TRUE,
  validation_notes TEXT,
  device_fingerprint TEXT,
  ip_address TEXT
);

CREATE INDEX idx_sessions_user ON game_sessions(user_id);
CREATE INDEX idx_sessions_date ON game_sessions(started_at DESC);

-- ============================================
-- TABLA DE TRANSACCIONES (RETIROS)
-- ============================================
CREATE TABLE IF NOT EXISTS withdrawals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  amount DECIMAL(18,8) NOT NULL,
  fee DECIMAL(18,8) DEFAULT 0.00000000,
  net_amount DECIMAL(18,8) NOT NULL,
  wallet_address TEXT NOT NULL,
  network TEXT DEFAULT 'TRC20',
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'cancelled')),
  tx_hash TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  processed_at TIMESTAMP WITH TIME ZONE,
  admin_note TEXT
);

CREATE INDEX idx_withdrawals_user ON withdrawals(user_id);
CREATE INDEX idx_withdrawals_status ON withdrawals(status);

-- ============================================
-- TABLA DE LEADERBOARD
-- ============================================
CREATE TABLE IF NOT EXISTS leaderboard (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE UNIQUE,
  username TEXT,
  high_score INTEGER DEFAULT 0,
  total_lines INTEGER DEFAULT 0,
  games_played INTEGER DEFAULT 0,
  max_level INTEGER DEFAULT 1,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_leaderboard_score ON leaderboard(high_score DESC);
CREATE INDEX idx_leaderboard_lines ON leaderboard(total_lines DESC);

-- ============================================
-- TABLA DE CONFIGURACIÓN DEL SISTEMA
-- ============================================
CREATE TABLE IF NOT EXISTS system_config (
  key TEXT PRIMARY KEY,
  value TEXT,
  description TEXT,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Configuración inicial
INSERT INTO system_config (key, value, description) VALUES
  ('house_edge', '0.20', 'House edge percentage (20%)'),
  ('min_withdrawal', '10.00', 'Minimum withdrawal amount in USDT'),
  ('max_withdrawal', '10000.00', 'Maximum withdrawal amount in USDT'),
  ('withdrawal_fee', '1.00', 'Withdrawal fee in USDT'),
  ('game_difficulty', '1.0', 'Global game difficulty multiplier'),
  ('maintenance_mode', 'false', 'Enable maintenance mode'),
  ('new_user_bonus', '0.00', 'Bonus USDT for new users');

-- ============================================
-- TABLA DE LOGS DE JUEGO (ANTI-CHEAT)
-- ============================================
CREATE TABLE IF NOT EXISTS game_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES game_sessions(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  event_data JSONB,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_gamelogs_session ON game_logs(session_id);
CREATE INDEX idx_gamelogs_timestamp ON game_logs(timestamp DESC);

-- ============================================
-- FUNCIONES Y TRIGGERS
-- ============================================

-- Función para actualizar leaderboard automáticamente
CREATE OR REPLACE FUNCTION update_leaderboard()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO leaderboard (user_id, username, high_score, total_lines, games_played, max_level)
  VALUES (
    NEW.user_id,
    (SELECT username FROM users WHERE id = NEW.user_id),
    NEW.score,
    NEW.lines_cleared,
    1,
    NEW.level_reached
  )
  ON CONFLICT (user_id) DO UPDATE SET
    high_score = GREATEST(leaderboard.high_score, NEW.score),
    total_lines = leaderboard.total_lines + NEW.lines_cleared,
    max_level = GREATEST(leaderboard.max_level, NEW.level_reached),
    games_played = leaderboard.games_played + 1,
    updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para actualizar leaderboard después de cada sesión
DROP TRIGGER IF EXISTS trigger_update_leaderboard ON game_sessions;
CREATE TRIGGER trigger_update_leaderboard
AFTER INSERT ON game_sessions
FOR EACH ROW
EXECUTE FUNCTION update_leaderboard();

-- Función para calcular payout con house edge
CREATE OR REPLACE FUNCTION calculate_payout(p_score INTEGER, p_lines INTEGER, p_level INTEGER)
RETURNS DECIMAL(18,8) AS $$
DECLARE
  base_score DECIMAL := 0;
  level_bonus DECIMAL := 0;
  house_edge DECIMAL := 0.20;
  payout DECIMAL := 0;
BEGIN
  -- Base score calculation
  base_score := CASE 
    WHEN p_lines = 1 THEN 100
    WHEN p_lines = 2 THEN 300
    WHEN p_lines = 3 THEN 500
    WHEN p_lines = 4 THEN 800
    WHEN p_lines >= 5 THEN p_lines * 200
    ELSE 0
  END;
  
  -- Level multiplier
  level_bonus := 1 + (p_level - 1) * 0.1;
  
  -- Calculate total (score / 1000 = USDT, ejemplo)
  payout := (base_score * level_bonus) / 100.00;
  
  -- Apply house edge
  payout := payout * (1 - house_edge);
  
  RETURN payout;
END;
$$ LANGUAGE plpgsql;

-- Función para validar sesión de juego (ANTI-CHEAT)
CREATE OR REPLACE FUNCTION validate_game_session(
  p_session_id UUID,
  p_lines INTEGER,
  p_duration_seconds INTEGER,
  p_score INTEGER
)
RETURNS TABLE(is_valid BOOLEAN, notes TEXT) AS $$
DECLARE
  v_min_duration INTEGER;
  v_max_lines_per_second DECIMAL := 2.0;
  v_expected_min_lines INTEGER;
  v_is_valid BOOLEAN := TRUE;
  v_notes TEXT := '';
BEGIN
  -- Calculate minimum valid duration based on lines
  v_expected_min_lines := p_duration_seconds * v_max_lines_per_second;
  
  IF p_lines > v_expected_min_lines AND p_duration_seconds < 10 THEN
    v_is_valid := FALSE;
    v_notes := 'Suspicious: too many lines in short time';
  END IF;
  
  IF p_score > 100000 AND p_duration_seconds < 60 THEN
    v_is_valid := FALSE;
    v_notes := v_notes || ' | Suspicious: impossibly high score';
  END IF;
  
  IF p_lines > 1000 THEN
    v_is_valid := FALSE;
    v_notes := v_notes || ' | Invalid: line count exceeds maximum';
  END IF;
  
  RETURN QUERY SELECT v_is_valid, v_notes;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- POLÍTICAS DE SEGURIDAD (RLS)
-- ============================================

-- Habilitar RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE withdrawals ENABLE ROW LEVEL SECURITY;
ALTER TABLE leaderboard ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_logs ENABLE ROW LEVEL SECURITY;

-- Políticas para usuarios (lectura de propios datos)
CREATE POLICY "Users can read own profile" ON users 
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON users 
  FOR UPDATE USING (auth.uid() = id);

-- Políticas para sesiones de juego
CREATE POLICY "Users can create game sessions" ON game_sessions 
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can read own sessions" ON game_sessions 
  FOR SELECT USING (user_id = auth.uid());

-- Políticas para leaderboard (público)
CREATE POLICY "Anyone can read leaderboard" ON leaderboard 
  FOR SELECT USING (true);

-- Políticas para retiros
CREATE POLICY "Users can create withdrawals" ON withdrawals 
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can read own withdrawals" ON withdrawals 
  FOR SELECT USING (user_id = auth.uid());

-- Políticas para configuración del sistema (solo admin)
CREATE POLICY "Admin can manage config" ON system_config 
  FOR ALL USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND email LIKE '%admin%')
  );

-- ============================================
-- DATOS DE EJEMPLO (TEST)
-- ============================================

-- Insertar usuario de prueba
INSERT INTO users (email, username, usdt_balance, referral_code)
VALUES 
  ('test@stackusdt.game', 'TestPlayer', 100.00000000, 'TEST001'),
  ('demo@stackusdt.game', 'DemoPlayer', 50.00000000, 'DEMO001')
ON CONFLICT (email) DO NOTHING;

-- Insertar algunas sesiones de prueba
INSERT INTO game_sessions (user_id, score, lines_cleared, level_reached, payout_usdt, is_valid)
SELECT 
  u.id,
  (random() * 10000)::INTEGER,
  (random() * 50)::INTEGER,
  (random() * 10 + 1)::INTEGER,
  (random() * 10)::DECIMAL(18,8),
  TRUE
FROM users u
WHERE u.email = 'test@stackusdt.game';

-- ============================================
-- VERIFICACIÓN
-- ============================================

SELECT 'Database setup complete!' as status;

-- Verificar tablas
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;
