import { Router } from 'express';
import { db } from '../services/supabase';
import { tournamentEngine } from '../services/tournamentEngine';

const router = Router();

// GET /api/tournament/list - Get active tournaments
router.get('/list', async (req, res) => {
  try {
    const tournaments = await db.getActiveTournaments();
    res.json({ success: true, tournaments });
  } catch (error: any) {
    console.error('Error fetching tournaments:', error);
    res.status(500).json({ error: 'Failed to fetch tournaments' });
  }
});

// GET /api/tournament/:id - Get tournament details
router.get('/:id', async (req, res) => {
  try {
    const tournament = await db.getTournament(req.params.id);
    if (!tournament) {
      return res.status(404).json({ error: 'Tournament not found' });
    }
    const participants = await db.getTournamentParticipants(req.params.id);
    res.json({ success: true, tournament, participants });
  } catch (error: any) {
    console.error('Error fetching tournament:', error);
    res.status(500).json({ error: 'Failed to fetch tournament' });
  }
});

// POST /api/tournament/join - Join a tournament
router.post('/join', async (req, res) => {
  try {
    const { user_id, tournament_id } = req.body;
    if (!user_id || !tournament_id) {
      return res.status(400).json({ error: 'user_id and tournament_id are required' });
    }

    const user = await db.getUserById(user_id);
    if (!user) return res.status(404).json({ error: 'User not found' });
    if (user.is_banned) return res.status(403).json({ error: 'User is banned' });

    const tournament = await db.getTournament(tournament_id);
    if (!tournament) return res.status(404).json({ error: 'Tournament not found' });
    if (tournament.status !== 'waiting') return res.status(400).json({ error: 'Tournament is not open' });

    if (tournament.entry_fee > 0 && user.usdt_balance < tournament.entry_fee) {
      return res.status(400).json({
        error: 'Insufficient balance',
        available: user.usdt_balance,
        required: tournament.entry_fee,
      });
    }

    if (tournament.entry_fee > 0) {
      await db.updateUserBalance(user_id, tournament.entry_fee, 'subtract');
    }

    await db.addParticipant(tournament_id, user_id, null, 0, 0);

    res.json({
      success: true,
      message: 'Joined tournament successfully',
      tournament,
    });
  } catch (error: any) {
    console.error('Error joining tournament:', error);
    res.status(500).json({ error: 'Failed to join tournament' });
  }
});

// GET /api/tournament/history/:userId
router.get('/history/:userId', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit as string) || 20;
    const history = await db.getUserTournamentHistory(req.params.userId, limit);
    res.json({ success: true, history });
  } catch (error: any) {
    console.error('Error fetching tournament history:', error);
    res.status(500).json({ error: 'Failed to fetch history' });
  }
});

// GET /api/tournament/leaderboard
router.get('/leaderboard', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit as string) || 50;
    const leaderboard = await db.getLeaderboard(limit);
    res.json({ success: true, leaderboard });
  } catch (error: any) {
    console.error('Error fetching leaderboard:', error);
    res.status(500).json({ error: 'Failed to fetch leaderboard' });
  }
});

// POST /api/tournament/create (admin)
router.post('/create', async (req, res) => {
  try {
    const { type } = req.body;
    if (!type) return res.status(400).json({ error: 'type is required' });

    const tournament = await tournamentEngine.createTournament(type);
    res.json({ success: true, tournament });
  } catch (error: any) {
    console.error('Error creating tournament:', error);
    res.status(500).json({ error: 'Failed to create tournament' });
  }
});

export default router;
