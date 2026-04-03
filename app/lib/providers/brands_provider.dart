import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/brand.dart';
import '../services/api_service.dart';

final apiServiceProvider = Provider((ref) => ApiService());

final brandsProvider = FutureProvider<List<Brand>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return api.getBrands();
});

final selectedBrandProvider = StateProvider<String?>((ref) => null);

final brandHealthProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, brandId) async {
  final api = ref.read(apiServiceProvider);
  return api.getBrandHealth(brandId);
});

final brandChannelsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, brandId) async {
  final api = ref.read(apiServiceProvider);
  return api.getBrandChannels(brandId);
});

final brandSocialProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, brandId) async {
  final api = ref.read(apiServiceProvider);
  return api.getBrandSocial(brandId);
});
