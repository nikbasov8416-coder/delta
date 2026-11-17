/// Публичный идентификатор приложения. Client secret не используется.
const yandexClientId = '9dfd06f99533434999c25fc578b45663';
final yandexAuthorizationUri = Uri.https('oauth.yandex.ru', '/authorize', {
  'response_type': 'token',
  'client_id': yandexClientId,
  'force_confirm': 'yes',
});
