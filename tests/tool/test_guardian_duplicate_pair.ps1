# Dependency-free tests. Never call ADB, cloud services or the Run mode.
$ErrorActionPreference = 'Stop'
$operatorPath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'tool/guardian_duplicate_pair.ps1'
$tokens = $null
$errors = $null
$null = [Management.Automation.Language.Parser]::ParseFile($operatorPath, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'Operator PowerShell syntax failed' }
. $operatorPath
$checks = 0
function Assert-Result([bool]$Actual, [bool]$Expected, [string]$Label) {
  if ($Actual -ne $Expected) { throw "Gate regression: $Label" }
  $script:checks++
}

$now = [DateTimeOffset]::Parse('2026-10-09T00:00:00Z')
$longDeadline = $now.AddSeconds(360)
Assert-Result (Test-GuardianPairBudget $now $now.AddSeconds(181) $longDeadline $true) $true 'first sufficient lifetime'
Assert-Result (Test-GuardianPairBudget $now $now.AddSeconds(180) $longDeadline $true) $false 'first boundary refused'
Assert-Result (Test-GuardianPairBudget $now $now.AddSeconds(121) $longDeadline $false) $true 'duplicate sufficient lifetime'
Assert-Result (Test-GuardianPairBudget $now $now.AddSeconds(120) $longDeadline $false) $false 'duplicate boundary refused'
Assert-Result (Test-GuardianPairBudget $now $now.AddSeconds(-1) $longDeadline $false) $false 'expired event refused'
Assert-Result (Test-GuardianPairBudget $now $now.AddSeconds(480) $now.AddSeconds(165) $false) $false 'shutdown margin boundary refused'
Assert-Result (Test-GuardianPairBudget $now $now.AddSeconds(480) $now.AddSeconds(166) $false) $true 'shutdown margin sufficient'
Assert-Result (Test-GuardianPairBudget $now.AddSeconds(240) $now.AddSeconds(480) $longDeadline $false) $false 'preflight elapsed time refused'

# Exercise both Windows PowerShell string dates and PowerShell 7 JSON date objects.
$contextJson='{"delivery":"00000000-0000-4000-9000-000000000845","expires_at":"2026-10-10T15:55:29.972Z","window_deadline":"2026-10-10T15:55:03.622Z"}'
$parsedContext=Convert-GuardianPairContext ($contextJson | ConvertFrom-Json)
Assert-Result ($parsedContext.expires_at.ToString('o') -ceq '2026-10-10T15:55:29.9720000+00:00') $true 'JSON expiry UTC and milliseconds preserved'
Assert-Result ($parsedContext.window_deadline.ToString('o') -ceq '2026-10-10T15:55:03.6220000+00:00') $true 'JSON deadline UTC and milliseconds preserved'
Assert-Result (Test-GuardianPairBudget ([DateTimeOffset]::Parse('2026-10-10T15:50:00Z')) $parsedContext.expires_at $parsedContext.window_deadline $true) $true 'real context budget admitted'
Assert-Result ((Convert-GuardianPairUtc '2026-10-10T15:55:29.972Z').ToString('o') -ceq $parsedContext.expires_at.ToString('o')) $true 'ISO string path matches JSON path'
Assert-Result ((Convert-GuardianPairUtc ([DateTime]::Parse('2026-10-10T15:55:29.972Z').ToUniversalTime())).ToString('o') -ceq $parsedContext.expires_at.ToString('o')) $true 'UTC DateTime path preserves instant'
Assert-Result ((Convert-GuardianPairUtc $parsedContext.window_deadline) -eq $parsedContext.window_deadline) $true 'UTC DateTimeOffset path preserved'
function Assert-Rejected($Action,[string]$Label){
  $rejected=$false
  try{& $Action | Out-Null}catch{$rejected=$true}
  Assert-Result $rejected $true $Label
}
Assert-Rejected {Convert-GuardianPairUtc ([DateTime]::SpecifyKind([DateTime]::Now,[DateTimeKind]::Unspecified))} 'ambiguous DateTime refused'
Assert-Rejected {Convert-GuardianPairUtc ([DateTime]::Now)} 'local DateTime refused'
Assert-Rejected {Convert-GuardianPairUtc '10/10/2026 15:55:29'} 'culture-formatted string refused'
Assert-Rejected {Convert-GuardianPairUtc '2026-10-10T15:55:29.972+05:30'} 'non-UTC string refused'
Assert-Rejected {Convert-GuardianPairUtc ([DateTimeOffset]::Parse('2026-10-10T15:55:29+05:30'))} 'non-UTC offset object refused'
Assert-Rejected {Convert-GuardianPairUtc '2026-19-10T15:55:29Z'} 'invalid calendar refused'
Assert-Rejected {Convert-GuardianPairContext ([pscustomobject]@{delivery='other';expires_at=$now;window_deadline=$now})} 'non-synthetic context refused'
Assert-Rejected {Convert-GuardianPairContext ([pscustomobject]@{delivery='00000000-0000-4000-9000-000000000845';expires_at=$now;window_deadline=$now;extra=$true})} 'extra context fields refused'

# Local correlation values, not credentials or real account identifiers.
$delivery = '00000000-0000-4000-9000-000000000825'
$nonce = 'synthetic-job-correlation'
function New-TestGate { [pscustomobject]@{delivery=$delivery; nonce=$nonce; guarded_requeue_confirmed=$true} }
Assert-Result (Test-GuardianPairGate (New-TestGate) $delivery $nonce) $true 'exact confirmed gate'
Assert-Result (Test-GuardianPairGate $null $delivery $nonce) $false 'missing gate'
$gate = New-TestGate
$gate.guarded_requeue_confirmed = $false
Assert-Result (Test-GuardianPairGate $gate $delivery $nonce) $false 'unconfirmed requeue'
$gate.guarded_requeue_confirmed = 'true'
Assert-Result (Test-GuardianPairGate $gate $delivery $nonce) $false 'string truth refused'
$gate.guarded_requeue_confirmed = 1
Assert-Result (Test-GuardianPairGate $gate $delivery $nonce) $false 'number truth refused'
Assert-Result (Test-GuardianPairGate (New-TestGate) 'other-delivery' $nonce) $false 'other delivery refused'
Assert-Result (Test-GuardianPairGate (New-TestGate) $delivery 'stale-job') $false 'stale job refused'
$gate = New-TestGate
$gate | Add-Member -NotePropertyName extra -NotePropertyValue $true
Assert-Result (Test-GuardianPairGate $gate $delivery $nonce) $false 'extra fields refused'
Assert-Result (Test-GuardianPairGate ([pscustomobject]@{delivery=$delivery; nonce=$nonce}) $delivery $nonce) $false 'missing confirmation refused'
Assert-Result (Test-GuardianPairGate ([pscustomobject]@{Delivery=$delivery; nonce=$nonce; guarded_requeue_confirmed=$true}) $delivery $nonce) $false 'wrong field case refused'

Assert-Result ((Convert-GuardianProcessArgument '') -ceq '""') $true 'empty process argument preserved'
Assert-Result ((Convert-GuardianProcessArgument 'two words') -ceq '"two words"') $true 'spaces preserved'
Assert-Result ((Convert-GuardianProcessArgument 'a"b') -ceq '"a\"b"') $true 'embedded quote escaped'
Assert-Result ((Convert-GuardianProcessArgument 'C:\trailing\') -ceq '"C:\trailing\\"') $true 'trailing slash doubled'

# Default Plan mode must succeed with unusable executable paths and no live inputs.
$plan = & $operatorPath -AdbPath 'not-an-executable' -NodePath 'not-an-executable' | ConvertFrom-Json
if ($plan.mode -cne 'plan' -or $plan.sends -ne 0 -or $plan.maximum_sends -ne 2 -or
    $plan.gate_wait_seconds -ne 45 -or $plan.browser_shutdown_margin_seconds -ne 45 -or
    $plan.requeue_requires_exact_gate -cne $true) { throw 'Default no-send plan contract failed' }
$checks++
Write-Output "Guardian pair operator: $checks checks passed; no device or network calls."
