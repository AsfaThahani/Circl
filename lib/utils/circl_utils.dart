import 'dart:math' as math;

double haversineDistance(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const double earthRadiusKm = 6371.0;
  final double dLat = _toRadians(lat2 - lat1);
  final double dLon = _toRadians(lon2 - lon1);

  final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(lat1)) *
          math.cos(_toRadians(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);

  final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

double _toRadians(double degrees) => degrees * math.pi / 180.0;

String auraLevelFor(int circlPoints) {
  if (circlPoints < 0) return 'Bronze';
  if (circlPoints < 100) return 'Bronze';
  if (circlPoints < 250) return 'Silver';
  if (circlPoints < 500) return 'Gold';
  return 'Diamond';
}

int circlPointsForCompletion({
  required String requestType,
}) {
  const int basePoints = 5;
  const int communityBonus = 5;
  final bool isFreeExchange =
      requestType == 'Free Favour' || requestType == 'Free Borrow';
  return basePoints + (isFreeExchange ? communityBonus : 0);
}

double platformCommission(double amount) {
  if (amount <= 0) return 0.0;
  return (amount * 0.05).roundToDouble();
}
