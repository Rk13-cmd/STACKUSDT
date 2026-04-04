import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { createServer } from 'http';
import path from 'path';
import authRoutes from './routes/auth';
import gameRoutes from './routes/game';
import userRoutes from './routes/user';
import withdrawRoutes from './routes/withdraw';
import shopRoutes from './routes/shop';
import depositRoutes from './routes/deposit';
import adminRoutes from './routes/admin';
import tournamentRoutes from './routes/tournament';
import economyRoutes from './routes/economy';
import featuresRoutes from './routes/features';
import { botEngine } from './services/botEngine';
import { tournamentEngine } from './services/tournamentEngine';
import { GameRoomManager } from './services/gameRoomManager';
import { paymentSync } from './services/paymentSync';
import { stakingService } from './services/stakingService';
import { bonusService } from './services/bonusService';
import { referralService } from './services/referralService';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

app.use((req: Request, res: Response, next: NextFunction) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// Health check
app.get('/health', (req: Request, res: Response) => {
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(), 
    service: 'STACK USDT API' 
  });
});

// API Routes (must come before static files)
app.use('/api/auth', authRoutes);
app.use('/api/game', gameRoutes);
app.use('/api/user', userRoutes);
app.use('/api/withdraw', withdrawRoutes);
app.use('/api/shop', shopRoutes);
app.use('/api/deposit', depositRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/tournament', tournamentRoutes);
app.use('/api/economy', economyRoutes);
app.use('/api/features', featuresRoutes);

// Expose active rooms via API
app.get('/api/game/rooms', (req: Request, res: Response) => {
  res.json({ success: true, rooms: gameRoomManager.getActiveRooms() });
});

// Serve Flutter Web static files
// Try multiple possible paths for production vs development
const possiblePaths = [
  path.join(__dirname, '..', 'frontend_build'),           // from dist/
  path.join(process.cwd(), 'stack_usdt_project', 'backend_server', 'frontend_build'), // from repo root
  path.join(__dirname, '..', '..', 'frontend_build'),     // fallback
];

let frontendPath = possiblePaths[0];
for (const p of possiblePaths) {
  try {
    require('fs').accessSync(path.join(p, 'index.html'));
    frontendPath = p;
    break;
  } catch {
    // try next path
  }
}
app.use(express.static(frontendPath));

// Catch-all: serve Flutter app for non-API routes
app.get('*', (req: Request, res: Response) => {
  res.sendFile(path.join(frontendPath, 'index.html'));
});

// Error handler (must be after all routes)
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  console.error('Error:', err.message);
  res.status(500).json({ error: 'Internal server error' });
});

// Create HTTP server and attach Socket.io
const server = createServer(app);
const gameRoomManager = new GameRoomManager(server);

server.listen(PORT, () => {
  console.log(`
╔═══════════════════════════════════════════════════╗
║   🎮 STACK USDT API SERVER                       ║
║   🚀 Running on http://localhost:${PORT}             ║
║   🔌 WebSocket enabled                           ║
║   🌐 Serving Flutter Web frontend                ║
╚═══════════════════════════════════════════════════╝
  `);
  botEngine.start();
  tournamentEngine.start();

  setInterval(async () => {
    try {
      const result = await paymentSync.syncPendingPayments();
      if (result.updated > 0 || result.credited > 0) {
        console.log(`[PaymentSync] Checked: ${result.checked}, Updated: ${result.updated}, Credited: ${result.credited}, Errors: ${result.errors}`);
      }
      if (result.stuckPayments.length > 0) {
        console.warn(`[PaymentSync] ${result.stuckPayments.length} stuck payments detected`);
      }
    } catch (err: any) {
      console.error('[PaymentSync] Sync error:', err.message);
    }
  }, 5 * 60 * 1000);

  setInterval(async () => {
    try {
      const distributed = await stakingService.distributeAllRewards();
      if (distributed > 0) {
        console.log('[Staking] Distributed $' + distributed.toFixed(4) + ' USDT in rewards');
      }
    } catch (err: any) {
      console.error('[Staking] Reward distribution error:', err.message);
    }
  }, 24 * 60 * 60 * 1000);

  setInterval(async () => {
    try {
      const { supabase } = await import('./services/supabase');
      const today = new Date().toISOString().split('T')[0];
      const { error } = await supabase.rpc('create_daily_snapshot', { p_date: today });
      if (error) {
        console.error('[DailySnapshot] Error:', error.message);
      } else {
        console.log('[DailySnapshot] Snapshot created for ' + today);
      }
    } catch (err: any) {
      console.error('[DailySnapshot] Failed:', err.message);
    }
  }, 24 * 60 * 60 * 1000);
});

export default app;
