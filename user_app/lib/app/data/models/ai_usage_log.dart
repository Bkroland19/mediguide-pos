import 'backend_record.dart';
import 'base_model.dart';
import 'user.dart';

/// AI Assistant usage log model for tracking AI interactions and improving responses
class AiUsageLog extends BaseModel {
  AiUsageLog(super.data) {
    _register();
  }

  /// backend collection name
  static const String collection = 'ai_usage_logs';
  // Self-registration for dynamic model creation
  static bool _didRegister = false;

  static void _register() {
    if (_didRegister) return;
    BaseModel.registerModel(collection, (data) => AiUsageLog(data));
    _didRegister = true;
  }

  /// Create AiUsageLog from backend record
  static AiUsageLog fromRecord(RecordModel record) => AiUsageLog(record.data);

  /// Create JSON for new AI usage log record
  static Map<String, dynamic> forCreate({required String userId}) {
    return {'user_id': userId};
  }

  // Direct field properties
  late final String userId = get<String>("user_id", "");

  // Relationship properties
  late final User? user = getRelation<User>("user_id");
}
