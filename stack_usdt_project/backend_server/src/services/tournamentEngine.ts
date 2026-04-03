import { db } from './supabase';

export interface TournamentConfig {
  type: string;
  entryFee: number;
  rake: number;
  maxPlayers: number;
  prizeDistribution: number[];
}

const TOURNAMENT_TYPES: Record<string, TournamentConfig> = {
  quick_duel: {
    type: 'quick_duel',
    entryFee: 2,
    rake: 20,
    maxPlayers: 2,
    prizeDistribution: [100],
  },
  standard: {
    type: 'standard',
    entryFee: 10,
    rake: 15,
    maxPlayers: 8,
    prizeDistribution: [50, 30, 20],
  },
  premium: {
    type: 'premium',
    entryFee: 50,
    rake: 12,
    maxPlayers: 16,
    prizeDistribution: [40, 25, 15, 10, 2.5, 2.5, 2.5, 2.5],
  },
  elite: {
    type: 'elite',
    entryFee: 100,
    rake: 10,
    maxPlayers: 32,
    prizeDistribution: [40, 25, 15, 10, 2, 2, 2, 2, 0.5, 0.5, 0.5, 0.5, 0.25, 0.25, 0.25, 0.25],
  },
  freeroll: {
    type: 'freeroll',
    entryFee: 0,
    rake: 0,
    maxPlayers: 50,
    prizeDistribution: [50, 30, 20],
  },
};

export class TournamentEngine {
  private running = false;
  private intervals: any[] = [];

  start() {
    if (this.running) return;
    this.running = true;
    this.scheduleTournaments();
    console.log('🏆 Tournament Engine started');
  }

  stop() {
    this.running = false;
    this.intervals.forEach(clearInterval);
    this.intervals = [];
    console.log('🏆 Tournament Engine stopped');
  }

  private async scheduleTournaments() {
    this.intervals.forEach(clearInterval);

    const freq = await db.getEconomyConfig('tournament_frequency');
    const quickMin = freq?.quick_duel_minutes ?? 2;
    const stdMin = freq?.standard_minutes ?? 10;
    const premMin = freq?.premium_minutes ?? 30;

    this.intervals.push(setInterval(() => this.createTournament('quick_duel'), quickMin * 60 * 1000));
    this.intervals.push(setInterval(() => this.createTournament('standard'), stdMin * 60 * 1000));
    this.intervals.push(setInterval(() => this.createTournament('premium'), premMin * 60 * 1000));

    // Create initial tournaments
    await this.createTournament('quick_duel');
    await this.createTournament('standard');
  }

  async createTournament(type: string): Promise<any> {
    const config = TOURNAMENT_TYPES[type];
    if (!config) return null;

    try {
      const rakeConfig = await db.getEconomyConfig('rake_config');
      const rake = rakeConfig?.[type] ?? config.rake;

    const tournament = await db.createTournament({
      type: config.type,
      entry_fee: config.entryFee,
      rake,
      max_players: config.maxPlayers,
      prize_pool: 0,
      prize_pool_net: 0,
      status: 'waiting',
    });

    // Auto-fill with bots
    try {
      const bots = await db.getActiveBots();
      const botCount = Math.min(config.maxPlayers - 1, Math.floor(bots.length * 0.3));
      const selectedBots = bots.sort(() => Math.random() - 0.5).slice(0, botCount);

      for (const bot of selectedBots) {
        await db.addParticipant(tournament.id, null, bot.id, 0, 0);
      }
    } catch (e) {
      console.warn('TournamentEngine: Could not fill tournament with bots (DB unavailable):', e);
    }

    return tournament;
    } catch (e) {
      console.warn('TournamentEngine: Failed to create tournament (DB unavailable):', e);
      return null;
    }
  }

  async completeTournament(tournamentId: string, results: Array<{
    participantId: string;
    userId?: string;
    botId?: string;
    score: number;
    lines: number;
  }>) {
    const tournament = await db.getTournament(tournamentId);
    if (!tournament) return;

    const config = TOURNAMENT_TYPES[tournament.type];
    const sorted = results.sort((a, b) => b.score - a.score);
    const totalEntry = tournament.entry_fee * sorted.length;
    const rakeAmount = totalEntry * (tournament.rake / 100);
    const netPool = totalEntry - rakeAmount;

    await db.updateTournament(tournamentId, {
      prize_pool: totalEntry,
      prize_pool_net: netPool,
      status: 'completed',
      completed_at: new Date().toISOString(),
    });

    for (let i = 0; i < sorted.length; i++) {
      const distPercent = i < config.prizeDistribution.length
        ? config.prizeDistribution[i] / 100
        : 0;
      const prize = netPool * distPercent;

      const oldMmr = await db.getParticipantMmr(sorted[i].userId, sorted[i].botId);
      const newMmr = this.calculateMMR(sorted, i, oldMmr);
      const mmrChange = newMmr - oldMmr;

      await db.updateParticipant(sorted[i].participantId, {
        placement: i + 1,
        prize_amount: prize,
        score: sorted[i].score,
        lines_cleared: sorted[i].lines,
        mmr_change: mmrChange,
      });

      if (sorted[i].userId && prize > 0) {
        await db.updateUserBalance(sorted[i].userId!, prize, 'add');
      }

      if (sorted[i].botId) {
        const bot = await db.getBotById(sorted[i].botId!);
        await db.updateBot(sorted[i].botId!, {
          mmr: newMmr,
          balance: Math.max(0, (bot?.balance || 0) + prize - tournament.entry_fee),
        });
      }

      if (sorted[i].userId) {
        await db.updateUserMMR(sorted[i].userId!, newMmr);
      }
    }

    await db.rebuildLeaderboardCache();
  }

  private calculateMMR(results: any[], placement: number, currentMmr: number): number {
    const K = currentMmr < 600 ? 32 : currentMmr < 1200 ? 24 : currentMmr < 1800 ? 16 : 12;
    const winRate = placement === 0 ? 1 : 0;
    const expected = 1 / (1 + Math.pow(10, (results[0].score - results[placement].score) / 400));
    const delta = Math.round(K * (winRate - expected));
    return Math.max(0, Math.min(3000, currentMmr + delta));
  }

  getTournamentTypes() {
    return Object.values(TOURNAMENT_TYPES);
  }
}

export const tournamentEngine = new TournamentEngine();
