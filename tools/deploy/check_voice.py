"""Read local LiveKit room/track state without displaying credentials or tokens."""
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from dotenv import dotenv_values
from mordeviel_api.voice import signed_token


def check(backend, out=print, opener=urllib.request.urlopen):
    values = dotenv_values(backend / '.env')
    key, secret = values.get('LIVEKIT_API_KEY'), values.get('LIVEKIT_API_SECRET')
    if not key or not secret:
        out('Configuration vocale incomplète dans backend/.env.')
        return 1
    base = (values.get('MORDEVIEL_VOICE_API_URL') or 'http://127.0.0.1:7880').rstrip('/')
    url = urllib.parse.urlparse(base)
    if (url.hostname not in {'127.0.0.1', 'localhost', '::1'} or
            url.scheme not in {'http', 'https'} or url.username or url.password or url.query or url.fragment):
        out('Ce contrôle est réservé au service LiveKit local de ce serveur.')
        return 1

    def rpc(method, data, grants):
        request = urllib.request.Request(
            f'{base}/twirp/livekit.RoomService/{method}',
            data=json.dumps(data).encode(),
            headers={'Content-Type': 'application/json', 'Authorization': 'Bearer ' +
                     signed_token(key, secret, grants, 'voice-diagnostic', ttl=30)}, method='POST')
        with opener(request, timeout=5) as response:
            return json.load(response)

    try:
        rooms = rpc('ListRooms', {}, {'roomList': True}).get('rooms', [])
        out(f'Canaux LiveKit : {len(rooms)}')
        for room in rooms:
            name = room['name']
            participants = rpc('ListParticipants', {'room': name},
                               {'roomAdmin': True, 'room': name}).get('participants', [])
            out(f'Canal {name} : {len(participants)} appareil(s)')
            for participant in participants:
                tracks = [t for t in participant.get('tracks', []) if t.get('type', 0) in (0, 'AUDIO')]
                state = participant.get('state', 'JOINING')
                microphone = ', '.join('coupé' if t.get('muted') else 'ouvert' for t in tracks) or 'aucune piste audio'
                out(f"  {participant.get('identity', '?')} | état={state} | {microphone}")
        if not rooms:
            out('Aucun canal : garder les deux applications ouvertes et rejoindre le vocal avant ce contrôle.')
        out('Une piste publiée ne confirme pas à elle seule la réception des paquets audio.')
        return 0
    except urllib.error.HTTPError as error:
        out(f'Contrôle LiveKit refusé ou indisponible (HTTP {error.code}).')
    except (OSError, ValueError, KeyError):
        out('Impossible de lire l’état du service LiveKit local.')
    return 1


if __name__ == '__main__':
    sys.exit(check(Path(__file__).resolve().parents[2] / 'backend'))
