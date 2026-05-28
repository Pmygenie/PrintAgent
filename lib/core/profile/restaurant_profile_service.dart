import 'restaurant_profile_model.dart';
import 'restaurant_profile_store.dart';

class RestaurantProfileService {
  static final RestaurantProfileStore _store = RestaurantProfileStore();

  static Future<RestaurantProfileModel> getProfile() async {
    return await _store.get() ?? RestaurantProfileModel.empty();
  }

  static Future<bool> hasProfile() async {
    final profile = await _store.get();
    return profile != null && profile.isNotEmpty;
  }

  static Future<void> clearProfile() async {
    await _store.clear();
  }
}