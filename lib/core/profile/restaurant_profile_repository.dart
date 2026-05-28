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
    final saved = await store.get();
    print('✅ Saved profile name: ${saved?.restaurantName}');
    print('✅ Saved profile phone: ${saved?.restaurantPhone}');
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
