import { db } from './supabase';

export interface BotResult {
  botId: string;
  score: number;
  linesCleared: number;
  won: boolean;
  mmrChange: number;
}

export class BotEngine {
  private running = false;
  private interval: any = null;

  start() {
    if (this.running) return;
    this.running = true;
    this.interval = setInterval(() => this.tick(), 30000);
    console.log('🤖 Bot Engine started (30s interval)');
  }

  stop() {
    this.running = false;
    if (this.interval) {
      clearInterval(this.interval);
      this.interval = null;
    }
    console.log('🤖 Bot Engine stopped');
  }

  private async tick() {
    try {
      const bots = await db.getActiveBots();
      if (bots.length === 0) return;

      const botConfig = await db.getEconomyConfig('bot_config');
      const globalWinRate = botConfig?.global_win_rate ?? 55;

      for (const bot of bots) {
        try {
          const shouldWin = Math.random() * 100 < (bot.win_rate || globalWinRate);
          const score = this.generateScore(bot, shouldWin);
          const lines = Math.floor(score / 150) + Math.floor(Math.random() * 5);

          const oldMmr = bot.mmr || 1000;
          const targetMmr = this.getTargetMmr(bot.tier);
          const mmrChange = Math.round((targetMmr - oldMmr) * 0.02 * (shouldWin ? 1 : -1));
          const newMmr = Math.max(0, Math.min(3000, oldMmr + mmrChange));

          const prizeAmount = shouldWin ? this.generatePrize(bot) : 0;
          const entryCost = this.getEntryCost(bot.tier);

          await db.updateBot(bot.id, {
            mmr: newMmr,
            balance: Math.max(0, (bot.balance || 0) + prizeAmount - entryCost),
            win_rate: this.adjustWinRate(bot.win_rate, shouldWin),
          });

          await db.recordBotGame(bot.id, score, lines, shouldWin, prizeAmount, mmrChange);
        } catch (botError) {
          console.warn(`BotEngine: Error processing bot ${bot.name}:`, botError);
        }
      }

      await db.rebuildLeaderboardCache();
    } catch (error) {
      console.warn('Bot Engine tick error (DB may be unavailable):', error);
    }
  }

  private generateScore(bot: any, shouldWin: boolean): number {
    const baseScores: Record<string, [number, number]> = {
      'Bronze': [200, 800],
      'Silver': [500, 1500],
      'Gold': [1000, 3000],
      'Plat': [2000, 5000],
      'Diamond': [3000, 8000],
    };
    const [min, max] = baseScores[bot.tier] || [500, 2000];
    if (shouldWin) {
      return Math.floor(max * 0.6 + Math.random() * max * 0.4);
    }
    return Math.floor(min + Math.random() * (max - min) * 0.4);
  }

  private getTargetMmr(tier: string): number {
    const targets: Record<string, number> = {
      'Bronze': 400,
      'Silver': 900,
      'Gold': 1500,
      'Plat': 2100,
      'Diamond': 2700,
    };
    return targets[tier] || 1000;
  }

  private generatePrize(bot: any): number {
    const basePrizes: Record<string, [number, number]> = {
      'Bronze': [0.5, 3],
      'Silver': [2, 8],
      'Gold': [5, 20],
      'Plat': [15, 50],
      'Diamond': [40, 150],
    };
    const [min, max] = basePrizes[bot.tier] || [1, 10];
    return parseFloat((min + Math.random() * (max - min)).toFixed(2));
  }

  private getEntryCost(tier: string): number {
    const costs: Record<string, number> = {
      'Bronze': 1,
      'Silver': 3,
      'Gold': 8,
      'Plat': 20,
      'Diamond': 50,
    };
    return costs[tier] || 5;
  }

  private adjustWinRate(current: number, won: boolean): number {
    const target = 50 + (Math.random() - 0.5) * 20;
    const adjustment = (target - current) * 0.05;
    return parseFloat(Math.max(25, Math.min(75, current + adjustment)).toFixed(2));
  }
}

export const botEngine = new BotEngine();
