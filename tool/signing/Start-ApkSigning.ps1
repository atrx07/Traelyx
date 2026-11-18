param(
    [Parameter(Mandatory=$true)][string]$PythonExe,
    [Parameter(Mandatory=$true)][string]$Repository,
    [Parameter(Mandatory=$true)][string]$Plan
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Traelyx local APK signing'
$form.Size = New-Object System.Drawing.Size(590, 290)
$form.StartPosition = 'CenterScreen'
$form.TopMost = $true
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$label = New-Object System.Windows.Forms.Label
$label.Text = 'Enter the existing production keystore password. Three prepared APKs will be signed and checked locally. No key is created or copied. Nothing is installed or uploaded.'
$label.SetBounds(20, 15, 540, 60)
$form.Controls.Add($label)
$password = New-Object System.Windows.Forms.TextBox
$password.UseSystemPasswordChar = $true
$password.SetBounds(20, 85, 540, 25)
$form.Controls.Add($password)
$notice = New-Object System.Windows.Forms.Label
$notice.SetBounds(20, 125, 540, 55)
$form.Controls.Add($notice)
$sign = New-Object System.Windows.Forms.Button
$sign.Text = 'Sign and verify APKs'
$sign.SetBounds(20, 195, 320, 30)
$form.Controls.Add($sign)
$close = New-Object System.Windows.Forms.Button
$close.Text = 'Cancel'
$close.SetBounds(370, 195, 190, 30)
$close.Add_Click({ $password.Clear(); $form.Close() })
$form.Controls.Add($close)
$statusPath = Join-Path $Repository '.dart_tool/release-signing/apk-status-v1.json'
$statusDirectory = Split-Path -Parent $statusPath
[void][System.IO.Directory]::CreateDirectory($statusDirectory)
'{"status":"awaiting_private_password"}' | Set-Content -LiteralPath $statusPath -Encoding UTF8
$sign.Add_Click({
    if ($password.Text.Length -eq 0) { $notice.Text = 'Enter the existing password.'; return }
    $sign.Enabled = $false
    $close.Enabled = $false
    $password.Enabled = $false
    $notice.Text = 'Verifying the pinned key, then signing and checking three APKs...'
    $form.Refresh()
    try {
        $info = New-Object System.Diagnostics.ProcessStartInfo
        $info.FileName = $PythonExe
        $info.WorkingDirectory = $Repository
        $info.Arguments = '-m tool.release_apk sign --plan "' + $Plan + '"'
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        $info.RedirectStandardOutput = $true
        $info.RedirectStandardError = $true
        $info.EnvironmentVariables['TRAELYX_SIGNING_SETUP_PASSWORD'] = $password.Text
        try {
            $process = [System.Diagnostics.Process]::Start($info)
        } finally {
            [void]$info.EnvironmentVariables.Remove('TRAELYX_SIGNING_SETUP_PASSWORD')
            $password.Clear()
        }
        $output = $process.StandardOutput.ReadToEndAsync()
        $errors = $process.StandardError.ReadToEndAsync()
        while (-not $process.WaitForExit(100)) { [System.Windows.Forms.Application]::DoEvents() }
        if ($process.ExitCode -eq 0) {
            $notice.Text = 'Three APKs signed and verified. Nothing installed or uploaded. You can close this window.'
        } else {
            $notice.Text = 'Signing needs attention. Tell Codex to check the redacted status. Do not send the password.'
        }
        $process.Dispose()
    } catch {
        $password.Clear()
        $notice.Text = 'Local helper could not finish. Existing keys are retained; tell Codex.'
        '{"status":"failed","reason":"Local signing helper could not start or finish."}' | Set-Content -LiteralPath $statusPath -Encoding UTF8
    }
    $close.Text = 'Close'
    $close.Enabled = $true
})
[void]$form.ShowDialog()
$password.Clear()
$form.Dispose()
