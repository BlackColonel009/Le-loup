/// Commands shared by a device-hosted and a remotely hosted game.
abstract interface class GameHost {
  Map<String, int> get deck;
  Map<String, dynamic> get snapshot;
  Stream<Map<String, dynamic>> get updates;
  Future<void> start({
    int port = 8080,
    String nickname = 'MDJ',
    String? bindAddress,
  });
  Future<List<String>> addresses();
  void configure(
    Map<String, int> deck, {
    required bool campOnly,
    bool? revealOnDeath,
    bool? revealRescuer,
    String? pack,
    List<String>? sentences,
    Map<String, String>? cardStyles,
  });
  void setLocked(bool value);
  void setNarration({required String profile, required bool automatic});
  Future<void> kick(String id);
  void startGame();
  void startNight({int seconds = 120});
  void callNight(String action);
  void advanceNight();
  void finishNight();
  void pauseNight();
  void resumeNight();
  void startVote({int seconds = 120});
  void setDayChat(bool value);
  void spinSentence();
  void continueAfterSentence();
  Future<void> dispose();
}
