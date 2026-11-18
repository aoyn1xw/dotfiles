# Bootstrap GitHub Codespaces + Android ADB tooling on Windows without administrator rights.
# Installs portable GitHub CLI and Android SDK Platform-Tools under the current user's profile.
# Run in PowerShell 7 or Windows PowerShell 5.1. No elevation required.
param([switch]$SkipGitHubCli, [switch]$SkipAdb)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$root = Join-Path $env:LOCALAPPDATA 'CodespacesAdbTools'
$bin = Join-Path $root 'bin'
New-Item -ItemType Directory -Force -Path $bin | Out-Null

function Add-UserPath([string]$path) {
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  $parts = @($userPath -split ';' | Where-Object { $_ })
  if ($parts -notcontains $path) {
    [Environment]::SetEnvironmentVariable('Path', (($parts + $path) -join ';'), 'User')
  }
  if (($env:Path -split ';') -notcontains $path) { $env:Path += ";$path" }
}
function Download-Zip([string]$url, [string]$destination) {
  Write-Host "Downloading $url"
  Invoke-WebRequest -Uri $url -OutFile $destination -UseBasicParsing
}
function Install-Gh {
  if (Get-Command gh -ErrorAction SilentlyContinue) {
    Write-Host "GitHub CLI already installed: $((Get-Command gh).Source)"
    return
  }
  $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/cli/cli/releases/latest' -Headers @{ 'User-Agent' = 'codespaces-adb-bootstrap' }
  # PROCESSOR_ARCHITEW6432 identifies the native architecture for 32-bit PowerShell on 64-bit Windows.
  $arch = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
  if (-not $arch) { throw 'Could not determine Windows CPU architecture.' }
  $suffix = if ($arch -eq 'Arm64') { 'windows_arm64.zip' } elseif ($arch -eq 'X64') { 'windows_amd64.zip' } else { throw "Unsupported Windows architecture: $arch" }
  $asset = $release.assets | Where-Object { $_.name -and $_.name.EndsWith($suffix, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
  if (-not $asset) { throw "Could not find GitHub CLI ZIP for $arch." }
  $zip = Join-Path $env:TEMP ([guid]::NewGuid().ToString() + '.zip')
  $dir = Join-Path $env:TEMP ([guid]::NewGuid().ToString())
  try {
    Download-Zip $asset.browser_download_url $zip
    Expand-Archive -LiteralPath $zip -DestinationPath $dir -Force
    $exe = Get-ChildItem -Path $dir -Filter gh.exe -Recurse -File | Select-Object -First 1
    if (-not $exe) { throw 'GitHub CLI ZIP did not contain gh.exe.' }
    Copy-Item -LiteralPath $exe.FullName -Destination (Join-Path $bin 'gh.exe') -Force
  } finally {
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
  }
  Write-Host 'Installed portable GitHub CLI.'
}
function Install-Adb {
  if (Get-Command adb -ErrorAction SilentlyContinue) {
    Write-Host "ADB already installed: $((Get-Command adb).Source)"
    return
  }
  $zip = Join-Path $env:TEMP ([guid]::NewGuid().ToString() + '.zip')
  $dir = Join-Path $env:TEMP ([guid]::NewGuid().ToString())
  try {
    Download-Zip 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip' $zip
    Expand-Archive -LiteralPath $zip -DestinationPath $dir -Force
    foreach ($name in @('adb.exe','AdbWinApi.dll','AdbWinUsbApi.dll')) {
      $source = Join-Path (Join-Path $dir 'platform-tools') $name
      if (-not (Test-Path $source)) { throw "Platform-Tools archive missing $name." }
      Copy-Item -LiteralPath $source -Destination (Join-Path $bin $name) -Force
    }
  } finally {
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
  }
  Write-Host 'Installed portable Android ADB.'
}
try {
  if (-not $SkipGitHubCli) { Install-Gh }
  if (-not $SkipAdb) { Install-Adb }
  Add-UserPath $bin
  Write-Host ''
  Write-Host 'Tool verification:'
  & gh --version | Select-Object -First 1
  & adb version | Select-Object -First 2
  if (Get-Command ssh -ErrorAction SilentlyContinue) {
    Write-Host "OpenSSH available: $((Get-Command ssh).Source)"
  } else {
    Write-Warning 'OpenSSH client not found. The tunnel needs ssh.exe; ask your administrator if Windows Optional Features are locked.'
  }
  Write-Host ''
  Write-Host 'Next: gh auth login'
  Write-Host 'Then: gh auth refresh -h github.com -s codespace'
  Write-Host 'Start the tunnel from a local checkout of this dotfiles repository:'
  Write-Host '  .\scripts\start-codespace-adb-tunnel.ps1 -Codespace YOUR_CODESPACE_NAME'
  Write-Host 'No device pairing or SSH tunnel was started automatically.'
} catch {
  Write-Host "Bootstrap failed: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "Location: $($_.InvocationInfo.PositionMessage)" -ForegroundColor Red
  Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
  exit 1
}
