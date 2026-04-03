import { Router } from 'express';
import { db } from '../services/supabase';

const router = Router();

// GET /api/economy/config - Get all economy config
router.get('/config', async (req, res) => {
  try {
    const config = await db.getAllEconomyConfig();
    res.json({ success: true, config });
  } catch (error: any) {
    console.error('Error fetching economy config:', error);
    res.status(500).json({ error: 'Failed to fetch config' });
  }
});

// PUT /api/economy/config - Update economy config
router.put('/config', async (req, res) => {
  try {
    const { key, value } = req.body;
    if (!key || value === undefined) {
      return res.status(400).json({ error: 'key and value are required' });
    }
    await db.updateEconomyConfig(key, value);
    res.json({ success: true, message: 'Config updated' });
  } catch (error: any) {
    console.error('Error updating economy config:', error);
    res.status(500).json({ error: 'Failed to update config' });
  }
});

// GET /api/economy/stats - Financial stats
router.get('/stats', async (req, res) => {
  try {
    const stats = await db.getFinancialStats();
    res.json({ success: true, stats });
  } catch (error: any) {
    console.error('Error fetching economy stats:', error);
    res.status(500).json({ error: 'Failed to fetch stats' });
  }
});

// GET /api/economy/bots - Get all bots
router.get('/bots', async (req, res) => {
  try {
    const bots = await db.getAllBots();
    res.json({ success: true, bots });
  } catch (error: any) {
    console.error('Error fetching bots:', error);
    res.status(500).json({ error: 'Failed to fetch bots' });
  }
});

// PUT /api/economy/bot/:id - Update bot config
router.put('/bot/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { is_active, win_rate, mmr, balance } = req.body;
    const updates: any = {};
    if (is_active !== undefined) updates.is_active = is_active;
    if (win_rate !== undefined) updates.win_rate = win_rate;
    if (mmr !== undefined) updates.mmr = mmr;
    if (balance !== undefined) updates.balance = balance;

    await db.updateBot(id, updates);
    res.json({ success: true, message: 'Bot updated' });
  } catch (error: any) {
    console.error('Error updating bot:', error);
    res.status(500).json({ error: 'Failed to update bot' });
  }
});

export default router;
