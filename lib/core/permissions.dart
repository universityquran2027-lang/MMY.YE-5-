/// صلاحيات الأدوار الثلاثة (وثيقة الأقسام 4.3 إلى 4.5).
enum Role {
  manager, assistant, archivist;

  static Role parse(Object? v) =>
      Role.values.firstWhere((r) => r.name == v, orElse: () => Role.archivist);

  /// إضافة/تعديل/حذف في الأقسام التشغيلية: المدير ومساعده فقط. الأرشيف اطلاع وطباعة وتصدير.
  bool get canEditOperations => this != Role.archivist;
  bool get canManageAccounts => this == Role.manager;
  bool get canConfigureSecurity => this == Role.manager;
  bool get canConfigureEvaluationWeights => this == Role.manager;
}

const statusLabels = {
  'active': 'نشط', 'stopped': 'متوقف',
  'suspended': 'موقوف',
  'planned': 'مخططة', 'running': 'جارية', 'done': 'منتهية', 'cancelled': 'ملغية',
};
