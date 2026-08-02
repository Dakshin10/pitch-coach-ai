import 'package:flutter/material.dart';

class UserProfile {
  String name;
  String email;
  String role;
  String targetGoal;
  String experienceLevel;
  String targetIndustry;
  String feedbackTone;
  int sessionsCompleted;
  double avgScore;
  String memberSince;

  UserProfile({
    required this.name,
    required this.email,
    required this.role,
    required this.targetGoal,
    required this.experienceLevel,
    required this.targetIndustry,
    required this.feedbackTone,
    this.sessionsCompleted = 42,
    this.avgScore = 78.0,
    this.memberSince = 'Jan 2025',
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'PC';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

class UserProvider extends ChangeNotifier {
  UserProfile _user = UserProfile(
    name: 'Dakshin',
    email: 'dakshin@example.com',
    role: 'Computer Science Student',
    targetGoal: 'Technical Interviews & Pitch Presentations',
    experienceLevel: 'Intermediate',
    targetIndustry: 'Software & Technology',
    feedbackTone: 'Encouraging & Constructive',
  );

  bool _isLoggedIn = true;

  UserProfile get user => _user;
  bool get isLoggedIn => _isLoggedIn;

  void login({required String name, required String email}) {
    _isLoggedIn = true;
    _user.name = name.isNotEmpty ? name : _user.name;
    _user.email = email.isNotEmpty ? email : _user.email;
    notifyListeners();
  }

  void loginAsGuest() {
    _isLoggedIn = true;
    _user = UserProfile(
      name: 'Guest User',
      email: 'guest@pitchcoach.ai',
      role: 'Pitch Practitioner',
      targetGoal: 'General Public Speaking',
      experienceLevel: 'Beginner',
      targetIndustry: 'General',
      feedbackTone: 'Balanced',
    );
    notifyListeners();
  }

  void updateProfile({
    String? name,
    String? email,
    String? role,
    String? targetGoal,
    String? experienceLevel,
    String? targetIndustry,
    String? feedbackTone,
  }) {
    if (name != null && name.trim().isNotEmpty) {
      _user.name = name.trim();
    }
    if (email != null && email.trim().isNotEmpty) {
      _user.email = email.trim();
    }
    if (role != null && role.trim().isNotEmpty) {
      _user.role = role.trim();
    }
    if (targetGoal != null && targetGoal.trim().isNotEmpty) {
      _user.targetGoal = targetGoal.trim();
    }
    if (experienceLevel != null && experienceLevel.trim().isNotEmpty) {
      _user.experienceLevel = experienceLevel.trim();
    }
    if (targetIndustry != null && targetIndustry.trim().isNotEmpty) {
      _user.targetIndustry = targetIndustry.trim();
    }
    if (feedbackTone != null && feedbackTone.trim().isNotEmpty) {
      _user.feedbackTone = feedbackTone.trim();
    }
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    notifyListeners();
  }
}
