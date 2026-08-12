import 'package:printer_agent/core/config/print_config.dart';

import 'restaurant_profile_api.dart';
import 'restaurant_profile_model.dart';
import 'restaurant_profile_store.dart';

class RestaurantProfileRepository {
  final RestaurantProfileApi api;
  final RestaurantProfileStore store;

  RestaurantProfileRepository({
    required this.api,
    required this.store,
  });

  Future<RestaurantProfileModel?> getLocalProfile() async {
    return store.get();
  }

  Future<RestaurantProfileModel> fetchAndStore({
    required String token,
  }) async {
    final response = await api.fetchProfile(token: token);
    final profile = RestaurantProfileModel.fromApi(response);
    await store.save(profile);
    // Restaurant ID must ONLY ever come from the restaurant profile API — the
    // printer-agent-config endpoint may echo a stale/wrong value, so this is
    // the single source of truth and Settings shows it read-only.
    if (profile.restaurantId > 0) {
      PrintConfig.restaurantId = profile.restaurantId;
      await PrintConfig.save();
    }
    final saved = await store.get();
    print('✅ Saved profile name: ${saved?.restaurantName}');
    print('✅ Saved profile phone: ${saved?.restaurantPhone}');
    print('✅ Saved profile restaurantId: ${saved?.restaurantId}');
    return profile;
  }

  Future<RestaurantProfileModel?> syncOnAppStart({
    required String token,
  }) async {
    try {
      return await fetchAndStore(token: token);
    } catch (_) {
      return await getLocalProfile();
    }
  }

  Future<RestaurantProfileModel?> refresh({
    required String token,
  }) async {
    try {
      return await fetchAndStore(token: token);
    } catch (_) {
      return await getLocalProfile();
    }
  }
}
