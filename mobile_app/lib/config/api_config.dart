/// Select with --dart-define=APP_ENV=development|production.
/// API_BASE_URL may override either environment for staging or a LAN server.
const appEnvironment =
    String.fromEnvironment('APP_ENV', defaultValue: 'production');
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: appEnvironment == 'development'
      ? 'http://10.0.2.2:5000'
      : 'https://kalyanfaultdetection.in',
);

bool get isProduction => appEnvironment == 'production';
