export interface GameResult {
  score: number;
  linesCleared: number;
  level: number;
  playTimeSeconds: number;
  userId: string;
}

export class AntiCheatValidator {
  validate(result: GameResult): { isValid: boolean; reason?: string; riskLevel: 'low' | 'medium' | 'high' } {
    const { score, linesCleared, level, playTimeSeconds } = result;

    // Check 1: Impossible score for play time
    const maxPossibleScore = playTimeSeconds * 200;
    if (score > maxPossibleScore) {
      return {
        isValid: false,
        reason: `Score ${score} exceeds maximum possible (${maxPossibleScore}) for ${playTimeSeconds}s`,
        riskLevel: 'high',
      };
    }

    // Check 2: Impossible lines for play time
    const maxPossibleLines = Math.floor(playTimeSeconds / 0.5);
    if (linesCleared > maxPossibleLines) {
      return {
        isValid: false,
        reason: `Lines ${linesCleared} exceeds maximum possible (${maxPossibleLines}) for ${playTimeSeconds}s`,
        riskLevel: 'high',
      };
    }

    // Check 3: Score to lines ratio sanity
    if (linesCleared > 0) {
      const scorePerLine = score / linesCleared;
      if (scorePerLine > 500) {
        return {
          isValid: false,
          reason: `Score per line (${scorePerLine.toFixed(1)}) is unrealistically high`,
          riskLevel: 'high',
        };
      }
    }

    // Check 4: Level consistency
    const expectedLevel = Math.floor(linesCleared / 10) + 1;
    if (level > expectedLevel + 2) {
      return {
        isValid: false,
        reason: `Level ${level} is inconsistent with ${linesCleared} lines (expected ~${expectedLevel})`,
        riskLevel: 'medium',
      };
    }

    // Check 5: Minimum play time for score
    if (score > 10000 && playTimeSeconds < 10) {
      return {
        isValid: false,
        reason: `Score ${score} in only ${playTimeSeconds}s is suspicious`,
        riskLevel: 'high',
      };
    }

    // Check 6: Zero score with high play time (possible bot or AFK)
    if (score === 0 && playTimeSeconds > 120) {
      return {
        isValid: true,
        reason: 'AFK detected - no score earned',
        riskLevel: 'low',
      };
    }

    // Check 7: Unrealistic lines per second
    if (playTimeSeconds > 0) {
      const linesPerSecond = linesCleared / playTimeSeconds;
      if (linesPerSecond > 3) {
        return {
          isValid: false,
          reason: `Lines per second (${linesPerSecond.toFixed(1)}) is superhuman`,
          riskLevel: 'high',
        };
      }
    }

    return { isValid: true, riskLevel: 'low' };
  }

  compareResults(player1: GameResult, player2: GameResult): {
    winner: string;
    margin: string;
    suspicious: boolean;
  } {
    const p1Valid = this.validate(player1);
    const p2Valid = this.validate(player2);

    if (!p1Valid.isValid && !p2Valid.isValid) {
      return { winner: 'none', margin: 'both_invalid', suspicious: true };
    }

    if (!p1Valid.isValid) {
      return { winner: player2.userId, margin: 'p1_invalid', suspicious: true };
    }

    if (!p2Valid.isValid) {
      return { winner: player1.userId, margin: 'p2_invalid', suspicious: true };
    }

    const winner = player1.score >= player2.score ? player1.userId : player2.userId;
    const margin = Math.abs(player1.score - player2.score);
    const marginPercent = margin / Math.max(player1.score, player2.score, 1) * 100;

    // Check for suspiciously close scores (possible collusion)
    const suspicious = marginPercent < 1 && player1.playTimeSeconds > 60;

    return {
      winner,
      margin: marginPercent.toFixed(1) + '%',
      suspicious,
    };
  }
}

export const antiCheat = new AntiCheatValidator();
