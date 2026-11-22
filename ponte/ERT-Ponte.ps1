<#
  ERT-Ponte - collega l'addon ERT (Ethereum Raid Tools) al bot Discord della gilda.

  Cosa fa, da solo:
   - quando WoW e' aperto, ogni 3 minuti chiede al bot i raid in programma e le righe dei raid
     di cui sei referente, e le scrive in Interface\AddOns\ERT\ERT_Dati.lua (in gioco: /reload);
   - quando in gioco chiudi un appello e fai /reload (o esci), legge i risultati salvati da ERT
     (WTF\Account\*\SavedVariables\ERT.lua) e li manda al bot, che segna le persone al raid;
   - installa l'addon ERT se manca e lo tiene aggiornato;
   - ricettari: quando Mastercraft salva (/reload o uscita dal gioco), manda al bot le ricette dei tuoi
     personaggi (solo ricette e livello di professione, niente oro o borse) e i ricettari sul sito si aggiornano.
     Un alt diventa un ricettario nuovo; le richieste di craft arrivano sempre a te su Discord.

  Non tocca nient'altro: legge solo ERT.lua e Mastercraft.lua nelle SavedVariables e scrive solo nella cartella dell'addon ERT.
  File: %LOCALAPPDATA%\ERT-Ponte (config.json = la tua chiave personale, ponte.log = cosa ha fatto).
  Per toglierlo: Disinstalla.cmd nella stessa cartella.
#>
param([switch]$Installa, [switch]$Disinstalla, [switch]$Una, [switch]$Collega, [switch]$DaExe, [switch]$Elenco)

$VERSIONE = '1.4'
$BOT_BASE = 'https://professioniethereum.michael-cerri90.workers.dev'
$SITO_BASE = 'https://michaelcerri90-sudo.github.io/PROFESSIONI-Ethereum-'
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Qui = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script = $MyInvocation.MyCommand.Path
$CfgFile = Join-Path $Qui 'config.json'
$StatoFile = Join-Path $Qui 'stato.json'
$LogFile = Join-Path $Qui 'ponte.log'
$SceltaFile = Join-Path $Qui 'scelta.json'   # quali ricettari mandare: { "Pg|Professione": true/false } (lo scrive ERT-Ponte.exe)
$Avvio = Join-Path ([Environment]::GetFolderPath('Startup')) 'ERT-Ponte.lnk'
$Interattivo = $Installa -or $Disinstalla -or $Una -or $Collega

function Log([string]$t) {
  try {
    if ((Test-Path -LiteralPath $LogFile) -and (Get-Item -LiteralPath $LogFile).Length -gt 1MB) {
      Move-Item -LiteralPath $LogFile -Destination ($LogFile + '.vecchio') -Force
    }
    Add-Content -LiteralPath $LogFile -Value ('{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $t) -Encoding UTF8
  } catch {}
  if ($Interattivo) { Write-Host $t }
}

function LeggiJson([string]$file, $vuoto) {
  if (Test-Path -LiteralPath $file) {
    try { return (Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json) } catch {}
  }
  return $vuoto
}
function ScriviJson([string]$file, $dati) {
  [IO.File]::WriteAllText($file, ($dati | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($false)))
}

function Config { LeggiJson $CfgFile $null }
function Stato {
  $s = LeggiJson $StatoFile $null
  if (-not $s) { $s = [pscustomobject]@{} }
  foreach ($k in 'inviati', 'datiHash', 'zipHash', 'zipControllo', 'psControllo', 'wow', 'mcTempo', 'mcHash') {
    if (-not ($s.PSObject.Properties.Name -contains $k)) { $s | Add-Member -NotePropertyName $k -NotePropertyValue $null }
  }
  if (-not $s.inviati) { $s.inviati = @() }
  return $s
}

# ------------------------------------------------------------------ dov'e' WoW
function CartellaGioco([string]$c) {
  # $c = cartella "World of Warcraft" oppure gia' la cartella del client (_forever_)
  if (-not (Test-Path -LiteralPath $c)) { return $null }
  if (Test-Path -LiteralPath (Join-Path $c 'Interface\AddOns\ERT\ERT.toc')) { return $c }
  $f = Join-Path $c '_forever_'
  if (Test-Path -LiteralPath (Join-Path $f 'Interface\AddOns\ERT\ERT.toc')) { return $f }
  if (Test-Path -LiteralPath (Join-Path $f 'WTF')) { return $f }
  if ((Test-Path -LiteralPath (Join-Path $c 'WTF')) -and (Split-Path $c -Leaf) -eq '_forever_') { return $c }
  return $null
}
function TrovaWow {
  $cand = New-Object System.Collections.Generic.List[string]
  foreach ($k in 'HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft', 'HKLM:\SOFTWARE\Blizzard Entertainment\World of Warcraft') {
    try {
      $p = [string](Get-ItemProperty -LiteralPath $k -ErrorAction Stop).InstallPath
      if ($p) { $p = $p.TrimEnd('\'); $cand.Add($p); $cand.Add((Split-Path $p -Parent)) }
    } catch {}
  }
  foreach ($d in [IO.DriveInfo]::GetDrives()) {
    if ($d.DriveType -ne 'Fixed' -or -not $d.IsReady) { continue }
    foreach ($s in 'World of Warcraft', 'Program Files (x86)\World of Warcraft', 'Program Files\World of Warcraft', 'Games\World of Warcraft',
                   'Giochi\World of Warcraft', 'Blizzard\World of Warcraft', 'Battle.net\World of Warcraft', 'Program Files (x86)\Battle.net\World of Warcraft') {
      $cand.Add((Join-Path $d.RootDirectory.FullName $s))
    }
  }
  foreach ($c in $cand) { $g = CartellaGioco $c; if ($g) { return $g } }
  return $null
}
function ChiediWow {
  Add-Type -AssemblyName System.Windows.Forms
  $d = New-Object System.Windows.Forms.FolderBrowserDialog
  $d.Description = "Non trovo World of Warcraft. Scegli la cartella _forever_ del gioco (dentro World of Warcraft)."
  $d.ShowNewFolderButton = $false
  while ($d.ShowDialog() -eq 'OK') {
    $g = CartellaGioco $d.SelectedPath
    if ($g) { return $g }
    [System.Windows.Forms.MessageBox]::Show("In quella cartella non c'e' WoW: scegli la cartella _forever_ (quella con dentro WTF e Interface).", 'ERT-Ponte') | Out-Null
  }
  return $null
}
function Wow($stato) {
  if ($stato.wow -and (CartellaGioco $stato.wow)) { return (CartellaGioco $stato.wow) }
  $g = TrovaWow
  if (-not $g -and $Installa) { $g = ChiediWow }
  if ($g) { $stato.wow = $g }
  return $g
}
function WowAperto {
  return [bool](Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Wow*' })
}

# ------------------------------------------------------------------ bot
function Bot($cfg, [string]$percorso, $corpo) {
  $h = @{ Authorization = 'Ponte ' + $cfg.token; 'User-Agent' = 'ERT-Ponte/' + $VERSIONE }
  $url = $cfg.bot + $percorso
  if ($null -eq $corpo) { return Invoke-RestMethod -Uri $url -Headers $h -TimeoutSec 30 -UseBasicParsing }
  $b = [Text.Encoding]::UTF8.GetBytes(($corpo | ConvertTo-Json -Depth 5 -Compress))
  return Invoke-RestMethod -Uri $url -Method Post -Headers $h -Body $b -ContentType 'application/json; charset=utf-8' -TimeoutSec 30 -UseBasicParsing
}

# ------------------------------------------------------------------ addon ERT
function Hash([byte[]]$b) {
  $sha = [Security.Cryptography.SHA256]::Create()
  return ([BitConverter]::ToString($sha.ComputeHash($b)) -replace '-', '').Substring(0, 16)
}
# scarica ERT.zip dal sito e lo installa se e' cambiato (o se l'addon manca). Non tocca ERT_Dati.lua.
function AggiornaAddon($cfg, $stato, $wow, [switch]$Forza) {
  $dest = Join-Path $wow 'Interface\AddOns\ERT'
  $manca = -not (Test-Path -LiteralPath (Join-Path $dest 'ERT.toc'))
  $tmp = Join-Path ([IO.Path]::GetTempPath()) ('ERT-Ponte-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $tmp | Out-Null
  try {
    $zip = Join-Path $tmp 'ERT.zip'
    Invoke-WebRequest -Uri ($cfg.sito + '/addon/ERT.zip') -OutFile $zip -UseBasicParsing -TimeoutSec 60
    $h = Hash ([IO.File]::ReadAllBytes($zip))
    if (-not $manca -and -not $Forza -and $h -eq $stato.zipHash) { return 'uguale' }
    $estr = Join-Path $tmp 'x'
    Expand-Archive -LiteralPath $zip -DestinationPath $estr -Force
    $src = Join-Path $estr 'ERT'
    if (-not (Test-Path -LiteralPath (Join-Path $src 'ERT.toc'))) { throw 'ERT.zip non valido' }
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    foreach ($f in Get-ChildItem -LiteralPath $src -Recurse -File) {
      $rel = $f.FullName.Substring($src.Length).TrimStart('\')
      if ($rel -eq 'ERT_Dati.lua' -and (Test-Path -LiteralPath (Join-Path $dest $rel))) { continue }
      $to = Join-Path $dest $rel
      New-Item -ItemType Directory -Path (Split-Path $to -Parent) -Force | Out-Null
      Copy-Item -LiteralPath $f.FullName -Destination $to -Force
    }
    $stato.zipHash = $h
    $stato.datiHash = $null # riscrive ERT_Dati.lua al prossimo giro
    if ($manca) { return 'installato' } else { return 'aggiornato' }
  } finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }
}

# ------------------------------------------------------------------ dati per l'addon (ERT_Dati.lua)
function LuaStr($s) {
  $t = [string]$s
  $t = $t -replace '\\', '\\' -replace '"', '\"' -replace "`r", '' -replace "`n", '\n'
  return '"' + $t + '"'
}
function LuaNum($n) { return [string][int64]$n }
function TestoDati($d, $stato) {
  $l = New-Object System.Collections.Generic.List[string]
  $l.Add('  chi = ' + (LuaStr $d.nome) + ',')
  $l.Add('  righe = {')
  foreach ($r in @($d.righe)) { if ($r) { $l.Add('    ' + (LuaStr $r) + ',') } }
  $l.Add('  },')
  $l.Add('  eventi = {')
  foreach ($e in @($d.eventi)) {
    if (-not $e) { continue }
    $raids = @($e.raids | ForEach-Object { '{ k = ' + (LuaStr $_.k) + ', nome = ' + (LuaStr $_.nome) + ', ts = ' + (LuaNum $_.ts) + ' }' })
    $l.Add('    { id = ' + (LuaStr $e.id) + ', raids = { ' + ($raids -join ', ') + ' } },')
  }
  $l.Add('  },')
  $l.Add('  inviati = { ' + ((@($stato.inviati) | ForEach-Object { LuaStr $_ }) -join ', ') + ' },')
  $l.Add('  annullati = { ' + ((@($d.annullati) | Where-Object { $_ } | ForEach-Object { LuaStr $_ }) -join ', ') + ' },')
  return ($l -join "`n")
}
function ScriviDati($cfg, $stato, $wow) {
  $d = Bot $cfg '/ponte/dati' $null
  $corpo = TestoDati $d $stato
  $h = Hash ([Text.Encoding]::UTF8.GetBytes($corpo))
  $file = Join-Path $wow 'Interface\AddOns\ERT\ERT_Dati.lua'
  if ($h -eq $stato.datiHash -and (Test-Path -LiteralPath $file)) { return $d }
  $testo = "-- Scritto da ERT-Ponte $VERSIONE il $(Get-Date -Format 'dd/MM/yyyy HH:mm'): non modificarlo, viene riscritto da solo.`n" +
           "ERT_Ponte = {`n  aggiornato = $([int64]$d.ora),`n$corpo`n}`n"
  New-Item -ItemType Directory -Path (Split-Path $file -Parent) -Force | Out-Null
  [IO.File]::WriteAllText($file, $testo, (New-Object Text.UTF8Encoding($false)))
  $stato.datiHash = $h
  Log ("dati per ERT aggiornati: {0} raid in programma, {1} da referente" -f @($d.eventi).Count, @($d.righe).Count)
  return $d
}

# ------------------------------------------------------------------ appelli fatti in gioco -> Discord
function AppelliDaMandare($stato, $wow) {
  $out = New-Object System.Collections.Generic.List[string]
  $acc = Join-Path $wow 'WTF\Account'
  if (-not (Test-Path -LiteralPath $acc)) { return $out }
  foreach ($sv in Get-ChildItem -LiteralPath $acc -Directory | ForEach-Object { Join-Path $_.FullName 'SavedVariables\ERT.lua' }) {
    if (-not (Test-Path -LiteralPath $sv)) { continue }
    $t = [IO.File]::ReadAllText($sv)
    foreach ($m in [regex]::Matches($t, '"(RC1\|[^"\\\r\n]*)"')) {
      $riga = $m.Groups[1].Value
      $req = $riga.Split('|')[1]
      if ($req -and -not (@($stato.inviati) -contains $req) -and -not $out.Contains($riga)) { $out.Add($riga) }
    }
  }
  return $out
}
function MandaAppelli($cfg, $stato, $wow) {
  $righe = AppelliDaMandare $stato $wow
  if ($righe.Count -eq 0) { return $false }
  $r = Bot $cfg '/ponte/presenze' @{ righe = @($righe) }
  $nuovi = $false
  foreach ($p in $r.esiti.PSObject.Properties) {
    Log ("appello {0}: {1}" -f $p.Name, $p.Value)
    $stato.inviati = @(@($stato.inviati) + $p.Name | Select-Object -Last 60)
    $nuovi = $true
  }
  return $nuovi
}

# ------------------------------------------------------------------ ricettari da Mastercraft.lua
# Del file (che puo' essere di vari MB) servono solo le tabelle "recipes" e "chars": le ritaglio e le leggo qui.
$RACCOLTA = @('Herbalism', 'Skinning', 'Fishing', 'Mining', 'First Aid')
function Ritaglia([string]$t, [string]$chiave) {
  $m = [regex]::Match($t, '(?m)^\["' + $chiave + '"\] = \{')
  if (-not $m.Success) { return $null }
  $re = [regex]'\G\{(?>"(?:\\.|[^"\\])*"|[^{}"]+|\{(?<d>)|\}(?<-d>))*(?(d)(?!))\}'
  $b = $re.Match($t, $m.Index + $m.Length - 1)
  if ($b.Success) { return $b.Value } else { return $null }
}
function LuaUnesc([string]$s) {
  if ($s.IndexOf('\') -lt 0) { return $s }
  return [regex]::Replace($s, '\\(\d{1,3}|.)', { param($m) $c = $m.Groups[1].Value
    if ($c -match '^\d+$') { [string][char][int]$c } elseif ($c -eq 'n') { "`n" } elseif ($c -eq 't') { "`t" } else { $c } })
}
function LuaLeggi([string]$s) {
  $script:lt = @(foreach ($m in [regex]::Matches($s, '"(?:\\.|[^"\\])*"|--[^\n]*|[{}\[\]=,;]|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|[A-Za-z_]\w*')) { if (-not $m.Value.StartsWith('--')) { $m.Value } })
  $script:lk = 0
  return (LuaValore)
}
function LuaValore {
  $t = $script:lt[$script:lk]; $script:lk++
  if ($t -eq '{') { return (LuaTabella) }
  if ($t[0] -eq '"') { return (LuaUnesc $t.Substring(1, $t.Length - 2)) }
  if ($t -eq 'true') { return $true }
  if ($t -eq 'false') { return $false }
  if ($t -eq 'nil') { return $null }
  return [double]::Parse($t, [Globalization.CultureInfo]::InvariantCulture)
}
function LuaTabella {
  $h = @{}; $pos = 1
  while ($script:lk -lt $script:lt.Count) {
    $t = $script:lt[$script:lk]
    if ($t -eq '}') { $script:lk++; return $h }
    if ($t -eq ',' -or $t -eq ';') { $script:lk++; continue }
    if ($t -eq '[') { $script:lk++; $k = LuaValore; $script:lk += 2; $h[$k] = (LuaValore); continue }
    if ($script:lt[$script:lk + 1] -eq '=' -and $t -match '^[A-Za-z_]') { $script:lk += 2; $h[$t] = (LuaValore); continue }
    $h[[double]$pos] = (LuaValore); $pos++
  }
  return $h
}
function Valori($t) {
  if (-not ($t -is [hashtable])) { return @() }
  return @($t.Keys | Sort-Object { [double]$_ } | ForEach-Object { $t[$_] } | Where-Object { $_ -ne $null })
}
function Num($h, [string]$k) { if ($h -is [hashtable] -and $h.ContainsKey($k) -and $h[$k] -ne $null) { return $h[$k] } return $null }
# dal file alle voci da mandare: una per personaggio e professione di artigianato (come la pagina "crea" del sito)
function RicettariDa([string]$file) {
  $t = [IO.File]::ReadAllText($file)
  $rt = Ritaglia $t 'recipes'
  if (-not $rt) { return @() }
  $ricette = LuaLeggi $rt
  $ct = Ritaglia $t 'chars'
  $chars = if ($ct) { LuaLeggi $ct } else { @{} }
  $out = New-Object System.Collections.Generic.List[object]
  foreach ($guid in $ricette.Keys) {
    $ch = $chars[$guid]
    $nome = if ($ch -is [hashtable] -and $ch['name']) { [string]$ch['name'] } else { $null }
    if (-not $nome) { continue }
    $profs = $ricette[$guid]
    if (-not ($profs -is [hashtable])) { continue }
    foreach ($prof in $profs.Keys) {
      if ($RACCOLTA -contains $prof) { continue }
      $v = $profs[$prof]
      $lista = Valori $v['list']
      if ($lista.Count -eq 0) { continue }
      $livello = ''
      foreach ($p in (Valori $ch['professions'])) { if ($p['name'] -eq $prof) { $livello = '{0}/{1}' -f [int]$p['skill'], [int]$p['max'] } }
      $rs = @(foreach ($r in $lista) {
        $cat = if ($r['category']) { $r['category'] } elseif ($r['group']) { $r['group'] } else { 'Ricette' }
        $q = Num $r 'outputQty'; if (-not $q) { $q = 1 }
        @{ name = [string]$r['name']; cat = [string]$cat; known = ($r['learned'] -ne $false); diff = [string]$r['diff']; qty = [int]$q
           reag = @(foreach ($g in (Valori $r['reagents'])) { $gq = Num $g 'qty'; if (-not $gq) { $gq = 1 }; @{ id = [int]$g['itemID']; q = [int]$gq } }) }
      })
      $sc = Num $v 'scanned'; if (-not $sc) { $sc = 0 }
      $out.Add(@{ pg = $nome; prof = [string]$prof; livello = $livello; scanned = [int64]$sc; recipes = $rs })
    }
  }
  return $out.ToArray()
}
function FileMastercraft($wow) {
  $acc = Join-Path $wow 'WTF\Account'
  if (-not (Test-Path -LiteralPath $acc)) { return @() }
  return @(Get-ChildItem -LiteralPath $acc -Directory | ForEach-Object { Join-Path $_.FullName 'SavedVariables\Mastercraft.lua' } | Where-Object { Test-Path -LiteralPath $_ })
}
# scelta fatta nell'app: senza scelta si mandano tutti; con la scelta solo quelli spuntati (i nuovi aspettano la spunta)
function Scelta { LeggiJson $SceltaFile $null }
function Scelto($scelta, $r) {
  if (-not $scelta) { return $true }
  $p = $scelta.PSObject.Properties[$r.pg + '|' + $r.prof]
  return [bool]($p -and $p.Value -eq $true)
}
function Nuovo($scelta, $r) { return [bool]($scelta -and -not $scelta.PSObject.Properties[$r.pg + '|' + $r.prof]) }
# per l'app: elenco dei ricettari trovati in Mastercraft.lua (scritto in elenco.json)
function ScriviElenco {
  $stato = Stato
  $wow = Wow $stato
  $scelta = Scelta
  $lista = @()
  if ($wow) {
    $lista = @(foreach ($f in (FileMastercraft $wow)) { foreach ($r in (RicettariDa $f)) {
      [pscustomobject]@{ pg = $r.pg; prof = $r.prof; livello = $r.livello; noti = @($r.recipes | Where-Object { $_.known }).Count
                         scelto = (Scelto $scelta $r); nuovo = (Nuovo $scelta $r) } } })
  }
  $out = [pscustomobject]@{ wow = $wow; scelta = [bool]$scelta; ricettari = $lista }
  [IO.File]::WriteAllText((Join-Path $Qui 'elenco.json'), ($out | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding($false)))
}
# quando Mastercraft.lua cambia (dopo /reload o all'uscita) o cambia la scelta nell'app, manda i ricettari al bot
function MandaRicettari($cfg, $stato, $wow, [switch]$Forza) {
  if ($cfg.ricettari -eq $false) { return $null }
  $files = FileMastercraft $wow
  if ($files.Count -eq 0) { return $null }
  $tempo = [string]($files | ForEach-Object { (Get-Item -LiteralPath $_).LastWriteTimeUtc.Ticks } | Measure-Object -Maximum).Maximum
  if (Test-Path -LiteralPath $SceltaFile) { $tempo += '|' + (Get-Item -LiteralPath $SceltaFile).LastWriteTimeUtc.Ticks }
  if (-not $Forza -and $tempo -eq [string]$stato.mcTempo) { return $null }
  $scelta = Scelta
  $trovati = @(foreach ($f in $files) { RicettariDa $f })
  $tutti = @($trovati | Where-Object { Scelto $scelta $_ })
  $nuovi = @($trovati | Where-Object { Nuovo $scelta $_ } | ForEach-Object { '{0} {1}' -f $_.pg, $_.prof })
  if ($nuovi.Count) { Log ("ricettari nuovi non ancora scelti (spuntali in ERT-Ponte): {0}" -f ($nuovi -join ', ')) }
  if ($tutti.Count -eq 0) {
    $stato.mcTempo = $tempo
    Log 'ricettari: nessuno scelto'
    return [pscustomobject]@{ esiti = @() }
  }
  $corpo = @{ ricettari = $tutti }
  $json = $corpo | ConvertTo-Json -Depth 8 -Compress
  $h = Hash ([Text.Encoding]::UTF8.GetBytes($json))
  if (-not $Forza -and $h -eq $stato.mcHash) { $stato.mcTempo = $tempo; return $null }
  $risp = Invoke-RestMethod -Uri ($cfg.bot + '/ponte/ricettari') -Method Post -Headers @{ Authorization = 'Ponte ' + $cfg.token; 'User-Agent' = 'ERT-Ponte/' + $VERSIONE } `
    -Body ([Text.Encoding]::UTF8.GetBytes($json)) -ContentType 'application/json; charset=utf-8' -TimeoutSec 60 -UseBasicParsing
  $stato.mcTempo = $tempo; $stato.mcHash = $h
  $cambiati = @($risp.esiti | Where-Object { $_.cambiato })
  if ($cambiati.Count) { Log ("ricettari aggiornati: {0}" -f (($cambiati | ForEach-Object { '{0} {1} ({2} ricette{3})' -f $_.pg, $_.prof, $_.noti, $(if ($_.nuovo) { ', nuovo' } else { '' }) }) -join '; ')) }
  else { Log 'ricettari: nessuna novita' }
  return $risp
}

# ------------------------------------------------------------------ installazione
function CreaAvvio {
  $sh = New-Object -ComObject WScript.Shell
  $l = $sh.CreateShortcut($Avvio)
  $l.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  $l.Arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $Script + '"'
  $l.WorkingDirectory = $Qui
  $l.WindowStyle = 7
  $l.Description = 'ERT-Ponte: collega l''addon ERT al bot Discord della gilda'
  $l.Save()
  $dis = "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%~dp0ERT-Ponte.ps1`" -Disinstalla`r`npause`r`n"
  [IO.File]::WriteAllText((Join-Path $Qui 'Disinstalla.cmd'), $dis, [Text.Encoding]::ASCII)
}
function FermaVecchio {
  $pidFile = Join-Path $Qui 'pid.txt'
  if (-not (Test-Path -LiteralPath $pidFile)) { return }
  $vecchio = [int](Get-Content -LiteralPath $pidFile -Raw)
  if ($vecchio -and $vecchio -ne $PID) {
    $p = Get-CimInstance Win32_Process -Filter "ProcessId = $vecchio" -ErrorAction SilentlyContinue
    if ($p -and $p.CommandLine -like '*ERT-Ponte.ps1*') { Stop-Process -Id $vecchio -Force -ErrorAction SilentlyContinue }
  }
  Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
}

if ($Disinstalla) {
  FermaVecchio
  Remove-Item -LiteralPath $Avvio -Force -ErrorAction SilentlyContinue
  Write-Host "ERT-Ponte fermato e tolto dall'avvio automatico."
  Write-Host "L'addon ERT resta installato. Se vuoi, cancella anche la cartella $Qui"
  return
}

if ($Collega) {
  # installazione da ZIP: la chiave personale arriva dal link del bottone "Scarica ERT-Ponte" (/raid ponte su Discord)
  Write-Host ''
  Write-Host '=== ERT-Ponte: collegamento a Discord ===' -ForegroundColor Yellow
  Write-Host 'Su Discord scrivi /raid ponte, tieni premuto (o clic destro) sul bottone "Scarica ERT-Ponte",'
  Write-Host 'scegli "Copia link" e incollalo qui sotto (clic destro per incollare), poi Invio.'
  for ($tentativo = 0; $tentativo -lt 3; $tentativo++) {
    $link = Read-Host 'Link'
    $c = [regex]::Match([string]$link, '[?&]c=(\w+)').Groups[1].Value
    if (-not $c) { Write-Host 'Non vedo il codice nel link: riprova.' -ForegroundColor Red; continue }
    try {
      $k = Invoke-RestMethod -Uri ($BOT_BASE + '/ponte/chiave?c=' + $c) -TimeoutSec 30 -UseBasicParsing
      ScriviJson $CfgFile @{ token = $k.token; bot = $k.bot; sito = $k.sito }
      Write-Host 'Collegato.' -ForegroundColor Green
      return
    } catch { Write-Host 'Link scaduto o non valido: rifai /raid ponte su Discord e riprova.' -ForegroundColor Red }
  }
  return
}

if ($Elenco) { ScriviElenco; return }

$cfg = Config
if (-not $cfg -or -not $cfg.token) { Log 'manca config.json: riscarica ERT-Ponte con /raid ponte su Discord'; return }

if ($Installa) {
  Write-Host ''
  Write-Host '=== ERT-Ponte - Ethereum Raid Tools ===' -ForegroundColor Yellow
  $stato = Stato
  $wow = Wow $stato
  if (-not $wow) { Write-Host "Non ho trovato World of Warcraft: riapri il file e scegli la cartella _forever_." -ForegroundColor Red; return }
  Write-Host ("Gioco: {0}" -f $wow)
  try {
    $esito = AggiornaAddon $cfg $stato $wow
    Write-Host ("Addon ERT: {0}" -f @{ installato = 'installato'; aggiornato = 'aggiornato'; uguale = "gia' aggiornato" }[$esito])
  } catch { Write-Host ("Addon ERT: non riesco a scaricarlo ({0}); riprovo da solo piu' tardi" -f $_.Exception.Message) -ForegroundColor DarkYellow }
  try {
    $d = ScriviDati $cfg $stato $wow
    $pg = @($d.personaggi) -join ', '
    if (-not $pg) { $pg = 'nessuno: registrali con /raid personaggi' }
    Write-Host ("Collegato a Discord come {0} (personaggi: {1})" -f $d.nome, $pg) -ForegroundColor Green
    Write-Host ("Raid in programma: {0}; dove sei referente: {1}" -f @($d.eventi).Count, @($d.righe).Count)
    try {
      Write-Host 'Ricettari: leggo Mastercraft.lua...'
      $r = MandaRicettari $cfg $stato $wow -Forza
      if ($r -and @($r.esiti).Count -eq 0) { Write-Host 'Ricettari: nessuno scelto (spuntali nella lista se vuoi metterli sul sito).' }
      elseif ($r) { Write-Host ("Ricettari sincronizzati: {0}" -f (@($r.esiti | ForEach-Object { '{0} {1}' -f $_.pg, $_.prof }) -join ', ')) -ForegroundColor Green }
      else { Write-Host 'Ricettari: Mastercraft.lua non trovato (se usi Mastercraft, apri le professioni in gioco e fai /reload).' }
    } catch { Write-Host ("Ricettari: non riuscito ({0}); riprovo da solo" -f $_.Exception.Message) -ForegroundColor DarkYellow }
  } catch {
    Write-Host ("Il bot non risponde: {0}" -f $_.Exception.Message) -ForegroundColor Red
    Write-Host "Se dice 401 riscarica ERT-Ponte con /raid ponte su Discord."
    ScriviJson $StatoFile $stato
    return
  }
  ScriviJson $StatoFile $stato
  FermaVecchio
  if ($DaExe) {
    # avvio automatico e programma in background li gestisce ERT-Ponte.exe (senza finestre)
    Write-Host ''
    Write-Host 'Fatto. ERT-Ponte lavora in background e parte da solo a ogni accensione del PC.' -ForegroundColor Green
    return
  }
  CreaAvvio
  Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') -WindowStyle Hidden `
    -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', ('"' + $Script + '"'))
  Write-Host ''
  Write-Host 'Fatto. ERT-Ponte ora lavora in background e parte da solo a ogni accensione del PC.' -ForegroundColor Green
  Write-Host 'In gioco: /reload per vedere i raid nuovi; dopo un appello, /reload per mandarlo a Discord.'
  Write-Host 'Ricettari: dopo aver aperto le professioni in gioco, /reload (o esci) e il sito si aggiorna da solo.'
  Write-Host "Per toglierlo: Disinstalla.cmd in $Qui"
  return
}

# ------------------------------------------------------------------ giro continuo (in background)
$mutex = New-Object Threading.Mutex($false, 'Local\ERT-Ponte')
if (-not $mutex.WaitOne(0)) { return } # gia' acceso
Set-Content -LiteralPath (Join-Path $Qui 'pid.txt') -Value $PID
Log "ERT-Ponte $VERSIONE acceso"
$prossimiDati = [datetime]::MinValue
$prossimoAddon = [datetime]::MinValue
$prossimoScript = (Get-Date).AddMinutes(5)
$eraAperto = $false
$attesaErrore = [datetime]::MinValue
while ($true) {
  try {
    $cfg = Config
    $stato = Stato
    $wow = Wow $stato
    $adesso = Get-Date
    if (-not $wow) {
      if ($adesso -ge $prossimiDati) { Log "non trovo World of Warcraft: riapri ERT-Ponte.cmd per sceglierlo"; $prossimiDati = $adesso.AddMinutes(30) }
    } elseif ($adesso -ge $attesaErrore) {
      $aperto = WowAperto
      # appena si apre WoW, e poi ogni 3 minuti finche' resta aperto; a gioco chiuso ogni 30 minuti
      if (($aperto -and -not $eraAperto) -or $adesso -ge $prossimiDati) {
        if (MandaAppelli $cfg $stato $wow) { $stato.datiHash = $null }
        ScriviDati $cfg $stato $wow | Out-Null
        $prossimiDati = $adesso.AddMinutes($(if ($aperto) { 3 } else { 30 }))
      } elseif (MandaAppelli $cfg $stato $wow) {
        $stato.datiHash = $null
        ScriviDati $cfg $stato $wow | Out-Null
      }
      $eraAperto = $aperto
      MandaRicettari $cfg $stato $wow | Out-Null
      if ($adesso -ge $prossimoAddon) {
        $e = AggiornaAddon $cfg $stato $wow
        if ($e -ne 'uguale') { Log "addon ERT $e" }
        $prossimoAddon = $adesso.AddHours(6)
      }
      if ($adesso -ge $prossimoScript) {
        # nuova versione di ERT-Ponte: la scarica, partira' alla prossima accensione
        $nuovo = (Invoke-WebRequest -Uri ($cfg.sito + '/ponte/ERT-Ponte.ps1') -UseBasicParsing -TimeoutSec 30).Content
        if ($nuovo -is [byte[]]) { $nuovo = [Text.Encoding]::UTF8.GetString($nuovo) }
        # solo se la versione sul sito e' piu' nuova di questa (mai tornare indietro)
        $vSito = [regex]::Match($nuovo, "\`$VERSIONE = '([\d.]+)'").Groups[1].Value
        if ($vSito -and ([version]$vSito -gt [version]$VERSIONE) -and $nuovo -match 'ERT-Ponte') {
          [IO.File]::WriteAllText($Script, $nuovo, (New-Object Text.UTF8Encoding($false)))
          Log 'scaricata una versione nuova di ERT-Ponte: partira'' alla prossima accensione'
        }
        $prossimoScript = $adesso.AddHours(12)
      }
    }
    ScriviJson $StatoFile $stato
  } catch {
    Log ("errore: {0}" -f $_.Exception.Message)
    $attesaErrore = (Get-Date).AddMinutes(2)
  }
  if ($Una) { break }
  Start-Sleep -Seconds 20
}
