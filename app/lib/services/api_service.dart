import 'package:dio/dio.dart';
import '../models/brand.dart';
import '../models/alert.dart';
import '../models/scenario.dart';

class ApiService {
  static const String baseUrl = '/api';
  final Dio _dio;

  ApiService() : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 120),
  ));

  Future<List<Brand>> getBrands() async {
    final response = await _dio.get('/brands');
    return (response.data as List).map((j) => Brand.fromJson(j)).toList();
  }

  Future<List<Map<String, dynamic>>> getBrandHealth(String brandId) async {
    final response = await _dio.get('/brands/$brandId/health');
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<List<Map<String, dynamic>>> getBrandChannels(String brandId) async {
    final response = await _dio.get('/brands/$brandId/channels');
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<List<Map<String, dynamic>>> getBrandSocial(String brandId) async {
    final response = await _dio.get('/brands/$brandId/social');
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<List<Alert>> getAlerts() async {
    final response = await _dio.get('/alerts');
    return (response.data as List).map((j) => Alert.fromJson(j)).toList();
  }

  Future<String> chat(List<Map<String, String>> messages) async {
    final response = await _dio.post('/chat', data: {'messages': messages});
    return response.data['content'] as String;
  }

  Future<Scenario> runScenario(String brand, Map<String, double> proposedSpend) async {
    final response = await _dio.post('/scenario', data: {
      'brand': brand,
      'proposedSpend': proposedSpend,
    });
    return Scenario.fromJson(response.data);
  }
}
