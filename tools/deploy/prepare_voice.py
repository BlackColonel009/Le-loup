"""Prepare self-hosted voice keys/config without displaying any secret."""
import json
import os
import secrets
from pathlib import Path
from urllib.parse import urlparse

from dotenv import dotenv_values


def prepare(backend, domain=None):
    env = backend / '.env'
    env_existed = env.exists()
    values = dotenv_values(env) if env_existed else {}
    public = urlparse(values.get('MORDEVIEL_PUBLIC_URL') or 'https://mordeviel.newtechnologiestg.com')
    domain = domain or public.hostname
    if not domain or not all(c.isalnum() or c in '.-' for c in domain):
        raise ValueError('Domaine public invalide.')
    defaults = {
        'MORDEVIEL_VOICE_URL': f'wss://{domain}',
        'MORDEVIEL_VOICE_API_URL': 'http://127.0.0.1:7880',
        'LIVEKIT_API_KEY': 'MW' + secrets.token_hex(10),
        'LIVEKIT_API_SECRET': secrets.token_urlsafe(48),
    }
    updates = {key: value for key, value in defaults.items() if not values.get(key)}
    values.update(updates)
    if len(values['LIVEKIT_API_SECRET']) < 32:
        raise ValueError('LIVEKIT_API_SECRET doit contenir au moins 32 caractères.')
    backend.mkdir(parents=True, exist_ok=True)
    if updates:
        with env.open('a', encoding='utf-8') as out:
            out.write('\n# Vocal Mordeviel — secrets privés\n')
            for key, value in updates.items():
                out.write(f'{key}={json.dumps(value)}\n')
    config = backend / 'data/livekit/livekit.yaml'
    config.parent.mkdir(parents=True, exist_ok=True)
    config.write_text(f'''port: 7880
bind_addresses: ["127.0.0.1"]
rtc:
  tcp_port: 7881
  port_range_start: 50000
  port_range_end: 50199
  use_external_ip: true
room:
  auto_create: false
  empty_timeout: 60
  departure_timeout: 10
keys:
  {json.dumps(values['LIVEKIT_API_KEY'])}: {json.dumps(values['LIVEKIT_API_SECRET'])}
turn:
  enabled: true
  domain: {json.dumps(domain)}
  udp_port: 3478
  tls_port: 5349
  cert_file: "/etc/letsencrypt/live/{domain}/fullchain.pem"
  key_file: "/etc/letsencrypt/live/{domain}/privkey.pem"
logging:
  level: warn
''', encoding='utf-8')
    if os.name != 'nt':
        # Existing permissions may grant the systemd service access to a root-owned file.
        if not env_existed:
            os.chmod(env, 0o600)
        os.chmod(config, 0o600)
    return config


if __name__ == '__main__':
    prepare(Path(__file__).resolve().parents[2] / 'backend')
    print('Configuration vocale préparée. Secrets conservés dans backend/.env et backend/data/livekit/.')
