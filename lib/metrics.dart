enum DistanceUnit { km, mi }

enum EnergyUnit { kcal, kj }

/// Body details used to estimate distance and calories from steps, and the units to show them in.
/// Keep the formulas in sync with android/.../Metrics.kt (used by the widgets).
class BodyProfile {
  const BodyProfile({
    required this.heightCm,
    required this.weightKg,
    required this.imperial,
    required this.distanceUnit,
    required this.energyUnit,
  });

  static const defaults = BodyProfile(
    heightCm: 170,
    weightKg: 70,
    imperial: false,
    distanceUnit: DistanceUnit.km,
    energyUnit: EnergyUnit.kcal,
  );

  final int heightCm;
  final int weightKg;

  /// Height and weight are entered in feet/inches and pounds instead of cm and kg.
  final bool imperial;

  final DistanceUnit distanceUnit;
  final EnergyUnit energyUnit;

  factory BodyProfile.fromMap(Map<Object?, Object?>? map) {
    if (map == null) return defaults;
    final imperial = map['imperial'] as bool? ?? defaults.imperial;
    return BodyProfile(
      heightCm: map['heightCm'] as int? ?? defaults.heightCm,
      weightKg: map['weightKg'] as int? ?? defaults.weightKg,
      imperial: imperial,
      // Profiles saved before units were separate used miles with imperial.
      distanceUnit:
          DistanceUnit.values.asNameMap()[map['distanceUnit']] ?? (imperial ? DistanceUnit.mi : DistanceUnit.km),
      energyUnit: EnergyUnit.values.asNameMap()[map['energyUnit']] ?? defaults.energyUnit,
    );
  }

  Map<String, Object> toMap() => {
        'heightCm': heightCm,
        'weightKg': weightKg,
        'imperial': imperial,
        'distanceUnit': distanceUnit.name,
        'energyUnit': energyUnit.name,
      };

  BodyProfile copyWith({
    int? heightCm,
    int? weightKg,
    bool? imperial,
    DistanceUnit? distanceUnit,
    EnergyUnit? energyUnit,
  }) =>
      BodyProfile(
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        imperial: imperial ?? this.imperial,
        distanceUnit: distanceUnit ?? this.distanceUnit,
        energyUnit: energyUnit ?? this.energyUnit,
      );

  /// Average walking stride is ~41.5% of body height.
  double get _strideMeters => heightCm * 0.415 / 100;

  double distanceKm(int steps) => steps * _strideMeters / 1000;

  /// ~0.57 kcal per pound of body weight per mile walked (≈0.78 kcal/kg/km).
  double _kcal(int steps) => distanceKm(steps) * weightKg * 0.78;

  int calories(int steps) => _kcal(steps).floor();

  /// Distance in [distanceUnit].
  double distance(int steps) => distanceUnit == DistanceUnit.mi ? distanceKm(steps) * 0.621371 : distanceKm(steps);

  /// Energy burned in [energyUnit].
  int energy(int steps) => energyUnit == EnergyUnit.kj ? (_kcal(steps) * 4.184).floor() : calories(steps);

  @override
  bool operator ==(Object other) =>
      other is BodyProfile &&
      other.heightCm == heightCm &&
      other.weightKg == weightKg &&
      other.imperial == imperial &&
      other.distanceUnit == distanceUnit &&
      other.energyUnit == energyUnit;

  @override
  int get hashCode => Object.hash(heightCm, weightKg, imperial, distanceUnit, energyUnit);
}
