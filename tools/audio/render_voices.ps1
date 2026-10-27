$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$output = Join-Path $root 'apps/le_loup/assets/audio/classic'
New-Item -ItemType Directory -Force -Path $output | Out-Null
# Accès direct à la voix française OneCore, sans modifier le registre Windows.
$token = New-Object -ComObject SAPI.SpObjectToken
$token.SetId('HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Speech_OneCore\Voices\Tokens\MSTTS_V110_frFR_PaulM', '', $false)
$voice = New-Object -ComObject SAPI.SpVoice
$voice.Voice = $token
$voice.Rate = -2
$voice.Volume = 95
$lines = [ordered]@{
  role_reveal = 'Découvrez votre rôle à l''abri des regards.'
  sleep = 'Le village s''endort. Fermez les yeux.'
  seer = 'Voyante, ouvre les yeux. Quelle identité souhaites-tu découvrir ?'
  wolves = 'Loups-garous, réveillez-vous. Quelle sera votre victime ?'
  witch = 'Les loups se rendorment. Sorcière, réveille-toi, et prépare tes potions.'
  dawn = 'Le jour se lève. Le village découvre les événements de la nuit.'
  hunter = 'Chasseur, ton dernier souffle te laisse un dernier tir.'
  day = 'Le village est réveillé. Place au débat.'
  voting = 'Le village vote. Désignez un joueur, ou choisissez le vote blanc.'
  vote_result = 'Le scrutin est terminé. Le village découvre le résultat.'
  ended_village = 'Le village remporte la partie.'
  ended_wolves = 'Les loups-garous remportent la partie.'
  ended_draw = 'Le village est désert. Partie nulle.'
}
foreach ($line in $lines.GetEnumerator()) {
  $stream = New-Object -ComObject SAPI.SpFileStream
  $stream.Open((Join-Path $output ($line.Key + '.wav')), 3, $false)
  $voice.AudioOutputStream = $stream
  try { $voice.Speak('<pitch absmiddle="-3">' + $line.Value + '</pitch>', 8) | Out-Null }
  finally { $stream.Close() }
}
Write-Output ('Voix française : ' + $voice.Voice.GetDescription())
