import 'package:flutter/material.dart';

/// ألوان مستخرجة حرفياً من ملف الشعار الرسمي (logo.svg).
class Brand {
  static const green = Color(0xFF136031); // الإطار والكتابة الخضراء
  static const red = Color(0xFFE82629); // كلمة «الحربي»
  static const white = Color(0xFFFFFFFF);

  // درجات مشتقة من الأخضر الأصلي للحالات والعناصر التفاعلية
  static const greenDark = Color(0xFF0C3F20);
  static const greenLight = Color(0xFF2E8B57);
  static const greenTint = Color(0xFFE6F2EA);

  // رمادي محايد
  static const gray50 = Color(0xFFF5F6F5);
  static const gray200 = Color(0xFFE0E3E1);
  static const gray500 = Color(0xFF6B726E);
  static const gray900 = Color(0xFF1B1F1D);

  // حالات
  static const success = Color(0xFF1E8E4E);
  static const warning = Color(0xFFE59A12);
  static const error = Color(0xFFB3261E); // أغمق من الأحمر المميز كي لا يختلط به
  static const info = Color(0xFF1F6FB5);
}
