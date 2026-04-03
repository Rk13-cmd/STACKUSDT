import { db } from './supabase';

export interface ValidationResult {
  isValid: boolean;
  message: string;
  riskLevel: 'low' | 'medium' | 'high';
}

export interface PayoutResult {
  payout: number;
  houseEdge: number;
  bonus: number;
}

export class GameLogicService {
  private readonly HOUSE_EDGE = 0.20;
  private readonly BASE_PAYOUT_RATE = 0.001; // 1 punto = 0.001 USDT
  private readonly MAX_LINES_PER_SECOND = 2.0;
  private readonly MAX_SCORE_PER_MINUTE = 10000;

  async validateGameResult(
    sessionId: string,
    linesCleared: number,
    playTimeSeconds: number,
    score: number
  ): Promise<ValidationResult> {
    const session = await db.getGameSession(sessionId);
    
    if (!session) {
      return {
        isValid: false,
        message: 'Session not found',
        riskLevel: 'high'
      };
    }

    // Calculate expected duration
    const durationSeconds = playTimeSeconds;
    const expectedMinDuration = linesCleared / this.MAX_LINES_PER_SECOND;
    
    // Check 1: Too many lines in too short time
    if (linesCleared > 0 && durationSeconds < expectedMinDuration * 0.5) {
      return {
        isValid: false,
        message: `Suspicious: ${linesCleared} lines cleared in only ${durationSeconds}s`,
        riskLevel: 'high'
      };
    }

    // Check 2: Impossibly high score
    const maxExpectedScore = (durationSeconds / 60) * this.MAX_SCORE_PER_MINUTE;
    if (score > maxExpectedScore * 1.5) {
      return {
        isValid: false,
        message: `Suspicious: Score ${score} too high for ${durationSeconds}s playtime`,
        riskLevel: 'high'
      };
    }

    // Check 3: Zero lines with high score
    if (linesCleared === 0 && score > 1000) {
      return {
        isValid: false,
        message: 'Suspicious: High score with zero lines cleared',
        riskLevel: 'medium'
      };
    }

    // Check 4: Very short game with high score
    if (durationSeconds < 5 && score > 5000) {
      return {
        isValid: false,
        message: 'Suspicious: Game too short for this score',
        riskLevel: 'medium'
      };
    }

    // Check 5: Lines without time (impossible)
    if (linesCleared > 0 && durationSeconds === 0) {
      return {
        isValid: false,
        message: 'Invalid: Lines cleared with zero time',
        riskLevel: 'high'
      };
    }

    // All checks passed
    return {
      isValid: true,
      message: 'Game validated successfully',
      riskLevel: 'low'
    };
  }

  calculatePayout(linesCleared: number, score: number, level: number): PayoutResult {
    // Base score calculation
    const lineScores = [0, 100, 300, 500, 800, 1200, 1800, 2500];
    const baseScore = linesCleared <= 7 
      ? lineScores[linesCleared] 
      : linesCleared * 400;
    
    // Level multiplier
    const levelMultiplier = 1 + (level - 1) * 0.1;
    
    // Calculate base payout
    let payout = (baseScore * levelMultiplier * this.BASE_PAYOUT_RATE);
    
    // Apply house edge
    const houseEdgeAmount = payout * this.HOUSE_EDGE;
    payout = payout - houseEdgeAmount;
    
    // Bonus for perfect games
    let bonus = 0;
    if (linesCleared >= 10) {
      bonus = linesCleared * 0.1;
    }
    
    return {
      payout: Math.max(0, payout + bonus),
      houseEdge: houseEdgeAmount,
      bonus
    };
  }

  async processGameEnd(
    sessionId: string,
    linesCleared: number,
    playTimeSeconds: number,
    score: number
  ): Promise<{ 
    success: boolean; 
    payout: number; 
    isValid: boolean; 
    validationMessage: string;
    xpGained: number;
    miningXP: number;
    miningLevel: number;
  }> {
    const validation = await this.validateGameResult(
      sessionId,
      linesCleared,
      playTimeSeconds,
      score
    );

    const level = Math.floor(linesCleared / 10) + 1;
    
    let payout = 0;
    if (validation.isValid) {
      const payoutResult = this.calculatePayout(linesCleared, score, level);
      payout = payoutResult.payout;
    }

    await db.endGameSession(sessionId, {
      duration_seconds: playTimeSeconds,
      score,
      lines_cleared: linesCleared,
      level_reached: level,
      payout_usdt: payout,
      is_valid: validation.isValid,
      validation_notes: validation.message
    });

    let xpGained = 0;
    let miningXP = 0;
    let miningLevel = 1;

    if (validation.isValid) {
      xpGained = linesCleared * 10 + Math.floor(score / 100);
      const session = await db.getGameSession(sessionId);
      if (session && xpGained > 0) {
        try {
          await db.updateUserBalance(session.user_id, payout, 'add');
          const xpResult = await db.updateMiningXP(session.user_id, xpGained);
          miningXP = xpResult.mining_xp;
          miningLevel = xpResult.mining_level;
        } catch (error) {
          console.error('Failed to update balance or XP:', error);
        }
      }
    }

    return {
      success: true,
      payout,
      isValid: validation.isValid,
      validationMessage: validation.message,
      xpGained,
      miningXP,
      miningLevel,
    };
  }
}

export const gameLogic = new GameLogicService();
