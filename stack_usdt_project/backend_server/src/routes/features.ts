import { Router } from 'express';
import { db } from '../services/supabase';
import { requireAdmin, optionalAuth } from '../middleware/auth';
import { bonusService } from '../services/bonusService';
import { referralService } from '../services/referralService';
import { missionService } from '../services/missionService';
import { stakingService } from '../services/stakingService';

const router = Router();

// ==================== BONUSES ====================

// GET /api/features/bonuses/active - Get active bonuses for user
router.get('/bonuses/active', optionalAuth, async (req, res) => {
  try {
    const bonuses = await bonusService.getActiveBonuses();
    res.json({ success: true, bonuses });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to fetch bonuses' });
  }
});

// GET /api/features/bonuses/my - Get user's bonuses
router.get('/bonuses/my', async (req, res) => {
  try {
    const userId = (req as any).userId || req.query.user_id;
    if (!userId) return res.status(401).json({ error: 'Authentication required' });

    const bonuses = await bonusService.getUserBonuses(userId);
    const pendingValue = await bonusService.getUserPendingBonusValue(userId);
    res.json({ success: true, bonuses, pending_value: pendingValue });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to fetch bonuses' });
  }
});

// POST /api/features/bonuses/:id/claim - Claim a bonus
router.post('/bonuses/:id/claim', async (req, res) => {
  try {
    const userId = (req as any).userId || req.body.user_id;
    if (!userId) return res.status(401).json({ error: 'Authentication required' });

    const result = await bonusService.claimBonus(req.params.id, userId);
    res.json({ success: true, bonus: result });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

// ADMIN: POST /api/features/bonuses/create
router.post('/bonuses/create', requireAdmin, async (req, res) => {
  try {
    const bonus = await bonusService.createBonus(req.body);
    res.json({ success: true, bonus });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// ADMIN: PUT /api/features/bonuses/:id/toggle
router.put('/bonuses/:id/toggle', requireAdmin, async (req, res) => {
  try {
    await bonusService.toggleBonus(req.params.id, req.body.is_active);
    res.json({ success: true });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// ADMIN: GET /api/features/bonuses/all
router.get('/bonuses/all', requireAdmin, async (req, res) => {
  try {
    const bonuses = await bonusService.getAllBonuses();
    res.json({ success: true, bonuses });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to fetch bonuses' });
  }
});

// ==================== REFERRALS ====================

// GET /api/features/referrals/info
router.get('/referrals/info', async (req, res) => {
  try {
    const userId = (req as any).userId || req.query.user_id;
    if (!userId) return res.status(401).json({ error: 'Authentication required' });

    const info = await referralService.getReferralInfo(userId);
    res.json({ success: true, info });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/features/referrals/apply
router.post('/referrals/apply', async (req, res) => {
  try {
    const { user_id, code } = req.body;
    if (!user_id || !code) return res.status(400).json({ error: 'user_id and code required' });

    const applied = await referralService.applyReferralCode(user_id, code);
    res.json({ success: true, applied });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/features/referrals/leaderboard
router.get('/referrals/leaderboard', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit as string) || 20;
    const board = await referralService.getReferralLeaderboard(limit);
    res.json({ success: true, leaderboard: board });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to fetch leaderboard' });
  }
});

// ==================== MISSIONS ====================

// GET /api/features/missions - Get all active missions
router.get('/missions', async (req, res) => {
  try {
    const period = req.query.period as string;
    const missions = await missionService.getAllMissions(period);
    res.json({ success: true, missions });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to fetch missions' });
  }
});

// GET /api/features/missions/my - Get user's mission progress
router.get('/missions/my', async (req, res) => {
  try {
    const userId = (req as any).userId || req.query.user_id;
    if (!userId) return res.status(401).json({ error: 'Authentication required' });

    const period = (req.query.period as string) || 'daily';
    const progress = await missionService.getUserMissionProgress(userId, period);
    res.json({ success: true, progress });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/features/missions/:id/claim - Claim mission reward
router.post('/missions/:id/claim', async (req, res) => {
  try {
    const userId = (req as any).userId || req.body.user_id;
    if (!userId) return res.status(401).json({ error: 'Authentication required' });

    const result = await missionService.claimMissionReward(userId, req.params.id);
    res.json({ success: true, reward: result });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

// ADMIN: POST /api/features/missions/create
router.post('/missions/create', requireAdmin, async (req, res) => {
  try {
    const mission = await missionService.createMission(req.body);
    res.json({ success: true, mission });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// ADMIN: PUT /api/features/missions/:id/toggle
router.put('/missions/:id/toggle', requireAdmin, async (req, res) => {
  try {
    await missionService.toggleMission(req.params.id, req.body.is_active);
    res.json({ success: true });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// ADMIN: GET /api/features/missions/stats
router.get('/missions/stats', requireAdmin, async (req, res) => {
  try {
    const stats = await missionService.getMissionStats();
    res.json({ success: true, stats });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to fetch stats' });
  }
});

// ==================== STAKING ====================

// GET /api/features/staking/info
router.get('/staking/info', async (req, res) => {
  try {
    const userId = (req as any).userId || req.query.user_id;
    if (!userId) return res.status(401).json({ error: 'Authentication required' });

    const info = await stakingService.getUserStakingInfo(userId);
    res.json({ success: true, info });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/features/staking/stake
router.post('/staking/stake', async (req, res) => {
  try {
    const userId = (req as any).userId || req.body.user_id;
    if (!userId) return res.status(401).json({ error: 'Authentication required' });

    const { amount } = req.body;
    if (!amount || amount < 10) return res.status(400).json({ error: 'Minimum stake is $10 USDT' });

    const result = await stakingService.stake(userId, parseFloat(amount));
    res.json({ success: true, ...result });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

// POST /api/features/staking/unstake
router.post('/staking/unstake', async (req, res) => {
  try {
    const userId = (req as any).userId || req.body.user_id;
    if (!userId) return res.status(401).json({ error: 'Authentication required' });

    const result = await stakingService.unstake(userId);
    res.json({ success: true, ...result });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

// GET /api/features/staking/global-stats
router.get('/staking/global-stats', async (req, res) => {
  try {
    const stats = await stakingService.getGlobalStakingStats();
    res.json({ success: true, stats });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to fetch staking stats' });
  }
});

export default router;
