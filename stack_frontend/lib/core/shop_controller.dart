import 'api_service.dart';

class ShopController {
  Future<List<dynamic>> getSkins() async {
    final response = await apiService.get('/shop/skins');
    if (response['success'] == true) {
      return response['skins'] ?? [];
    }
    return [];
  }

  Future<Map<String, dynamic>> getInventory(String userId) async {
    final response = await apiService.get('/shop/inventory/$userId');
    if (response['success'] == true) {
      return response;
    }
    return {'inventory': [], 'active_skin': null};
  }

  Future<Map<String, dynamic>> buySkin(String userId, String skinId) async {
    final response = await apiService.post('/shop/buy', {
      'user_id': userId,
      'skin_id': skinId,
    });
    return response;
  }

  Future<Map<String, dynamic>> equipSkin(String userId, String skinId) async {
    final response = await apiService.post('/shop/equip', {
      'user_id': userId,
      'skin_id': skinId,
    });
    return response;
  }

  Future<Map<String, dynamic>> getActiveSkin(String userId) async {
    final inventory = await getInventory(userId);
    return {'active_skin': inventory['active_skin']};
  }
}

final shopController = ShopController();
