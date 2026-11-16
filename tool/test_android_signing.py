"""Проверки отказов подготовки подписи без создания настоящего ключа."""
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name('prepare_android_signing.py')

class SigningTests(unittest.TestCase):
    def test_missing_secrets(self):
        env = {k:v for k,v in os.environ.items() if not k.startswith('DELTA_ANDROID_')}
        result = subprocess.run([sys.executable,str(SCRIPT)],env=env,capture_output=True,text=True)
        self.assertNotEqual(result.returncode,0)
        self.assertIn('Подпись Android не настроена',result.stderr)
        self.assertNotIn('Traceback',result.stderr)

    def test_invalid_base64(self):
        directory=SCRIPT.parent.parent / '.dart_tool' / 'signing-tests'
        directory.mkdir(parents=True,exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='delta-signing-',dir=directory) as folder:
            target=Path(folder)/'synthetic.jks'
            env={k:v for k,v in os.environ.items() if not k.startswith('DELTA_ANDROID_')}
            env.update({name:'synthetic' for name in [
                'DELTA_ANDROID_STORE_PASSWORD','DELTA_ANDROID_KEY_ALIAS','DELTA_ANDROID_KEY_PASSWORD']})
            env['DELTA_ANDROID_KEYSTORE_BASE64']='!not-base64!'
            env['DELTA_ANDROID_KEYSTORE_PATH']=str(target)
            result=subprocess.run([sys.executable,str(SCRIPT)],env=env,capture_output=True,text=True)
            self.assertNotEqual(result.returncode,0)
            self.assertIn('неверный base64',result.stderr)
            self.assertFalse(target.exists())
            self.assertNotIn('synthetic',result.stderr)

if __name__=='__main__':
    unittest.main()
