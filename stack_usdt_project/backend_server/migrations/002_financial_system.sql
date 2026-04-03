-- ============================================================
-- STACK USDT: Sistema Financiero Profesional
-- Depósitos, Retiros, Notificaciones, Gestión de Usuarios
-- ============================================================

-- 1. Tabla de depósitos
CREATE TABLE IF NOT EXISTS deposits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  amount_usdt NUMERIC(10, 4) NOT NULL,
  amount_received NUMERIC(10, 4),
  currency_from TEXT NOT NULL DEFAULT 'USDTTRC20',
  nowpayments_payment_id TEXT,
  nowpayments_order_id TEXT,
  payment_address TEXT,
  payment_status TEXT NOT NULL DEFAULT 'waiting',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  confirmed_at TIMESTAMPTZ
);

-- 2. Tabla de notificaciones push
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Tabla de auditoría financiera
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  target_type TEXT,
  target_id TEXT,
  details JSONB,
  ip_address TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Actualizar tabla users
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS total_deposited NUMERIC(10, 4) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false;

-- 5. Actualizar tabla withdrawals con campos de admin
ALTER TABLE withdrawals
  ADD COLUMN IF NOT EXISTS admin_notes TEXT,
  ADD COLUMN IF NOT EXISTS admin_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS processed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS tx_hash TEXT;

-- 6. Índices
CREATE INDEX IF NOT EXISTS idx_deposits_user ON deposits(user_id);
CREATE INDEX IF NOT EXISTS idx_deposits_status ON deposits(payment_status);
CREATE INDEX IF NOT EXISTS idx_deposits_nowpayments ON deposits(nowpayments_payment_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_withdrawals_status ON withdrawals(status);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at);

-- 7. RLS Policies
ALTER TABLE deposits ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own deposits" ON deposits
  FOR SELECT USING (auth.uid() = user_id);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own notifications" ON notifications
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users update own notifications" ON notifications
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Server can insert notifications" ON notifications
  FOR INSERT WITH CHECK (true);

ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins view audit logs" ON audit_logs
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND is_admin = true)
  );
