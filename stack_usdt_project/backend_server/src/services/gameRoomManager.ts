import { Server as HttpServer } from 'http';
import { Server, Socket } from 'socket.io';
import { db } from './supabase';

interface Player {
  userId: string;
  username: string;
  mmr: number;
  socketId: string;
  score: number;
  linesCleared: number;
  level: number;
  isReady: boolean;
  gameFinished: boolean;
}

interface GameRoom {
  id: string;
  tournamentId: string;
  tournamentType: string;
  entryFee: number;
  players: Player[];
  maxPlayers: number;
  status: 'waiting' | 'countdown' | 'playing' | 'finished';
  startedAt: number;
  countdownStart: number;
}

export class GameRoomManager {
  private io: Server;
  private rooms: Map<string, GameRoom> = new Map();
  private userToRoom: Map<string, string> = new Map();

  constructor(server: HttpServer) {
    this.io = new Server(server, {
      cors: { origin: '*' },
      pingTimeout: 30000,
      pingInterval: 10000,
    });

    this.setupHandlers();
    console.log('🎮 Game Room Manager initialized');
  }

  private setupHandlers() {
    this.io.on('connection', (socket: Socket) => {
      console.log(`🔌 Player connected: ${socket.id}`);

      socket.on('join_tournament', this.handleJoinTournament.bind(this));
      socket.on('game_ready', this.handleGameReady.bind(this));
      socket.on('game_update', this.handleGameUpdate.bind(this));
      socket.on('game_finished', this.handleGameFinished.bind(this));
      socket.on('disconnect', () => this.handleDisconnect(socket));
    });
  }

  private async handleJoinTournament(socket: Socket, data: {
    userId: string;
    tournamentId: string;
    tournamentType: string;
    entryFee: number;
    maxPlayers: number;
  }) {
    try {
      const user = await db.getUserById(data.userId);
      if (!user) {
        socket.emit('error', { message: 'User not found' });
        return;
      }

      if (user.is_banned) {
        socket.emit('error', { message: 'Account is banned' });
        return;
      }

      // Find existing room or create new one
      let room = this.findAvailableRoom(data.tournamentType);
      if (!room) {
        room = this.createRoom(data);
      }

      // Add player to room
      const player: Player = {
        userId: data.userId,
        username: user.username || 'Player',
        mmr: (user.mining_level || 1) * 100,
        socketId: socket.id,
        score: 0,
        linesCleared: 0,
        level: 1,
        isReady: false,
        gameFinished: false,
      };

      room.players.push(player);
      this.userToRoom.set(data.userId, room.id);
      socket.join(room.id);

      // Notify room
      this.io.to(room.id).emit('player_joined', {
        roomId: room.id,
        players: room.players.map(p => ({
          userId: p.userId,
          username: p.username,
          mmr: p.mmr,
          isReady: p.isReady,
        })),
        playerCount: room.players.length,
        maxPlayers: room.maxPlayers,
        status: room.status,
      });

      // If room is full, start countdown
      if (room.players.length >= room.maxPlayers && room.status === 'waiting') {
        this.startCountdown(room);
      }
    } catch (error: any) {
      console.error('Error joining tournament:', error);
      socket.emit('error', { message: 'Failed to join tournament' });
    }
  }

  private findAvailableRoom(type: string): GameRoom | null {
    for (const room of this.rooms.values()) {
      if (
        room.tournamentType === type &&
        room.status === 'waiting' &&
        room.players.length < room.maxPlayers
      ) {
        return room;
      }
    }
    return null;
  }

  private createRoom(data: {
    tournamentId: string;
    tournamentType: string;
    entryFee: number;
    maxPlayers: number;
  }): GameRoom {
    const room: GameRoom = {
      id: `room_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      tournamentId: data.tournamentId,
      tournamentType: data.tournamentType,
      entryFee: data.entryFee,
      players: [],
      maxPlayers: data.maxPlayers,
      status: 'waiting',
      startedAt: 0,
      countdownStart: 0,
    };
    this.rooms.set(room.id, room);
    return room;
  }

  private startCountdown(room: GameRoom) {
    room.status = 'countdown';
    room.countdownStart = Date.now();

    const countdown = () => {
      const elapsed = (Date.now() - room.countdownStart) / 1000;
      const remaining = Math.max(0, 5 - Math.floor(elapsed));

      this.io.to(room.id).emit('countdown', {
        seconds: remaining,
        roomId: room.id,
      });

      if (remaining <= 0) {
        this.startGame(room);
      } else {
        setTimeout(countdown, 1000);
      }
    };

    countdown();
  }

  private startGame(room: GameRoom) {
    room.status = 'playing';
    room.startedAt = Date.now();

    this.io.to(room.id).emit('game_start', {
      roomId: room.id,
      tournamentType: room.tournamentType,
      players: room.players.map(p => ({
        userId: p.userId,
        username: p.username,
        mmr: p.mmr,
      })),
    });
  }

  private handleGameReady(socket: Socket, data: { userId: string; roomId: string }) {
    const room = this.rooms.get(data.roomId);
    if (!room) return;

    const player = room.players.find(p => p.userId === data.userId);
    if (!player) return;

    player.isReady = true;

    this.io.to(room.id).emit('player_ready', {
      userId: data.userId,
      allReady: room.players.every(p => p.isReady),
    });
  }

  private handleGameUpdate(socket: Socket, data: {
    userId: string;
    roomId: string;
    score: number;
    linesCleared: number;
    level: number;
  }) {
    const room = this.rooms.get(data.roomId);
    if (!room || room.status !== 'playing') return;

    const player = room.players.find(p => p.userId === data.userId);
    if (!player) return;

    player.score = data.score;
    player.linesCleared = data.linesCleared;
    player.level = data.level;

    // Broadcast to other players in the room
    socket.to(room.id).emit('opponent_update', {
      userId: data.userId,
      username: player.username,
      score: data.score,
      linesCleared: data.linesCleared,
      level: data.level,
    });
  }

  private async handleGameFinished(socket: Socket, data: {
    userId: string;
    roomId: string;
    score: number;
    linesCleared: number;
    level: number;
    playTimeSeconds: number;
  }) {
    const room = this.rooms.get(data.roomId);
    if (!room) return;

    const player = room.players.find(p => p.userId === data.userId);
    if (!player || player.gameFinished) return;

    player.score = data.score;
    player.linesCleared = data.linesCleared;
    player.level = data.level;
    player.gameFinished = true;

    // Notify others
    socket.to(room.id).emit('player_finished', {
      userId: data.userId,
      username: player.username,
      score: data.score,
    });

    // If all players finished, calculate results
    if (room.players.every(p => p.gameFinished)) {
      await this.finishGame(room);
    }
  }

  private async finishGame(room: GameRoom) {
    room.status = 'finished';

    // Sort players by score
    const sorted = [...room.players].sort((a, b) => b.score - a.score);

    // Calculate prize distribution
    const totalEntry = room.entryFee * room.players.length;
    const rakeConfig = await db.getEconomyConfig('rake_config');
    const rake = rakeConfig?.[room.tournamentType] ?? 15;
    const netPool = totalEntry * (1 - rake / 100);

    const distribution = this.getPrizeDistribution(room.players.length);

    const results = sorted.map((player, index) => ({
      userId: player.userId,
      username: player.username,
      score: player.score,
      linesCleared: player.linesCleared,
      placement: index + 1,
      prize: parseFloat((netPool * (distribution[index] / 100)).toFixed(4)),
    }));

    // Distribute prizes
    for (const result of results) {
      if (result.prize > 0) {
        await db.updateUserBalance(result.userId, result.prize, 'add');
      }

      // Notify each player
      const playerSocket = room.players.find(p => p.userId === result.userId)?.socketId;
      if (playerSocket) {
        this.io.to(playerSocket).emit('game_result', {
          placement: result.placement,
          score: result.score,
          prize: result.prize,
          leaderboard: results.map(r => ({
            userId: r.userId,
            username: r.username,
            score: r.score,
            placement: r.placement,
            prize: r.prize,
          })),
        });
      }
    }

    // Record in database
    try {
      const tournament = await db.createTournament({
        type: room.tournamentType,
        entry_fee: room.entryFee,
        rake,
        prize_pool: totalEntry,
        prize_pool_net: netPool,
        max_players: room.maxPlayers,
        current_players: room.players.length,
        status: 'completed',
        started_at: new Date(room.startedAt).toISOString(),
        completed_at: new Date().toISOString(),
      });

      for (const result of results) {
        await db.addParticipant(
          tournament.id,
          result.userId,
          null,
          result.score,
          result.linesCleared,
        );
      }
    } catch (error) {
      console.error('Error recording tournament results:', error);
    }

    // Clean up room after 30 seconds
    setTimeout(() => {
      this.rooms.delete(room.id);
      for (const player of room.players) {
        this.userToRoom.delete(player.userId);
      }
    }, 30000);
  }

  private getPrizeDistribution(playerCount: number): number[] {
    if (playerCount <= 2) return [100];
    if (playerCount <= 4) return [60, 40];
    if (playerCount <= 8) return [50, 30, 20];
    return [40, 25, 15, 10, 2.5, 2.5, 2.5, 2.5];
  }

  private handleDisconnect(socket: Socket) {
    // Find which room this player was in
    for (const [userId, roomId] of this.userToRoom.entries()) {
      const room = this.rooms.get(roomId);
      if (room) {
        const player = room.players.find(p => p.socketId === socket.id);
        if (player) {
          room.players = room.players.filter(p => p.socketId !== socket.id);
          this.userToRoom.delete(userId);

          this.io.to(roomId).emit('player_left', {
            userId,
            username: player.username,
          });

          // If room is now empty, delete it
          if (room.players.length === 0) {
            this.rooms.delete(roomId);
          }
        }
      }
    }
    console.log(`🔌 Player disconnected: ${socket.id}`);
  }

  getActiveRooms() {
    return Array.from(this.rooms.values()).map(room => ({
      id: room.id,
      type: room.tournamentType,
      players: room.players.length,
      maxPlayers: room.maxPlayers,
      status: room.status,
    }));
  }
}
