# BloodVeil Auto-Installer and Launcher
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$installDir = Join-Path $env:USERPROFILE "BloodVeil"
$clientJar = Join-Path $installDir "Bloodveil.jar"
$cacheDir = Join-Path $installDir "cache"
$jreDir = Join-Path $installDir "jre"
$clientUrl = "https://github.com/DwightM95/BloodVeil---Beta/releases/download/V1.0/Bloodveil.jar"
$cacheUrl = "https://github.com/DwightM95/BloodVeil---Beta/releases/download/V1.0/cache.zip"
$jreUrl = "https://api.adoptium.net/v3/binary/latest/11/ga/windows/x64/jre/hotspot/normal/eclipse"
$cacheZip = Join-Path $installDir "cache.zip"
$jreZip = Join-Path $installDir "jre.zip"

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
    # Check bundled JRE first
    $bundledJava = Join-Path $jreDir "bin\javaw.exe"
    if (Test-Path $bundledJava) { return $bundledJava }
    
    # Try PATH
    $javaCmd = Get-Command javaw -ErrorAction SilentlyContinue
    if ($javaCmd) { return $javaCmd.Source }
    
    $javaCmd = Get-Command java -ErrorAction SilentlyContinue
    if ($javaCmd) { return $javaCmd.Source }
    
    # Search common paths
    $searchPaths = @(
        "C:\Program Files\Java",
        "C:\Program Files (x86)\Java",
        "C:\Program Files\Eclipse Adoptium",
        "C:\Program Files\AdoptOpenJDK",
        "C:\Program Files\Temurin",
        "$env:ProgramFiles\Java",
        "$env:LOCALAPPDATA\Programs"
    )
    
    foreach ($basePath in $searchPaths) {
        if (Test-Path $basePath) {
            $javaExes = Get-ChildItem $basePath -Recurse -Filter "javaw.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($javaExes) { return $javaExes.FullName }
        }
    }
    
    return $null
}

# Launch button handler
$launchButton.Add_Click({
    $javaPath = Find-Java
    
    if (!$javaPath) {
        [System.Windows.Forms.MessageBox]::Show("Could not find Java. Please restart the launcher.", "Error", "OK", "Error")
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
    $needsJava = !(Find-Java)
    
    $progress = 0
    
    # Download Java if needed
    if ($needsJava) {
        try {
            $statusLabel.Text = "Downloading Java (45 MB)..."
            $form.Refresh()
            
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile($jreUrl, $jreZip)
            $wc.Dispose()
            
            $statusLabel.Text = "Installing Java..."
            $progress = 15
            $progressBar.Value = $progress
            $form.Refresh()
            
            Expand-Archive -Path $jreZip -DestinationPath $installDir -Force
            
            # Find the extracted JRE folder and rename it
            $extractedJre = Get-ChildItem $installDir -Directory | Where-Object { $_.Name -like "jdk*" -or $_.Name -like "jre*" } | Select-Object -First 1
            if ($extractedJre) {
                if (Test-Path $jreDir) { Remove-Item $jreDir -Recurse -Force }
                Move-Item $extractedJre.FullName $jreDir
            }
            
            Remove-Item $jreZip -Force -ErrorAction SilentlyContinue
            
            $progress = 20
            $progressBar.Value = $progress
            
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to download Java:`n$($_.Exception.Message)", "Error", "OK", "Error")
            $form.Close()
            return
        }
    } else {
        $progress = 20
        $progressBar.Value = $progress
    }
    
    # Download client
    if ($needsClient) {
        try {
            $statusLabel.Text = "Downloading client (54 MB)..."
            $form.Refresh()
            
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile($clientUrl, $clientJar)
            $wc.Dispose()
            
            $progress = 40
            $progressBar.Value = $progress
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to download client:`n$($_.Exception.Message)", "Download Error", "OK", "Error")
            $form.Close()
            return
        }
    } else {
        $progress = 40
        $progressBar.Value = $progress
    }
    
    # Download and extract cache
    if ($needsCache) {
        try {
            $statusLabel.Text = "Downloading game cache (328 MB)..."
            $progressBar.Value = 50
            $form.Refresh()
            
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile($cacheUrl, $cacheZip)
            $wc.Dispose()
            
            $statusLabel.Text = "Extracting cache files..."
            $progressBar.Value = 8
[void]$form.ShowDialog()
