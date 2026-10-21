/// Centralized environment configuration for the Circl platform.
///
/// Values are supplied at compile/run time using `--dart-define` or `--dart-define-from-file=.env`.
///
/// Example:
/// ```bash
/// flutter run --dart-define-from-file=.env
/// ```
class EnvConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-project.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'your-supabase-anon-key',
  );

  static const String payhereMerchantId = String.fromEnvironment(
    'PAYHERE_MERCHANT_ID',
    defaultValue: 'YOUR_PAYHERE_MERCHANT_ID',
  );

  static const String payhereSecret = String.fromEnvironment(
    'PAYHERE_SECRET',
    defaultValue: 'YOUR_PAYHERE_SECRET',
  );

  static const String payhereNotifyUrl = String.fromEnvironment(
    'PAYHERE_NOTIFY_URL',
    defaultValue: 'https://your-project.supabase.co/functions/v1/payhere-webhook',
  );

  static const String nicPepper = String.fromEnvironment(
    'NIC_PEPPER',
    defaultValue: 'Circl_Secure_Pepper_ChangeInProduction',
  );
}
