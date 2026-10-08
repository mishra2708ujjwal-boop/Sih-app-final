class EmergencyContact {
  final String name;
  final String relation;
  final String phone;
  final bool isPrimary;

  const EmergencyContact({
    required this.name,
    required this.relation,
    required this.phone,
    this.isPrimary = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'relation': relation,
        'phone': phone,
        'isPrimary': isPrimary,
      };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) => EmergencyContact(
        name: json['name'] as String? ?? 'Contact',
        relation: json['relation'] as String? ?? 'Family',
        phone: json['phone'] as String? ?? '+91 98765 43210',
        isPrimary: json['isPrimary'] as bool? ?? false,
      );
}

class UserProfile {
  final String name;
  final int age;
  final String gender;
  final double heightCm;
  final double weightKg;
  final String bloodGroup;
  final List<String> medicalConditions; // e.g. 'Asthma', 'Hypertension'
  final List<EmergencyContact> emergencyContacts;
  final bool isVulnerableProfile;

  const UserProfile({
    required this.name,
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.bloodGroup,
    required this.medicalConditions,
    required this.emergencyContacts,
    this.isVulnerableProfile = false,
  });

  factory UserProfile.defaultProfile() {
    return const UserProfile(
      name: 'Aditya Sharma',
      age: 28,
      gender: 'Male',
      heightCm: 176.0,
      weightKg: 72.5,
      bloodGroup: 'B+',
      medicalConditions: ['Mild Asthma'],
      emergencyContacts: [
        EmergencyContact(
          name: 'Priya Sharma',
          relation: 'Spouse',
          phone: '+91 98112 34567',
          isPrimary: true,
        ),
        EmergencyContact(
          name: 'Dr. R. K. Verma',
          relation: 'Physician',
          phone: '+91 94123 45678',
          isPrimary: false,
        ),
      ],
      isVulnerableProfile: false,
    );
  }

  UserProfile copyWith({
    String? name,
    int? age,
    String? gender,
    double? heightCm,
    double? weightKg,
    String? bloodGroup,
    List<String>? medicalConditions,
    List<EmergencyContact>? emergencyContacts,
    bool? isVulnerableProfile,
  }) {
    return UserProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      isVulnerableProfile: isVulnerableProfile ?? this.isVulnerableProfile,
    );
  }
}
