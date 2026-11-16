"""Подготовить ключ из GitHub Secrets, не выводя его содержимое."""
import base64
import os
from pathlib import Path


def main():
    names = ['DELTA_ANDROID_KEYSTORE_BASE64', 'DELTA_ANDROID_STORE_PASSWORD',
             'DELTA_ANDROID_KEY_ALIAS', 'DELTA_ANDROID_KEY_PASSWORD']
    missing = [name for name in names if not os.environ.get(name)]
    if missing:
        raise SystemExit('Подпись Android не настроена. Добавьте GitHub Secrets: '
                         + ', '.join(missing))
    try:
        data = base64.b64decode(os.environ[names[0]], validate=True)
    except ValueError:
        raise SystemExit('DELTA_ANDROID_KEYSTORE_BASE64: неверный base64') from None
    if not data:
        raise SystemExit('Файл ключа подписи пуст')
    target = Path(os.environ['DELTA_ANDROID_KEYSTORE_PATH'])
    # O_EXCL исключает случайную перезапись существующего файла.
    with os.fdopen(os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), 'wb') as stream:
        stream.write(data)
    print('Постоянный ключ подготовлен; значения секретов не выводятся.')


if __name__ == '__main__':
    main()
