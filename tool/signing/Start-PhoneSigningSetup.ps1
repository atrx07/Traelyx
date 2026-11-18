param(
    [Parameter(Mandatory=$true)][string]$PythonExe,
    [Parameter(Mandatory=$true)][string]$Repository,
    [Parameter(Mandatory=$true)][string]$Plan
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Traelyx production key setup'
$form.Size = New-Object System.Drawing.Size(590, 390)
$form.StartPosition = 'CenterScreen'
$form.TopMost = $true
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$script:started = $false
$statusPath = Join-Path $Repository '.dart_tool/release-signing/phone-setup-status-v1.json'
$label = New-Object System.Windows.Forms.Label
$label.Text = 'Choose a dedicated password. The key stays on this PC; its encrypted backup goes to the phone Documents/TraelyxSigningBackup folder and is read back for verification. Keep that folder local/unsynced. No APK is built.'
$label.SetBounds(20, 15, 540, 65)
$form.Controls.Add($label)
$firstLabel = New-Object System.Windows.Forms.Label
$firstLabel.Text = 'Password (at least 16 characters):'
$firstLabel.SetBounds(20, 85, 540, 20)
$form.Controls.Add($firstLabel)
$first = New-Object System.Windows.Forms.TextBox
$first.UseSystemPasswordChar = $true
$first.SetBounds(20, 110, 540, 25)
$form.Controls.Add($first)
$secondLabel = New-Object System.Windows.Forms.Label
$secondLabel.Text = 'Confirm password:'
$secondLabel.SetBounds(20, 145, 540, 20)
$form.Controls.Add($secondLabel)
$second = New-Object System.Windows.Forms.TextBox
$second.UseSystemPasswordChar = $true
$second.SetBounds(20, 170, 540, 25)
$form.Controls.Add($second)
$recovery = New-Object System.Windows.Forms.CheckBox
$recovery.Text = 'I saved this password separately in my password manager or offline recovery record, so losing this PC will not lose the only password.'
$recovery.SetBounds(20, 205, 540, 50)
$form.Controls.Add($recovery)
$notice = New-Object System.Windows.Forms.Label
$notice.SetBounds(20, 260, 540, 35)
$form.Controls.Add($notice)
$create = New-Object System.Windows.Forms.Button
$create.Text = 'Create key and phone backup'
$create.SetBounds(20, 305, 320, 30)
$form.Controls.Add($create)
$close = New-Object System.Windows.Forms.Button
$close.Text = 'Cancel'
$close.SetBounds(370, 305, 190, 30)
$close.Add_Click({ $first.Clear(); $second.Clear(); $form.Close() })
$form.Controls.Add($close)
$create.Add_Click({
    if ($first.Text.Length -lt 16 -or $first.Text -cne $second.Text -or
        $first.Text.ToCharArray().Where({ [char]::IsControl($_) }).Count -gt 0 -or -not $recovery.Checked) {
        $notice.Text = 'Use matching passwords of at least 16 characters and save a separate recovery copy.'
        return
    }
    $create.Enabled = $false
    $close.Enabled = $false
    $first.Enabled = $false
    $second.Enabled = $false
    $notice.Text = 'Creating/verifying the key and physical-phone backup...'
    $form.Refresh()
    try {
        $info = New-Object System.Diagnostics.ProcessStartInfo
        $info.FileName = $PythonExe
        $info.WorkingDirectory = $Repository
        $info.Arguments = '-m tool.release_signing_phone_setup --plan "' + $Plan + '"'
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        $info.RedirectStandardOutput = $true
        $info.RedirectStandardError = $true
        $info.EnvironmentVariables['TRAELYX_SIGNING_SETUP_PASSWORD'] = $first.Text
        $info.EnvironmentVariables['TRAELYX_SIGNING_RECOVERY_ATTESTED'] = 'true'
        try {
            $process = [System.Diagnostics.Process]::Start($info)
            $script:started = $true
        } finally {
            [void]$info.EnvironmentVariables.Remove('TRAELYX_SIGNING_SETUP_PASSWORD')
            $first.Clear(); $second.Clear()
        }
        $output = $process.StandardOutput.ReadToEndAsync()
        $errors = $process.StandardError.ReadToEndAsync()
        while (-not $process.WaitForExit(100)) { [System.Windows.Forms.Application]::DoEvents() }
        if ($process.ExitCode -eq 0) {
            $notice.Text = 'Key and phone backup verified. Keep your password recovery copy safe. You can close this window.'
        } else {
            $notice.Text = 'Setup needs attention. Existing keys were retained. Tell Codex to check the redacted status.'
        }
        $process.Dispose()
    } catch {
        $first.Clear(); $second.Clear()
        $notice.Text = 'Setup could not finish. Tell Codex; do not send the password.'
        '{"status":"failed","reason":"Local helper could not start or finish; existing keys are retained."}' | Set-Content -LiteralPath $statusPath -Encoding UTF8
    }
    $close.Text = 'Close'
    $close.Enabled = $true
})
[void]$form.ShowDialog()
if (-not $script:started) {
    '{"status":"cancelled","receipt_created":false}' | Set-Content -LiteralPath $statusPath -Encoding UTF8
}
$first.Clear(); $second.Clear()
$form.Dispose()
