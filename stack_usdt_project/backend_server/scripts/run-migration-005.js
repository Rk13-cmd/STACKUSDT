const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: require('path').resolve(__dirname, '..', '.env') });

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('ERROR: Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in .env');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkTable(tableName) {
  const { error } = await supabase.from(tableName).select('id').limit(1);
  return !error;
}

async function migrate() {
  console.log('=== STACK USDT Migration 005 ===');
  console.log('Checking existing tables...\n');

  const tables = ['bonuses', 'user_bonuses', 'referral_earnings', 'missions', 'user_mission_progress', 'user_staking', 'staking_rewards_log'];
  const existing = [];
  const missing = [];

  for (const t of tables) {
    const exists = await checkTable(t);
    if (exists) {
      existing.push(t);
      console.log(`[EXISTS] ${t}`);
    } else {
      missing.push(t);
      console.log(`[MISSING] ${t}`);
    }
  }

  console.log(`\nExisting: ${existing.length} | Missing: ${missing.length}`);

  if (missing.length > 0) {
    console.log('\nYou need to create these tables in Supabase SQL Editor:');
    console.log('Go to: https://app.supabase.com/project/hpfuoqejinckybhsqkub/sql\n');
    console.log('Copy and paste these blocks one at a time:\n');
    console.log('--- BLOCK 1: bonuses ---');
    console.log(`CREATE TABLE IF NOT EXISTS bonuses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  amount_usdt DECIMAL(18,8) NOT NULL DEFAULT 0,
  amount_percent DECIMAL(5,2),
  description TEXT,
  min_deposit DECIMAL(18,8) DEFAULT 0,
  max_uses INT DEFAULT NULL,
  current_uses INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  starts_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);`);

    console.log('\n--- BLOCK 2: user_bonuses ---');
    console.log(`CREATE TABLE IF NOT EXISTS user_bonuses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  bonus_id UUID REFERENCES bonuses(id) ON DELETE CASCADE,
  amount_usdt DECIMAL(18,8) NOT NULL,
  status TEXT DEFAULT 'pending',
  claimed_at TIMESTAMP WITH TIME ZONE,
  expires_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);`);

    console.log('\n--- BLOCK 3: referral_earnings ---');
    console.log(`CREATE TABLE IF NOT EXISTS referral_earnings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id UUID REFERENCES users(id) ON DELETE CASCADE,
  referred_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  level INT DEFAULT 1,
  amount_usdt DECIMAL(18,8) NOT NULL,
  source_deposit_id UUID,
  status TEXT DEFAULT 'pending',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);`);

    console.log('\n--- BLOCK 4: missions ---');
    console.log(`CREATE TABLE IF NOT EXISTS missions (
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
);`);

    console.log('\n--- BLOCK 5: user_mission_progress ---');
    console.log(`CREATE TABLE IF NOT EXISTS user_mission_progress (
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
);`);

    console.log('\n--- BLOCK 6: user_staking ---');
    console.log(`CREATE TABLE IF NOT EXISTS user_staking (
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
);`);

    console.log('\n--- BLOCK 7: staking_rewards_log ---');
    console.log(`CREATE TABLE IF NOT EXISTS staking_rewards_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staking_id UUID REFERENCES user_staking(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  amount_usdt DECIMAL(18,8) NOT NULL,
  reward_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);`);
  }

  // Seed data - only if tables exist
  if (existing.includes('bonuses')) {
    console.log('\n--- SEEDING DATA ---');

    const { count: bonusCount } = await supabase.from('bonuses').select('*', { count: 'exact', head: true });
    if (!bonusCount || bonusCount === 0) {
      console.log('Seeding bonuses...');
      await supabase.from('bonuses').insert([
        { name: 'Welcome Bonus', type: 'first_deposit', amount_usdt: 0, amount_percent: 10.00, description: '10% extra on your first deposit', min_deposit: 10, expires_at: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString() },
        { name: 'Reload Bonus', type: 'reload', amount_usdt: 0, amount_percent: 5.00, description: '5% extra on deposits over $50', min_deposit: 50, expires_at: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString() },
        { name: 'VIP Welcome', type: 'vip_bonus', amount_usdt: 25.00, amount_percent: 0, description: '$25 bonus for VIP Diamond members', min_deposit: 0, expires_at: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString() },
      ]);
      console.log('[OK] 3 bonuses seeded');
    } else {
      console.log(`[SKIP] ${bonusCount} bonuses already exist`);
    }

    const { count: missionCount } = await supabase.from('missions').select('*', { count: 'exact', head: true });
    if (!missionCount || missionCount === 0) {
      console.log('Seeding missions...');
      await supabase.from('missions').insert([
        { name: 'Play 5 Games', type: 'games_played', description: 'Complete 5 games in a day', requirement_value: 5, reward_usdt: 0.50, reward_xp: 50, period: 'daily' },
        { name: 'Play 20 Games', type: 'games_played', description: 'Complete 20 games in a day', requirement_value: 20, reward_usdt: 2.00, reward_xp: 200, period: 'daily' },
        { name: 'Clear 50 Lines', type: 'lines_cleared', description: 'Clear 50 lines in a day', requirement_value: 50, reward_usdt: 1.00, reward_xp: 100, period: 'daily' },
        { name: 'Clear 200 Lines', type: 'lines_cleared', description: 'Clear 200 lines in a day', requirement_value: 200, reward_usdt: 5.00, reward_xp: 500, period: 'daily' },
        { name: 'Score 1000+', type: 'high_score', description: 'Achieve a score over 1000', requirement_value: 1000, reward_usdt: 1.00, reward_xp: 100, period: 'daily' },
        { name: 'Score 5000+', type: 'high_score', description: 'Achieve a score over 5000', requirement_value: 5000, reward_usdt: 5.00, reward_xp: 500, period: 'daily' },
        { name: 'Join 3 Tournaments', type: 'tournaments_joined', description: 'Join 3 tournaments in a week', requirement_value: 3, reward_usdt: 2.00, reward_xp: 0, period: 'weekly' },
        { name: 'Win a Tournament', type: 'tournament_win', description: 'Win 1st place in any tournament', requirement_value: 1, reward_usdt: 10.00, reward_xp: 1000, period: 'weekly' },
        { name: 'Deposit $50+', type: 'deposit', description: 'Deposit $50 or more in a week', requirement_value: 50, reward_usdt: 3.00, reward_xp: 0, period: 'weekly' },
        { name: 'Play 100 Games', type: 'games_played', description: 'Complete 100 games in a month', requirement_value: 100, reward_usdt: 15.00, reward_xp: 1500, period: 'monthly' },
      ]);
      console.log('[OK] 10 missions seeded');
    } else {
      console.log(`[SKIP] ${missionCount} missions already exist`);
    }
  }

  console.log('\n=== Done ===');
  if (missing.length > 0) {
    console.log(`\nACTION REQUIRED: Create ${missing.length} missing table(s) in Supabase SQL Editor`);
    console.log('URL: https://app.supabase.com/project/hpfuoqejinckybhsqkub/sql');
    console.log('Then run this script again to seed data.');
  }
}

migrate().catch(console.error);
