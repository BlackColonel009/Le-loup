import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../audio/classic_audio.dart';
import '../challenges/reward_claim_dialog.dart';
import '../social/social_api.dart';
import '../social/social_service.dart';
import 'coin_widgets.dart';

Future<Map<String, dynamic>> loadMatchCoins(String matchId) async {
  for (var attempt = 0; ; attempt++) {
    try {
      return await SocialApi.instance.request('/coins/matches/$matchId');
    } on SocialError catch (error) {
      if (error.status != 404 || attempt >= 3) rethrow;
      await Future<void>.delayed(Duration(milliseconds: 250 * (attempt + 1)));
    }
  }
}

Future<void> showCoinReward(
  BuildContext context,
  Map<String, dynamic> receipt,
) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierLabel: 'Coffre de Lunes d’or',
  pageBuilder: (_, _, _) => CoinRewardScene(receipt: receipt),
);

class ShakingChest extends StatefulWidget {
  const ShakingChest({super.key, this.size = 40});
  final double size;
  @override
  State<ShakingChest> createState() => _ShakingChestState();
}

class _ShakingChestState extends State<ShakingChest>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
    } else {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.size,
    height: widget.size,
    child: AnimatedBuilder(
      animation: _motion,
      builder: (_, _) => RewardChestIllustration(
        motion: _motion.value,
        reduced: MediaQuery.disableAnimationsOf(context),
      ),
    ),
  );
}

class CoinRewardScene extends StatefulWidget {
  const CoinRewardScene({
    super.key,
    required this.receipt,
    this.videoEnabled = true,
  });
  final Map<String, dynamic> receipt;
  final bool videoEnabled;
  @override
  State<CoinRewardScene> createState() => _CoinRewardSceneState();
}

class _CoinRewardSceneState extends State<CoinRewardScene>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final _opening = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  late final _fallbackClock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  );
  VideoPlayerController? _video;
  Timer? _watchdog;
  List<int> _impacts = [for (var i = 1; i <= 40; i++) i * 200];
  bool _done = false,
      _opened = false,
      _fallback = false,
      _loading = true,
      _paused = false;
  int _count = 0, _still = 0, _position = 0;
  String? _error;
  int get _amount => widget.receipt['amount'] as int;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fallbackClock.addListener(
      () => _update((_fallbackClock.value * 10000).round()),
    );
    _fallbackClock.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_open());
    });
  }

  Future<void> _open() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final receipt = await SocialApi.instance.request(
        '/coins/matches/${widget.receipt['match_id']}/claim',
        method: 'POST',
      );
      SocialService.instance.updateCoinBalance(
        receipt['balance'] as int,
        forUser: receipt['user_id'] as int,
      );
      if (!mounted || _done) return;
      setState(() => _loading = false);
      try {
        final data =
            jsonDecode(
                  await rootBundle.loadString(
                    'assets/rewards/coin_impacts.json',
                  ),
                )
                as Map;
        _impacts = (data['impact_ms'] as List).cast<int>();
      } catch (_) {}
      if (!mounted || _done) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _finish();
        return;
      }
      await _opening.forward().orCancel;
      if (!mounted || _done) return;
      setState(() => _opened = true);
      if (!widget.videoEnabled) {
        _useFallback();
        return;
      }
      final video = VideoPlayerController.asset(
        'assets/rewards/coin_rain.mp4',
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _video = video;
      video.addListener(_videoChanged);
      try {
        await video.initialize().timeout(const Duration(seconds: 6));
        if (!mounted || _done) return;
        await video.setLooping(false);
        final audio = ClassicAudio.instance;
        await video.setVolume(audio.muted ? 0 : audio.effectLevel * .85);
        if (!mounted || _done) return;
        setState(() {});
        if (!_paused) await video.play();
        _watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
          if (_paused || _done) return;
          final next = video.value.position.inMilliseconds;
          _still = next == _position ? _still + 1 : 0;
          _position = next;
          if (_still >= 7) _useFallback();
        });
      } catch (_) {
        _useFallback();
      }
    } catch (error) {
      if (mounted && !_done) {
        setState(() {
          _loading = false;
          _error = error is SocialError
              ? error.message
              : 'Le coffre ne répond pas. Tes gains restent enregistrés.';
        });
      }
    }
  }

  void _update(int ms) {
    if (!mounted || _done) return;
    final value = coinsAtImpact(_amount, ms, _impacts);
    if (value != _count) setState(() => _count = value);
  }

  void _videoChanged() {
    final value = _video?.value;
    if (value == null || !mounted || _done || _fallback) return;
    if (value.hasError) {
      _useFallback();
      return;
    }
    _update(value.position.inMilliseconds);
    if (value.isInitialized &&
        value.duration > Duration.zero &&
        value.position >= value.duration) {
      _finish();
    }
  }

  void _useFallback() {
    if (!mounted || _done || _fallback) return;
    _watchdog?.cancel();
    unawaited(
      _video?.pause().catchError((Object _) {}) ?? Future<void>.value(),
    );
    setState(() => _fallback = true);
    _fallbackClock.value = (_position / 10000).clamp(0, 1);
    if (!_paused) _fallbackClock.forward();
  }

  void _finish() {
    if (!mounted || _done) return;
    _watchdog?.cancel();
    _fallbackClock.stop();
    unawaited(
      _video?.pause().catchError((Object _) {}) ?? Future<void>.value(),
    );
    setState(() {
      _done = true;
      _count = _amount;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
    final video = _video;
    if (_paused) {
      _fallbackClock.stop();
      unawaited(
        video?.pause().catchError((Object _) {}) ?? Future<void>.value(),
      );
    } else if (!_done && _opened) {
      if (_fallback) {
        _fallbackClock.forward();
      } else if (video?.value.isInitialized == true) {
        unawaited(video!.play().catchError((Object _) {}));
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watchdog?.cancel();
    _video?.removeListener(_videoChanged);
    unawaited(
      _video?.dispose().catchError((Object _) {}) ?? Future<void>.value(),
    );
    _opening.dispose();
    _fallbackClock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _done || _error != null,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _finish();
    },
    child: Scaffold(
      backgroundColor: const Color(0xFF080C10),
      body: SafeArea(
        child: Stack(
          children: [
            if (_opened &&
                !_done &&
                !_fallback &&
                _video?.value.isInitialized == true)
              Positioned.fill(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _video!.value.aspectRatio,
                    child: VideoPlayer(_video!),
                  ),
                ),
              ),
            if (_done)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        coinGold.withValues(alpha: .2),
                        const Color(0xFF080C10),
                      ],
                      radius: .85,
                    ),
                  ),
                ),
              ),
            if (!_done)
              Align(
                alignment: Alignment.topRight,
                child: TextButton.icon(
                  onPressed: _done ? null : _finish,
                  icon: const Icon(Icons.skip_next, color: coinGold),
                  label: const Text(
                    'Passer',
                    style: TextStyle(color: coinGold),
                  ),
                ),
              ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_done) ...[
                      const CoinToken(size: 112),
                      const SizedBox(height: 26),
                      Text(
                        widget.receipt['participant_role'] == 'mdj'
                            ? 'Récompense du MDJ'
                            : 'Vous avez gagné',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                    ] else if (!_opened ||
                        _fallback ||
                        _video?.value.isInitialized != true) ...[
                      SizedBox(
                        height: 170,
                        width: 240,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([
                            _opening,
                            _fallbackClock,
                          ]),
                          builder: (_, _) => RewardChestIllustration(
                            motion: _fallback
                                ? _fallbackClock.value
                                : _opening.value,
                            opening: ((_opening.value - .3) / .7).clamp(
                              0.0,
                              1.0,
                            ),
                            tier: RewardChestTier.classic,
                          ),
                        ),
                      ),
                      if (_loading) const Text('Ton trésor se prépare…'),
                    ],
                    if (_opened && !_done && !_fallback)
                      SizedBox(height: MediaQuery.sizeOf(context).height * .43),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .76),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: coinGold.withValues(alpha: .45),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CoinToken(size: 38),
                          const SizedBox(width: 12),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 100),
                            child: Text(
                              '+$_count',
                              key: ValueKey(_count),
                              style: const TextStyle(
                                color: coinGold,
                                fontSize: 38,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      coinName,
                      style: TextStyle(color: coinGold, fontSize: 18),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      TextButton(
                        onPressed: _open,
                        child: const Text('Réessayer'),
                      ),
                    ],
                    if (_done) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Ajoutées à ta bourse. Retrouve les offres du jour dans la boutique !',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (widget.receipt['participant_role'] == 'mdj') ...[
                        Text(
                          '${widget.receipt['nights']} nuit(s) guidée(s) · indépendant du camp gagnant',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                      ],
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Continuer'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
