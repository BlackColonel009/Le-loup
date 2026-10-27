$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$catalog = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'voice_profiles.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$voice = New-Object -ComObject SAPI.SpVoice
$voice.Volume = 95
foreach ($profile in $catalog.profiles) {
  $token = New-Object -ComObject SAPI.SpObjectToken
  $token.SetId(('HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Speech_OneCore\Voices\Tokens\MSTTS_V110_frFR_' + $profile.voice + 'M'), '', $false)
  $voice.Voice = $token
  $voice.Rate = $profile.rate
  $output = Join-Path $root ('.tools/audio/voices_raw/' + $profile.id)
  New-Item -ItemType Directory -Force -Path $output | Out-Null
  foreach ($line in $catalog.lines.($profile.edition).PSObject.Properties) {
    $stream = New-Object -ComObject SAPI.SpFileStream
    $stream.Open((Join-Path $output ($line.Name + '.wav')), 3, $false)
    $voice.AudioOutputStream = $stream
    $xml = '<pitch absmiddle="' + $profile.pitch + '">' + [System.Security.SecurityElement]::Escape($line.Value) + '</pitch>'
    try { $voice.Speak($xml, 8) | Out-Null } finally { $stream.Close() }
  }
  Write-Output ('Profil rendu : ' + $profile.id + ' / ' + $voice.Voice.GetDescription())
}
