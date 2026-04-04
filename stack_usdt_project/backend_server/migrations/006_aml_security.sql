-- ============================================
-- MIGRATION 006: AML Alerts + Security Enhancements
-- ============================================

CREATE TABLE IF NOT EXISTS aml_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  alert_type TEXT NOT NULL,
  reason TEXT NOT NULL,
  severity TEXT DEFAULT 'medium',
  status TEXT DEFAULT 'pending',
  reviewed_by UUID REFERENCES users(id),
  reviewed_at TIMESTAMP WITH TIME ZONE,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_aml_alerts_user ON aml_alerts(user_id, status);
CREATE INDEX IF NOT EXISTS idx_aml_alerts_severity ON aml_alerts(severity, status);
CREATE INDEX IF NOT EXISTS idx_aml_alerts_date ON aml_alerts(created_at DESC);

ALTER TABLE aml_alerts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view AML alerts" ON aml_alerts
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.is_admin = true)
  );

CREATE POLICY "System can insert AML alerts" ON aml_alerts
  FOR INSERT WITH CHECK (true);
