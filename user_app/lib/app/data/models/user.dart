import 'package:pocketbase/pocketbase.dart';
import '../enums/user_enums.dart';
import 'base_model.dart';

/// User model based on PocketBase users collection
class User extends BaseModel {
  User(super.data);
  
  /// PocketBase collection name
  static const String collection = 'users';
  
  // Self-registration for dynamic model creation  
  static final _registered = (() {
    BaseModel.registerModel(collection, (data) => User(data));
    return true;
  })();
  
  // Ensure registration is triggered
  static void ensureRegistration() {
    // Access _registered to trigger the initialization
    _registered;
  }
  
  /// Create User from PocketBase record
  static User fromRecord(RecordModel record) => User(record.data);
  
  /// Create JSON for new user record (excludes system fields)
  static Map<String, dynamic> forCreate({
    required String email,
    required String password,
    String? name,
    String? phone,
    String? alternativePhone,
    String? address,
    String? city,
    String? state,
    String? country,
    String? postalCode,
    String? licenseNumber,
    String? organization,
    String? department,
    String? jobTitle,
    UserRole? role,
    UserStatus? status,
    String? specialization,
    PreferredLanguage? preferredLanguage,
    String? timezone,
    String? notes,
    String? avatar,
    bool? emailVisibility,
    bool? verified,
  }) {
    return {
      'email': email,
      'password': password,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (alternativePhone != null) 'alternativePhone': alternativePhone,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (country != null) 'country': country,
      if (postalCode != null) 'postalCode': postalCode,
      if (licenseNumber != null) 'licenseNumber': licenseNumber,
      if (organization != null) 'organization': organization,
      if (department != null) 'department': department,
      if (jobTitle != null) 'jobTitle': jobTitle,
      if (role != null) 'role': role.name,
      if (status != null) 'status': status.name,
      if (specialization != null) 'specialization': specialization,
      if (preferredLanguage != null) 'preferredLanguage': preferredLanguage.name,
      if (timezone != null) 'timezone': timezone,
      if (notes != null) 'notes': notes,
      if (avatar != null) 'avatar': avatar,
      if (emailVisibility != null) 'emailVisibility': emailVisibility,
      if (verified != null) 'verified': verified,
    };
  }
  
  // Direct properties - late final for performance
  late final String name = get<String>("name", "");
  late final String email = get<String>("email", "");
  late final bool emailVisibility = get<bool>("emailVisibility", false);
  late final bool verified = get<bool>("verified", false);
  late final String phone = get<String>("phone", "");
  late final String alternativePhone = get<String>("alternativePhone", "");
  late final String address = get<String>("address", "");
  late final String city = get<String>("city", "");
  late final String state = get<String>("state", "");
  late final String country = get<String>("country", "");
  late final String postalCode = get<String>("postalCode", "");
  late final String licenseNumber = get<String>("licenseNumber", "");
  late final String organization = get<String>("organization", "");
  late final String department = get<String>("department", "");
  late final String jobTitle = get<String>("jobTitle", "");
  late final String timezone = get<String>("timezone", "");
  late final String notes = get<String>("notes", "");
  late final String avatar = get<String>("avatar", "");
  
  // Enum properties
  late final UserRole? role = getEnum<UserRole>("role", UserRole.values);
  late final UserStatus? status = getEnum<UserStatus>("status", UserStatus.values);
  late final String specialization = get<String>("specialization", "");
  late final PreferredLanguage? preferredLanguage = getEnum<PreferredLanguage>("preferredLanguage", PreferredLanguage.values);
  
}