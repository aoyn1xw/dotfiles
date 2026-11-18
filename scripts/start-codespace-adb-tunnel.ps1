# Start a localhost-only reverse ADB tunnel from Windows into a GitHub Codespace.
# Requires gh, ssh, and adb on Windows; SSH server feature in the Codespace.
param(
  [Parameter(Mandatory = $true)]
  [string]$Codespace,
  [int]$RemotePort = 15037
)
$ErrorActionPreference = 'Stop'
foreach ($cmd in @('gh', 'ssh', 'adb')) {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
    throw "Missing required command: $cmd"
  }
}
if ($RemotePort -lt 1024 -or $RemotePort -gt 65535) {
  throw 'RemotePort must be between 1024 and 65535.'
}
& adb start-server
if ($LASTEXITCODE -ne 0) { throw 'Failed to start local ADB server.' }
$config = Join-Path ([System.IO.Path]::GetTempPath()) ("bne-codespace-ssh-" + [guid]::NewGuid().ToString('N') + ".config")
try {
  $lines = @(& gh codespace ssh -c $Codespace --config)
  if ($LASTEXITCODE -ne 0 -or -not $lines) { throw 'Could not retrieve Codespace SSH configuration.' }
  $hostLine = $lines | Where-Object { $_ -match '^Host\s+\S+' } | Select-Object -First 1
  if (-not $hostLine) { throw 'Codespace SSH configuration did not contain a Host entry.' }
  $alias = ($hostLine -split '\s+')[1]
  [System.IO.File]::WriteAllLines($config, [string[]]$lines, [System.Text.UTF8Encoding]::new($false))
  Write-Host "Forwarding Codespace localhost:$RemotePort to Windows localhost:5037."
  Write-Host 'Leave this terminal open. Press Ctrl+C to stop the tunnel.'
  & ssh -F $config -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -N -R "127.0.0.1:${RemotePort}:127.0.0.1:5037" $alias
  if ($LASTEXITCODE -ne 0) { throw "SSH tunnel exited with code $LASTEXITCODE." }
}
finally {
  Remove-Item -LiteralPath $config -Force -ErrorAction SilentlyContinue
}
