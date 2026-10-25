[CmdletBinding()]
param(
	[int]$InterfaceIndex = 0,
	[string]$LogPath = ""
)

$ErrorActionPreference = 'Stop'
$deviceAddress = '192.168.7.1'
$devicePrefix = 24
$devicePeer = '192.168.7.2'
$udpPort = 5140
$firewallRuleName = 'SweetSuryaLiveUdp5140'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
	throw 'Run this script from an Administrator PowerShell window.'
}

$adapters = @(Get-NetAdapter -IncludeHidden | Sort-Object ifIndex)
if ($InterfaceIndex -eq 0) {
	$adapters | Format-Table ifIndex, Name, InterfaceDescription, Status -AutoSize
	$InterfaceIndex = [int](Read-Host 'Enter the ifIndex for Sweet iOS USB Ethernet')
}

$adapter = Get-NetAdapter -IncludeHidden -InterfaceIndex $InterfaceIndex -ErrorAction Stop
if (($adapter.Name + ' ' + $adapter.InterfaceDescription) -notmatch '(?i)USB|Sweet|ECM') {
	throw "Adapter '$($adapter.Name)' does not look like the Sweet USB Ethernet interface. No changes were made."
}

Write-Host "Selected $($adapter.Name) [$($adapter.InterfaceDescription)] (ifIndex $InterfaceIndex)"
$answer = Read-Host 'Assign 192.168.7.1/24 and listen for UDP logs on port 5140? [y/N]'
if ($answer -notmatch '(?i)^y(es)?$') {
	Write-Host 'Cancelled.'
	exit 0
}

if ([string]::IsNullOrWhiteSpace($LogPath)) {
	$repoRoot = Split-Path -Parent $PSScriptRoot
	$logDirectory = Join-Path $repoRoot 'xnu/out'
	New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
	$LogPath = Join-Path $logDirectory ('surya-usb-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
}

$addressExisted = @(Get-NetIPAddress -InterfaceIndex $InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
	Where-Object { $_.IPAddress -eq $deviceAddress }).Count -gt 0
$ruleExisted = @(Get-NetFirewallRule -Name $firewallRuleName -ErrorAction SilentlyContinue).Count -gt 0
$udp = $null
$writer = $null

try {
	if (-not $addressExisted) {
		New-NetIPAddress -InterfaceIndex $InterfaceIndex -IPAddress $deviceAddress -PrefixLength $devicePrefix -AddressFamily IPv4 | Out-Null
	}
	if (-not $ruleExisted) {
		New-NetFirewallRule -Name $firewallRuleName -DisplayName 'Temporary Sweet iOS UDP log capture' `
			-Direction Inbound -Action Allow -Protocol UDP -LocalPort $udpPort `
			-RemoteAddress $devicePeer -Profile Any | Out-Null
	}

	$udp = New-Object System.Net.Sockets.UdpClient($udpPort)
	$writer = [System.IO.StreamWriter]::new($LogPath, $true, [System.Text.UTF8Encoding]::new($false))
	$writer.AutoFlush = $true
	Write-Host "Listening on 0.0.0.0:$udpPort; saving logs to $LogPath"
	Write-Host 'Keep this window open. Press Ctrl+C to stop.'

	while ($true) {
		$remote = [System.Net.IPEndPoint]::new([System.Net.IPAddress]::Any, 0)
		$packet = $udp.Receive([ref]$remote)
		$text = [System.Text.Encoding]::UTF8.GetString($packet)
		[Console]::Write($text)
		$writer.Write($text)
	}
}
finally {
	if ($null -ne $writer) { $writer.Dispose() }
	if ($null -ne $udp) { $udp.Dispose() }
	if (-not $ruleExisted) {
		Remove-NetFirewallRule -Name $firewallRuleName -ErrorAction SilentlyContinue
	}
	if (-not $addressExisted) {
		Get-NetIPAddress -InterfaceIndex $InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
			Where-Object { $_.IPAddress -eq $deviceAddress } |
			Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
	}
}
