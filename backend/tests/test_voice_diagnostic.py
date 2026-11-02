import base64
import importlib.util
import io
import json
from pathlib import Path


def load_diagnostic():
    spec = importlib.util.spec_from_file_location(
        'check_voice', Path(__file__).resolve().parents[2] / 'tools/deploy/check_voice.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_diagnostic_reads_participants_with_scoped_grants_without_printing_secrets(tmp_path):
    module = load_diagnostic()
    (tmp_path / '.env').write_text('LIVEKIT_API_KEY=fixture-key\nLIVEKIT_API_SECRET=fixture-secret\n')
    output, requests = [], []

    def opener(request, timeout):
        token = request.headers['Authorization'].split()[1]
        payload = token.split('.')[1]
        grants = json.loads(base64.urlsafe_b64decode(payload + '=' * (-len(payload) % 4)))['video']
        requests.append((request, grants))
        response = ({'rooms': [{'name': 'mw-example-village'}]} if request.full_url.endswith('/ListRooms') else
                    {'participants': [{'identity': 'p1', 'state': 'ACTIVE',
                                       'tracks': [{'type': 'AUDIO'}, {'type': 'VIDEO', 'muted': True}]},
                                      {'identity': 'host', 'state': 'JOINED'}]})
        return io.StringIO(json.dumps(response))

    assert module.check(tmp_path, out=output.append, opener=opener) == 0
    text = '\n'.join(output)
    assert '2 appareil(s)' in text and 'p1 | état=ACTIVE | ouvert' in text
    assert 'host | état=JOINED | aucune piste audio' in text
    assert 'fixture-key' not in text and 'fixture-secret' not in text
    assert requests[0][1] == {'roomList': True}
    assert requests[1][1] == {'roomAdmin': True, 'room': 'mw-example-village'}


def test_diagnostic_keeps_signed_credentials_on_loopback(tmp_path):
    module = load_diagnostic()
    (tmp_path / '.env').write_text('LIVEKIT_API_KEY=key\nLIVEKIT_API_SECRET=secret\n'
                                  'MORDEVIEL_VOICE_API_URL=https://remote.example.test\n')
    output = []

    def opener(*args, **kwargs):
        raise AssertionError('Credentials must stay local.')

    assert module.check(tmp_path, out=output.append, opener=opener) == 1
    assert 'local' in output[0]
