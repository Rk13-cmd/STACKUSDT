import { Router } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { db } from '../services/supabase';
import { gameLogic } from '../services/gameLogic';
import { missionService } from '../services/missionService';

const router = Router();

// POST /api/start-game - Iniciar nueva sesión de juego
router.post('/start-game', async (req, res) => {
  try {
    const { user_id, device_fingerprint } = req.body;

    if (!user_id) {
      return res.status(400).json({ error: 'user_id is required' });
    }

    // Verificar que el usuario existe y no está banned
    const user = await db.getUserById(user_id);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    if (user.is_banned) {
      return res.status(403).json({ error: 'User is banned' });
    }

    // Verificar que no hay otra sesión activa
    // (En una implementación real, verificarías sesiones activas)

    // Crear nueva sesión
    const session = await db.createGameSession(user_id, device_fingerprint);

    res.json({
      success: true,
      session_id: session.id,
      user_id: user_id,
      usdt_balance: user.usdt_balance,
      started_at: session.started_at
    });
  } catch (error) {
    console.error('Error starting game:', error);
    res.status(500).json({ error: 'Failed to start game session' });
  }
});

// POST /api/end-game - Finalizar sesión de juego
router.post('/end-game', async (req, res) => {
  try {
    const { session_id, lines_cleared, play_time_seconds, score } = req.body;

    if (!session_id || lines_cleared === undefined || !play_time_seconds) {
      return res.status(400).json({ 
        error: 'session_id, lines_cleared, and play_time_seconds are required' 
      });
    }

    // Procesar fin del juego
    const result = await gameLogic.processGameEnd(
      session_id,
      lines_cleared,
      play_time_seconds,
      score || 0
    );

    // Obtener el usuario para devolver el balance actualizado
    const session = await db.getGameSession(session_id);
    let usdtBalance = 0;
    let userId = '';
    
    if (session) {
      userId = session.user_id;
      const user = await db.getUserById(session.user_id);
      usdtBalance = user?.usdt_balance || 0;

      await missionService.updateMissionProgress(userId, 'games_played', 1);
      await missionService.updateMissionProgress(userId, 'lines_cleared', lines_cleared);
      if (score > 0) {
        await missionService.updateMissionProgress(userId, 'high_score', score);
      }
    }

    res.json({
      success: result.success,
      session_id,
      usdt_balance: usdtBalance,
      lines_cleared: lines_cleared,
      score: score || 0,
      payout: result.payout,
      is_valid: result.isValid,
      validation_message: result.validationMessage,
      xp_gained: result.xpGained,
      mining_xp: result.miningXP,
      mining_level: result.miningLevel,
    });
  } catch (error) {
    console.error('Error ending game:', error);
    res.status(500).json({ error: 'Failed to end game session' });
  }
});

// GET /api/leaderboard - Obtener leaderboard
router.get('/leaderboard', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit as string) || 100;
    const leaderboard = await db.getLeaderboard(limit);

    res.json({
      success: true,
      leaderboard
    });
  } catch (error) {
    console.error('Error fetching leaderboard:', error);
    res.status(500).json({ error: 'Failed to fetch leaderboard' });
  }
});

// POST /api/validate-session - Validar sesión (anti-cheat)
router.post('/validate-session', async (req, res) => {
  try {
    const { session_id, lines_cleared, play_time_seconds, score } = req.body;

    if (!session_id) {
      return res.status(400).json({ error: 'session_id is required' });
    }

    const validation = await gameLogic.validateGameResult(
      session_id,
      lines_cleared || 0,
      play_time_seconds || 0,
      score || 0
    );

    res.json({
      is_valid: validation.isValid,
      message: validation.message,
      risk_level: validation.riskLevel
    });
  } catch (error) {
    console.error('Error validating session:', error);
    res.status(500).json({ error: 'Failed to validate session' });
  }
});

export default router;
