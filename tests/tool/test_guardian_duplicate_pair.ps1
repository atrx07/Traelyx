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

# The reviewed longer handoff cannot consume send or browser shutdown budgets.
Assert-Result ((Get-GuardianPairGateDeadline $now $now.AddSeconds(480) $longDeadline) -eq $now.AddSeconds(45)) $true 'default handoff remains 45 seconds'
Assert-Result ((Get-GuardianPairGateDeadline $now $now.AddSeconds(480) $longDeadline 90) -eq $now.AddSeconds(90)) $true 'explicit handoff capped at 90 seconds'
Assert-Result ((Get-GuardianPairGateDeadline $now $now.AddSeconds(480) $now.AddSeconds(200) 90) -eq $now.AddSeconds(35)) $true 'window budget shortens handoff'
Assert-Result ((Get-GuardianPairGateDeadline $now $now.AddSeconds(140) $longDeadline 90) -eq $now.AddSeconds(20)) $true 'event budget shortens handoff'
$waiting=Convert-GuardianPairUtc '2026-10-10T16:20:08.6996972Z'
$handoff=Convert-GuardianPairUtc '2026-10-10T16:21:16.5100096Z'
$expiry=Convert-GuardianPairUtc '2026-10-10T16:24:25.206748Z'
$window=Convert-GuardianPairUtc '2026-10-10T16:24:23.388Z'
$cutoff=Get-GuardianPairGateDeadline $waiting $expiry $window 90
Assert-Result ($cutoff.ToString('o') -ceq '2026-10-10T16:21:38.3880000+00:00') $true 'measured handoff retains window margin and precision'
Assert-Result ($handoff -lt $cutoff) $true 'measured 68 second handoff admitted'
Assert-Result ($handoff -lt (Get-GuardianPairGateDeadline $waiting $expiry $window)) $false 'original handoff regression reproduces refusal'
Assert-Result (Test-GuardianPairBudget $handoff $expiry $window $false) $true 'measured handoff retains strict send budget'
Assert-Result (Test-GuardianPairBudget $cutoff $expiry $window $false) $false 'cutoff equality still refuses dispatch'
Assert-Rejected {Get-GuardianPairGateDeadline $now $now.AddSeconds(480) $now.AddSeconds(165) 90} 'exhausted window refuses handoff'
Assert-Rejected {Get-GuardianPairGateDeadline $now $now.AddSeconds(120) $longDeadline 90} 'exhausted event refuses handoff'
Assert-Rejected {Get-GuardianPairGateDeadline $now $now.AddSeconds(480) $longDeadline 91} 'handoff above 90 refused'
Assert-Rejected {Get-GuardianPairGateDeadline $now $now.AddSeconds(480) $longDeadline 0} 'nonpositive handoff refused'

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
$extendedPlan = & $operatorPath -GateWaitSeconds 90 -AdbPath 'not-an-executable' -NodePath 'not-an-executable' | ConvertFrom-Json
Assert-Result ($extendedPlan.mode -ceq 'plan' -and $extendedPlan.sends -eq 0 -and
  $extendedPlan.gate_wait_seconds -eq 90 -and $extendedPlan.maximum_sends -eq 2 -and
  $extendedPlan.browser_shutdown_margin_seconds -eq 45 -and
  $extendedPlan.requeue_requires_exact_gate -ceq $true) $true 'extended no-send Plan preserves access and send limits'
Write-Output "Guardian pair operator: $checks checks passed; no device or network calls."
