import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { createServer } from 'http';
import authRoutes from './routes/auth';
import gameRoutes from './routes/game';
import userRoutes from './routes/user';
import withdrawRoutes from './routes/withdraw';
import shopRoutes from './routes/shop';
import depositRoutes from './routes/deposit';
import adminRoutes from './routes/admin';
import tournamentRoutes from './routes/tournament';
import economyRoutes from './routes/economy';
import { botEngine } from './services/botEngine';
import { tournamentEngine } from './services/tournamentEngine';
import { GameRoomManager } from './services/gameRoomManager';

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

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/game', gameRoutes);
app.use('/api/user', userRoutes);
app.use('/api/withdraw', withdrawRoutes);
app.use('/api/shop', shopRoutes);
app.use('/api/deposit', depositRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/tournament', tournamentRoutes);
app.use('/api/economy', economyRoutes);

// 404 handler
app.use((req: Request, res: Response) => {
  res.status(404).json({ error: 'Endpoint not found', path: req.path });
});

// Error handler
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  console.error('Error:', err.message);
  res.status(500).json({ error: 'Internal server error' });
});

// Create HTTP server and attach Socket.io
const server = createServer(app);
const gameRoomManager = new GameRoomManager(server);

// Expose active rooms via API
app.get('/api/game/rooms', (req: Request, res: Response) => {
  res.json({ success: true, rooms: gameRoomManager.getActiveRooms() });
});

server.listen(PORT, () => {
  console.log(`
╔═══════════════════════════════════════════════════╗
║   🎮 STACK USDT API SERVER                       ║
║   🚀 Running on http://localhost:${PORT}             ║
║   🔌 WebSocket enabled                           ║
╚═══════════════════════════════════════════════════╝
  `);
  botEngine.start();
  tournamentEngine.start();
});

export default app;
