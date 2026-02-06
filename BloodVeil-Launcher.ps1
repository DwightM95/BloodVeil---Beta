# BloodVeil Auto-Installer and Launcher
# Double-click this file or right-click → "Run with PowerShell"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$installDir = Join-Path $env:USERPROFILE "BloodVeil"
$clientJar = Join-Path $installDir "Bloodveil.jar"
$cacheDir = Join-Path $installDir "cache"
$clientUrl = "https://github.com/DwightM95/BloodVeil---Beta/releases/download/v1.0/Bloodveil.jar"
$cacheUrl = "https://github.com/DwightM95/BloodVeil---Beta/releases/download/v1.0/cache.zip"
$cacheZip = Join-Path $installDir "cache.zip"

$form = New-Object System.Windows.Forms.Form
$form.Text = "BloodVeil Launcher"
$form.Size = New-Object System.Drawing.Size(500, 180)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Location = New-Object System.Drawing.Point(10, 20)
$titleLabel.Size = New-Object System.Drawing.Size(470, 30)
$titleLabel.Font = New-Object System.Drawing.Font("Arial", 16, [System.Drawing.FontStyle]::Bold)
$titleLabel.Text = "BloodVeil"
$titleLabel.TextAlign = "MiddleCenter"
$form.Controls.Add($titleLabel)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(10, 60)
$statusLabel.Size = New-Object System.Drawing.Size(470, 20)
$statusLabel.Text = "Initializing..."
$statusLabel.TextAlign = "MiddleCenter"
$form.Controls.Add($statusLabel)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10, 90)
$progressBar.Size = New-Object System.Drawing.Size(470, 25)
$form.Controls.Add($progressBar)

$launchButton = New-Object System.Windows.Forms.Button
$launchButton.Location = New-Object System.Drawing.Point(175, 125)
$launchButton.Size = New-Object System.Drawing.Size(150, 30)
$launchButton.Text = "Launch Game"
$launchButton.Enabled = $false
$launchButton.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($launchButton)

$form.Show()
$form.Refresh()
[System.Windows.Forms.Application]::DoEvents()

function Download-File {
    param($url, $output, $statusText)
    $statusLabel.Text = $statusText
    $form.Refresh()
    [System.Windows.Forms.Application]::DoEvents()
    
    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "BloodVeil-Launcher")
        
        $syncHash = [hashtable]::Synchronized(@{})
        $syncHash.Form = $form
        $syncHash.ProgressBar = $progressBar
        
        Register-ObjectEvent -InputObject $wc -EventName DownloadProgressChanged -Action {
            $syncHash.ProgressBar.Value = $EventArgs.ProgressPercentage
            $syncHash.Form.Refresh()
            [System.Windows.Forms.Application]::DoEvents()
        } | Out-Null
        
        $task = $wc.DownloadFileTaskAsync($url, $output)
        
        while (!$task.IsCompleted) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 100
        }
        
        $wc.Dispose()
        
        if ($task.IsFaulted) {
            throw $task.Exception
        }
        
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Download failed:`n$($_.Exception.Message)`n`nPlease check your internet connection.", "Error", "OK", "Error")
        $form.Close()
        exit 1
    }
}

if (!(Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir | Out-Null
}

$statusLabel.Text = "Checking files..."
$form.Refresh()
[System.Windows.Forms.Application]::DoEvents()

if (!(Test-Path $clientJar)) {
    Download-File $clientUrl $clientJar "Downloading client (54 MB)..."
}

$cacheValid = (Test-Path $cacheDir) -and (Test-Path (Join-Path $cacheDir "main_file_cache.idx0"))
if (!$cacheValid) {
    Download-File $cacheUrl $cacheZip "Downloading cache (328 MB)..."
    
    $statusLabel.Text = "Extracting files..."
    $progressBar.Style = "Marquee"
    $form.Refresh()
    [System.Windows.Forms.Application]::DoEvents()
    
    try {
        Expand-Archive -Path $cacheZip -DestinationPath $installDir -Force
        Remove-Item $cacheZip -Force -ErrorAction SilentlyContinue
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Extraction failed:`n$($_.Exception.Message)", "Error", "OK", "Error")
        $form.Close()
        exit 1
    }
    
    $progressBar.Style = "Continuous"
}

$statusLabel.Text = "Ready to play!"
$progressBar.Value = 100
$launchButton.Enabled = $true
$form.Refresh()

$launchButton.Add_Click({
    try {
        $javaExe = "javaw"
        $testJava = Get-Command javaw -ErrorAction SilentlyContinue
        if (!$testJava) {
            $javaExe = "java"
        }
        
        Start-Process -FilePath $javaExe -ArgumentList "-jar `"$clientJar`"" -WorkingDirectory $installDir -WindowStyle Hidden
        $form.Close()
        
    } catch {
        $msg = "Cannot launch game. Java 11+ is required.`n`nDownload from: https://adoptium.net/`n`nError: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($msg, "Java Not Found", "OK", "Error")
    }
})

[void]$form.ShowDialog()
