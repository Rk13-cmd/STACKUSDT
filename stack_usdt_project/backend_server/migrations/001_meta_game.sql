-- ============================================================
-- STACK USDT: Meta-Juego (XP, Niveles, Tienda de Skins)
-- Ejecutar en Supabase SQL Editor
-- ============================================================

-- 1. Crear tabla de skins PRIMERO (necesaria para la FK)
CREATE TABLE IF NOT EXISTS skins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  block_color_hex TEXT NOT NULL,
  glow_color_hex TEXT NOT NULL DEFAULT '#40FFFFFF',
  price_usdt NUMERIC(10, 4) NOT NULL DEFAULT 0,
  is_premium BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Crear tabla de inventario de usuario
CREATE TABLE IF NOT EXISTS user_inventory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  skin_id UUID REFERENCES skins(id) ON DELETE CASCADE NOT NULL,
  acquired_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, skin_id)
);

-- 3. Actualizar tabla users con campos de XP y skin
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS mining_xp INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS mining_level INT DEFAULT 1,
  ADD COLUMN IF NOT EXISTS active_skin_id UUID REFERENCES skins(id) ON DELETE SET NULL;

-- 4. Insertar skins iniciales del catálogo
INSERT INTO skins (name, block_color_hex, glow_color_hex, price_usdt, is_premium) VALUES
  ('NEON CLASSIC',  '#00E5FF', '#4000E5FF', 0, false),
  ('CYBER GOLD',    '#FFD700', '#40FFD700', 5.00, false),
  ('PHANTOM WHITE', '#E0E0E0', '#40E0E0E0', 3.00, false),
  ('MATRIX GREEN',  '#39FF14', '#4039FF14', 4.00, false),
  ('CRIMSON FURY',  '#FF073A', '#40FF073A', 6.00, false),
  ('VOID PURPLE',   '#AA00FF', '#40AA00FF', 8.00, true),
  ('DIAMOND DUST',  '#B9F2FF', '#40B9F2FF', 15.00, true),
  ('SOLAR FLARE',   '#FF6D00', '#40FF6D00', 10.00, true),
  ('OBSIDIAN',      '#2C2C2C', '#40444444', 20.00, true),
  ('RAINBOW PRISM', '#FF1493', '#40FF1493', 50.00, true)
ON CONFLICT DO NOTHING;

-- 5. Dar skin clásica gratis a todos los usuarios existentes
INSERT INTO user_inventory (user_id, skin_id)
SELECT u.id, s.id
FROM users u
CROSS JOIN skins s
WHERE s.name = 'NEON CLASSIC'
  AND NOT EXISTS (
    SELECT 1 FROM user_inventory ui WHERE ui.user_id = u.id AND ui.skin_id = s.id
  )
ON CONFLICT DO NOTHING;

-- 6. Política RLS para skins (lectura pública)
ALTER TABLE skins ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Skins are publicly viewable" ON skins
  FOR SELECT USING (true);

-- 7. Política RLS para user_inventory
ALTER TABLE user_inventory ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own inventory" ON user_inventory
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Server can insert inventory" ON user_inventory
  FOR INSERT WITH CHECK (true);

-- 8. Índice para rendimiento
CREATE INDEX IF NOT EXISTS idx_user_inventory_user ON user_inventory(user_id);
CREATE INDEX IF NOT EXISTS idx_user_inventory_skin ON user_inventory(skin_id);
