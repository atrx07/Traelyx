# Explicit operator job only. Browser review owns enable/requeue/disable/cleanup.
# Run only after approval, fresh SQL lifetime checks and both enable confirmations.
param(
  [ValidateSet('Plan','Run')][string]$Mode = 'Plan',
  [string]$ContextPath,
  [string]$DeliveryId,
  [DateTimeOffset]$ExpiresAt,
  [DateTimeOffset]$WindowDeadline,
  [string]$AdbPath = 'adb',
  [string]$Serial,
  [string]$NodePath = 'node'
)

function Convert-GuardianPairUtc($Value) {
  # PowerShell 7 ConvertFrom-Json may already produce DateTime. Parsing that
  # value again through its culture-formatted string loses Kind and precision.
  if($Value -is [DateTimeOffset]) {
    if($Value.Offset -ne [TimeSpan]::Zero){throw 'operator_context_timestamp_invalid'}
    return $Value
  }
  if($Value -is [DateTime]) {
    if($Value.Kind -ne [DateTimeKind]::Utc){throw 'operator_context_timestamp_invalid'}
    return [DateTimeOffset]$Value
  }
  if($Value -isnot [string] -or
    $Value -notmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,7})?Z$'){
    throw 'operator_context_timestamp_invalid'
  }
  try {
    return [DateTimeOffset]::Parse($Value,[Globalization.CultureInfo]::InvariantCulture)
  } catch {throw 'operator_context_timestamp_invalid'}
}

function Convert-GuardianPairContext($Context) {
  if($null -eq $Context -or $Context -is [Array] -or
    (@($Context.PSObject.Properties.Name | Sort-Object) -join ',') -cne
      'delivery,expires_at,window_deadline' -or
    $Context.delivery -isnot [string] -or
    $Context.delivery -notmatch '^00000000-0000-4000-9000-000000000[0-9]{2}5$'){
    throw 'operator_context_invalid'
  }
  return [pscustomobject]@{
    delivery=$Context.delivery
    expires_at=(Convert-GuardianPairUtc $Context.expires_at)
    window_deadline=(Convert-GuardianPairUtc $Context.window_deadline)
  }
}

function Test-GuardianPairBudget($Now, $Expiry, $Deadline, [bool]$First) {
  # 45s dispatch + 75s phone observation + 45s browser shutdown margin.
  return (($Expiry-$Now).TotalSeconds -gt $(if($First){180}else{120})) -and
    (($Deadline-$Now).TotalSeconds -gt 165)
}

function Test-GuardianPairGate($Gate, [string]$ExpectedDelivery, [string]$ExpectedNonce) {
  if($null -eq $Gate){return $false}
  $keys=@($Gate.PSObject.Properties.Name | Sort-Object)
  return ($keys -join ',') -ceq 'delivery,guarded_requeue_confirmed,nonce' -and
    $Gate.delivery -ceq $ExpectedDelivery -and $Gate.nonce -ceq $ExpectedNonce -and
    $Gate.guarded_requeue_confirmed -is [bool] -and $Gate.guarded_requeue_confirmed
}

function Convert-GuardianProcessArgument([string]$Argument) {
  # Windows command-line quoting, including quotes and trailing backslashes.
  return '"' + (($Argument -replace '(\\*)"', '$1$1\"') -replace '(\\+)$', '$1$1') + '"'
}

if($MyInvocation.InvocationName -eq '.'){return} # Pure gate tests can dot-source.
if($Mode -eq 'Plan'){
  [pscustomobject]@{mode='plan'; sends=0; maximum_sends=2; gate_wait_seconds=45;
    browser_shutdown_margin_seconds=45; requeue_requires_exact_gate=$true} | ConvertTo-Json -Compress
  return
}

$ErrorActionPreference='Stop'
$pairRoot=Split-Path $PSScriptRoot -Parent
$priorAwake=$null
function Write-GuardianPairJson([string]$Path, $Value) {
  $stream=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
  try{
    $bytes=[Text.Encoding]::UTF8.GetBytes(($Value | ConvertTo-Json -Compress))
    $stream.Write($bytes,0,$bytes.Length)
  }finally{$stream.Dispose()}
}
function Invoke-PairAdb([string[]]$Arguments, [bool]$AllowAbsent=$false) {
  $process=New-Object Diagnostics.Process
  try{
    $start=New-Object Diagnostics.ProcessStartInfo
    $start.FileName=$AdbPath
    $start.Arguments=(@(@('-s',$Serial)+$Arguments | ForEach-Object {Convert-GuardianProcessArgument $_}) -join ' ')
    $start.UseShellExecute=$false
    $start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true
    $start.RedirectStandardError=$true
    $process.StartInfo=$start
    if(-not $process.Start()){throw 'operator_adb_failed'}
    $outputTask=$process.StandardOutput.ReadToEndAsync()
    $errorTask=$process.StandardError.ReadToEndAsync()
    if(-not $process.WaitForExit(15000)){
      $process.Kill()
      throw 'operator_adb_timeout'
    }
    $value=$outputTask.GetAwaiter().GetResult()
    $null=$errorTask.GetAwaiter().GetResult() # Never emit raw device errors.
    if($value.Length -gt 4194304){throw 'operator_adb_output_excessive'}
    $exitCode=$process.ExitCode
    if($exitCode -ne 0 -and -not ($AllowAbsent -and $exitCode -eq 1 -and -not $value.Trim())){
      throw 'operator_adb_failed'
    }
    return $value
  }finally{
    $process.Dispose()
  }
}
function Assert-PairReady([bool]$First) {
  if(-not (Test-GuardianPairBudget ([DateTimeOffset]::UtcNow) $ExpiresAt $WindowDeadline $First)){
    throw 'operator_budget_exhausted'
  }
  if((Invoke-PairAdb @('shell','pidof','io.github.atrx07.traelyx') $true).Trim()){
    throw 'operator_process_present'
  }
  if((Invoke-PairAdb @('shell','dumpsys','connectivity')) -notmatch '(?i)Active default network:\s*\d+'){
    throw 'operator_network_absent'
  }
  $preflight=& $NodePath tool/guardian_duplicate_phone.mjs preflight $AdbPath $Serial
  if($LASTEXITCODE -ne 0){throw 'operator_preflight_failed'}
}
function Invoke-PairPhase([string]$Phase) {
  Assert-PairReady ($Phase -eq 'first')
  $stamp=(Invoke-PairAdb @('shell',"date '+%m-%d %H:%M:%S.000'")).Trim()
  if($stamp -notmatch '^\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.000$'){throw 'operator_timestamp_invalid'}
  # Preflight subprocesses can consume time; recheck immediately before sending.
  if(-not (Test-GuardianPairBudget ([DateTimeOffset]::UtcNow) $ExpiresAt $WindowDeadline ($Phase -eq 'first'))){
    throw 'operator_budget_exhausted'
  }
  # Sentinel is created before invocation. Ambiguous acceptance is never retried.
  Write-GuardianPairJson (Join-Path $stateRoot ($Phase+'.once')) @{attempted=$true}
  $accepted=& $NodePath tool/guardian_push_probe.mjs send
  if($LASTEXITCODE -ne 0){throw 'operator_send_uncertain'}
  Write-GuardianPairJson (Join-Path $stateRoot ($Phase+'-accepted.json')) @{accepted_utc=[DateTimeOffset]::UtcNow.ToString('o')}
  $observed=& $NodePath tool/guardian_duplicate_phone.mjs $Phase $AdbPath $Serial $DeliveryId $stamp
  if($LASTEXITCODE -ne 0){throw 'operator_phone_phase_failed'}
  $parsed=$observed | ConvertFrom-Json
  if($parsed.verified -isnot [bool] -or $parsed.verified -cne $true -or $parsed.mode -cne $Phase){throw 'operator_phone_phase_invalid'}
  Write-GuardianPairJson (Join-Path $stateRoot ($Phase+'-passed.json')) $parsed
  Write-Output ($parsed | ConvertTo-Json -Compress)
}

Push-Location $pairRoot
try{
  if($ContextPath){
    if($PSBoundParameters.ContainsKey('DeliveryId') -or
      $PSBoundParameters.ContainsKey('ExpiresAt') -or
      $PSBoundParameters.ContainsKey('WindowDeadline')){throw 'operator_context_mixed_inputs'}
    $context=Convert-GuardianPairContext ([IO.File]::ReadAllText(
      (Join-Path $pairRoot $ContextPath)) | ConvertFrom-Json)
    $DeliveryId=$context.delivery
    $ExpiresAt=$context.expires_at
    $WindowDeadline=$context.window_deadline
  }
  if($DeliveryId -notmatch '^00000000-0000-4000-9000-000000000[0-9]{2}5$' -or $Serial -notmatch '^[A-Za-z0-9]+$'){
    throw 'operator_input_invalid'
  }
  $stateRoot=Join-Path $pairRoot ('.dart_tool/guardian-pair-'+$DeliveryId.Substring($DeliveryId.Length-3))
  if(Test-Path -LiteralPath $stateRoot){throw 'operator_existing_job_refused'}
  if(Test-Path (Join-Path $pairRoot ('.dart_tool/guardian-duplicate-'+$DeliveryId+'.sha256'))){throw 'operator_existing_claim_baseline_refused'}
  Assert-PairReady $true
  New-Item -ItemType Directory -Path $stateRoot | Out-Null
  $nonce=[Guid]::NewGuid().ToString('D') # Local job correlation, not an access credential.
  $awakeValue=(Invoke-PairAdb @('shell','settings','get','global','stay_on_while_plugged_in')).Trim()
  if($awakeValue -notmatch '^[0-7]$'){throw 'operator_wake_setting_invalid'}
  $priorAwake=$awakeValue
  Write-GuardianPairJson (Join-Path $stateRoot 'prior-awake.json') @{value=$priorAwake}
  Invoke-PairAdb @('shell','settings','put','global','stay_on_while_plugged_in','2') | Out-Null
  Invoke-PairAdb @('shell','input','keyevent','KEYCODE_WAKEUP') | Out-Null
  Invoke-PairAdb @('shell','uiautomator','dump','/data/local/tmp/traelyx-pair-preflight.xml') | Out-Null
  if((Invoke-PairAdb @('shell','dumpsys','window','policy')) -match '(?m)^\s*showing=true\s*$'){
    Invoke-PairAdb @('shell','input','swipe','540','1850','540','650','500') | Out-Null
    Invoke-PairAdb @('shell','uiautomator','dump','/data/local/tmp/traelyx-pair-preflight.xml') | Out-Null
  }
  Invoke-PairPhase 'first'
  Invoke-PairAdb @('shell','settings','put','global','stay_on_while_plugged_in',$priorAwake) | Out-Null
  Write-GuardianPairJson (Join-Path $stateRoot 'waiting.json') @{delivery=$DeliveryId; nonce=$nonce; phase='waiting_for_guarded_requeue'}
  Write-Output 'waiting_for_guarded_requeue'
  $gatePath=Join-Path $stateRoot 'requeue-confirmed.json'
  $gateDeadline=[DateTimeOffset]::UtcNow.AddSeconds(45)
  while(-not (Test-Path -LiteralPath $gatePath)){
    if([DateTimeOffset]::UtcNow -ge $gateDeadline){throw 'operator_gate_wait_expired'}
    Start-Sleep -Milliseconds 100
  }
  $gate=[IO.File]::ReadAllText($gatePath) | ConvertFrom-Json
  if(-not (Test-GuardianPairGate $gate $DeliveryId $nonce)){throw 'operator_gate_invalid'}
  Invoke-PairPhase 'duplicate'
  Write-Output 'pair_verified_close_both_functions_now'
}catch{
  Write-Output 'operator_job_stopped_close_both_functions_now'
  exit 1 # No raw subprocess output, exceptions, tokens or account information.
}finally{
  if($null -ne $priorAwake){
    try{
      Invoke-PairAdb @('shell','settings','put','global','stay_on_while_plugged_in',$priorAwake) | Out-Null
      Write-Output 'usb_wake_setting_restored=True'
    }catch{Write-Output 'usb_wake_setting_restored=False'}
  }
  Pop-Location
}
