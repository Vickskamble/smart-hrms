class AppConstants {
  static const String usersCollection = 'users';
  static const String customersCollection = 'customers';
  static const String transactionsCollection = 'transactions';

  static const String dateFormatYMD = 'yyyy-MM-dd';
  static const String dateFormatDMY = 'dd-MM-yyyy';
  static const String timeFormatHM = 'hh:mm a';
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm:ss';

  static const String currencySymbol = '₹';
  static const String currencyCode = 'INR';

  static const int defaultPageSize = 20;
  static const double defaultBalancePrecision = 2;

  // Office location for geofencing
  static const double officeLatitude = 19.0760;
  static const double officeLongitude = 72.8777;
  static const double geofenceRadiusMeters = 100.0;

  // HRMS specific constants
  static const int workDaysPerMonth = 30;
  static const int latePunchesPerDeduction = 1;
  static const double latePunchDeductionPercent = 0.5;
  static const double missedPunchDeductionPercent = 0.5;
}