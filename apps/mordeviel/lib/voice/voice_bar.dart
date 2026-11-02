import 'package:flutter/material.dart';
import 'game_voice.dart';

class VoiceBar extends StatefulWidget {
  const VoiceBar({super.key, required this.voice, this.onSettings});
  final GameVoice voice;
  final VoidCallback? onSettings;
  @override
  State<VoiceBar> createState() => _VoiceBarState();
}

class _VoiceBarState extends State<VoiceBar> with WidgetsBindingObserver {
  GameVoice get voice => widget.voice;
  VoidCallback? get onSettings => widget.onSettings;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: voice,
    builder: (context, _) {
      if (View.of(context).viewInsets.bottom > 0) {
        if (voice.transmitting || voice.locked) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => voice.pauseMicrophone(),
          );
        }
        return const SizedBox.shrink();
      }
      final label =
          voice.error ??
          (!voice.wanted
              ? 'Vocal facultatif'
              : voice.busy
              ? 'Connexion vocale…'
              : !voice.connected
              ? 'En attente du prochain appel'
              : voice.transmitting
              ? 'Ton micro est ouvert'
              : voice.canSpeak
              ? 'Maintiens pour parler'
              : 'Écoute · micro fermé pour cette phase');
      return Material(
        color: const Color(0xFF17232A),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              IconButton(
                tooltip: voice.wanted
                    ? 'Quitter le vocal'
                    : 'Rejoindre le vocal',
                onPressed: voice.wanted ? voice.leave : voice.join,
                icon: Icon(
                  voice.wanted
                      ? Icons.headset_off_outlined
                      : Icons.headset_mic_outlined,
                  color: voice.connected ? const Color(0xFF79D6B1) : null,
                ),
              ),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: voice.error == null ? null : const Color(0xFFFFB7A5),
                  ),
                ),
              ),
              if (voice.wanted) ...[
                _HoldMicrophone(voice: voice),
                IconButton(
                  tooltip: voice.locked
                      ? 'Déverrouiller et couper le micro'
                      : 'Verrouiller le micro ouvert',
                  onPressed: voice.canSpeak ? voice.toggleLock : null,
                  icon: Icon(
                    voice.locked ? Icons.lock : Icons.lock_open,
                    size: 21,
                  ),
                ),
              ],
              if (onSettings != null)
                IconButton(
                  tooltip: 'Contrôle vocal du MDJ',
                  onPressed: onSettings,
                  icon: const Icon(Icons.tune, size: 21),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _HoldMicrophone extends StatefulWidget {
  const _HoldMicrophone({required this.voice});
  final GameVoice voice;
  @override
  State<_HoldMicrophone> createState() => _HoldMicrophoneState();
}

class _HoldMicrophoneState extends State<_HoldMicrophone> {
  int? _pointer;
  void _release(int id) {
    if (_pointer != id) return;
    _pointer = null;
    widget.voice.hold(false);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.voice.transmitting ? 'Micro ouvert' : 'Maintenir pour parler',
    button: true,
    onTap: widget.voice.canSpeak ? widget.voice.toggleLock : null,
    child: Listener(
      onPointerDown: (event) {
        if (_pointer == null && widget.voice.canSpeak) {
          _pointer = event.pointer;
          widget.voice.hold(true);
        }
      },
      onPointerUp: (event) => _release(event.pointer),
      onPointerCancel: (event) => _release(event.pointer),
      child: Container(
        width: 48,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: widget.voice.transmitting
              ? const Color(0xFFA54D45)
              : widget.voice.canSpeak
              ? const Color(0xFF2E654F)
              : const Color(0xFF303A40),
        ),
        child: Icon(
          widget.voice.transmitting ? Icons.mic : Icons.mic_off,
          color: widget.voice.canSpeak ? Colors.white : Colors.grey,
        ),
      ),
    ),
  );
}
