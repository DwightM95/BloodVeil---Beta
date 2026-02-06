# BloodVeil Auto-Installer and Launcher
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$installDir = Join-Path $env:USERPROFILE "BloodVeil"
$clientJar = Join-Path $installDir "Bloodveil.jar"
$cacheDir = Join-Path $installDir "cache"
$clientUrl = "https://github.com/DwightM95/BloodVeil---Beta/releases/download/V1.0/Bloodveil.jar"
$cacheUrl = "https://github.com/DwightM95/BloodVeil---Beta/releases/download/V1.0/cache.zip"
$cacheZip = Join-Path $installDir "cache.zip"

# Create install directory
if (!(Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

# Create form
$form = New-Object System.Windows.Forms.Form
$form.Text = "BloodVeil Launcher"
$form.Size = New-Object System.Drawing.Size(500, 200)
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
$launchButton.Location = New-Object System.Drawing.Point(175, 130)
$launchButton.Size = New-Object System.Drawing.Size(150, 35)
$launchButton.Text = "Launch Game"
$launchButton.Enabled = $false
$launchButton.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($launchButton)

# Function to find Java
function Find-Java {
    # Try PATH first
    $javaCmd = Get-Command javaw -ErrorAction SilentlyContinue
    if ($javaCmd) { return $javaCmd.Source }
    
    $javaCmd = Get-Command java -ErrorAction SilentlyContinue
    if ($javaCmd) { return $javaCmd.Source }
    
    # Search common installation paths
    $searchPaths = @(
        "C:\Program Files\Java",
        "C:\Program Files (x86)\Java",
        "C:\Program Files\Eclipse Adoptium",
        "C:\Program Files\AdoptOpenJDK",
        "C:\Program Files\Temurin",
        "C:\Program Files\Zulu",
        "C:\Program Files\Microsoft",
        "${env:ProgramFiles}\Java",
        "${env:ProgramFiles(x86)}\Java",
        "${env:LOCALAPPDATA}\Programs"
    )
    
    foreach ($basePath in $searchPaths) {
        if (Test-Path $basePath) {
            Get-ChildItem $basePath -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $javaw = Join-Path $_.FullName "bin\javaw.exe"
                $java = Join-Path $_.FullName "bin\java.exe"
                
                if (Test-Path $javaw) { return $javaw }
                if (Test-Path $java) { return $java }
            }
        }
    }
    
    # Check JAVA_HOME
    $javaHome = [Environment]::GetEnvironmentVariable("JAVA_HOME", "Machine")
    if ($javaHome -and (Test-Path "$javaHome\bin\javaw.exe")) {
        return "$javaHome\bin\javaw.exe"
    }
    
    return $null
}

# Launch button handler
$launchButton.Add_Click({
    $javaPath = Find-Java
    
    if (!$javaPath) {
        $result = [System.Windows.Forms.MessageBox]::Show(
            "Java 11+ not found!`n`nWould you like to download Java now?`n`n(You'll need to restart the launcher after installing)",
            "Java Required",
            "YesNo",
            "Question"
        )
        if ($result -eq "Yes") {
            Start-Process "https://adoptium.net/temurin/releases/?version=11"
        }
        return
    }
    
    try {
        Start-Process -FilePath $javaPath -ArgumentList "-jar `"$clientJar`"" -WorkingDirectory $installDir -WindowStyle Hidden
        $form.Close()
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to launch game:`n$($_.Exception.Message)", "Launch Error", "OK", "Error")
    }
})

# Setup on form shown
$form.Add_Shown({
    $statusLabel.Text = "Checking installation..."
    $form.Refresh()
    
    # Check if files exist
    $needsClient = !(Test-Path $clientJar)
    $needsCache = !(Test-Path $cacheDir) -or !(Test-Path (Join-Path $cacheDir "main_file_cache.idx0"))
    
    if ($needsClient) {
        try {
            $statusLabel.Text = "Downloading client (54 MB)..."
            $form.Refresh()
            
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile($clientUrl, $clientJar)
            $wc.Dispose()
            
            $progressBar.Value = 30
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to download client:`n$($_.Exception.Message)", "Download Error", "OK", "Error")
            $form.Close()
            return
        }
    } else {
        $progressBar.Value = 30
    }
    
    if ($needsCache) {
        try {
            $statusLabel.Text = "Downloading game cache (328 MB)..."
            $progressBar.Value = 40
            $form.Refresh()
            
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile($cacheUrl, $cacheZip)
            $wc.Dispose()
            
            $statusLabel.Text = "Extracting cache files..."
            $progressBar.Value = 70
            $form.Refresh()
            
            Expand-Archive -Path $cacheZip -DestinationPath $installDir -Force
            Remove-Item $cacheZip -Force -ErrorAction SilentlyContinue
            
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to download/extract cache:`n$($_.Exception.Message)", "Error", "OK", "Error")
            $form.Close()
            return
        }
    }
    
    $statusLabel.Text = "Ready to play!"
    $progressBar.Value = 100
    $launchButton.Enabled = $true
    $launchButton.Focus()
})

[void]$form.ShowDialog()
