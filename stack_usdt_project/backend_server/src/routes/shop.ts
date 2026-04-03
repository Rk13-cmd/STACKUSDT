import { Router } from 'express';
import { db } from '../services/supabase';

const router = Router();

// GET /api/shop/skins - Return full skin catalog
router.get('/skins', async (req, res) => {
  try {
    const skins = await db.getAllSkins();
    res.json({ success: true, skins });
  } catch (error: any) {
    console.error('Error fetching skins:', error);
    res.status(500).json({ error: 'Failed to fetch skin catalog' });
  }
});

// GET /api/shop/inventory/:userId - Return user's owned skins
router.get('/inventory/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const inventory = await db.getUserInventory(userId);
    const activeSkin = await db.getUserActiveSkin(userId);

    res.json({
      success: true,
      inventory,
      active_skin: activeSkin,
    });
  } catch (error: any) {
    console.error('Error fetching inventory:', error);
    res.status(500).json({ error: 'Failed to fetch inventory' });
  }
});

// POST /api/shop/buy - Purchase a skin (server-side transaction)
router.post('/buy', async (req, res) => {
  try {
    const { user_id, skin_id } = req.body;

    if (!user_id || !skin_id) {
      return res.status(400).json({ error: 'user_id and skin_id are required' });
    }

    // Fetch user and skin in parallel
    const user = await db.getUserById(user_id);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const skin = await db.getSkinById(skin_id);
    if (!skin) {
      return res.status(404).json({ error: 'Skin not found' });
    }

    // Free skins don't need balance check
    if (skin.price_usdt > 0) {
      const userBalance = user.usdt_balance || 0;
      if (userBalance < skin.price_usdt) {
        return res.status(402).json({
          error: 'INSUFFICIENT_LIQUIDITY',
          message: `Insufficient balance. Skin costs ${skin.price_usdt} USDT, you have ${userBalance.toFixed(4)} USDT`,
          required: skin.price_usdt,
          available: userBalance,
        });
      }

      // Deduct balance
      await db.updateUserBalance(user_id, skin.price_usdt, 'subtract');
    }

    // Add to inventory (UNIQUE constraint prevents duplicates)
    try {
      await db.addToInventory(user_id, skin_id);
    } catch (err: any) {
      if (err.message && err.message.includes('duplicate')) {
        return res.status(409).json({ error: 'You already own this skin' });
      }
      throw err;
    }

    // Auto-equip if it's the first skin purchased
    if (!user.active_skin_id) {
      await db.setUserActiveSkin(user_id, skin_id);
    }

    res.json({
      success: true,
      message: `Skin "${skin.name}" purchased successfully`,
      skin: {
        id: skin.id,
        name: skin.name,
        price_paid: skin.price_usdt,
      },
      new_balance: user.usdt_balance - skin.price_usdt,
    });
  } catch (error: any) {
    console.error('Error purchasing skin:', error);
    res.status(500).json({ error: 'Failed to complete purchase' });
  }
});

// POST /api/shop/equip - Equip an owned skin
router.post('/equip', async (req, res) => {
  try {
    const { user_id, skin_id } = req.body;

    if (!user_id || !skin_id) {
      return res.status(400).json({ error: 'user_id and skin_id are required' });
    }

    // Verify user owns this skin
    const inventory = await db.getUserInventory(user_id);
    const ownsSkin = inventory.some((item: any) => item.skin_id === skin_id);

    if (!ownsSkin) {
      return res.status(403).json({ error: 'You do not own this skin' });
    }

    await db.setUserActiveSkin(user_id, skin_id);

    const skin = await db.getSkinById(skin_id);
    res.json({
      success: true,
      message: `Skin "${skin?.name}" equipped`,
      active_skin: skin,
    });
  } catch (error: any) {
    console.error('Error equipping skin:', error);
    res.status(500).json({ error: 'Failed to equip skin' });
  }
});

export default router;
