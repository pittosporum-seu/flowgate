$ErrorActionPreference = 'Stop'

$InstallRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$DataRoot = Join-Path $env:LOCALAPPDATA 'TrojanSubVPN'
$RuntimeDir = Join-Path $DataRoot 'runtime'
$SettingsPath = Join-Path $DataRoot 'settings.json'
$NodesPath = Join-Path $DataRoot 'nodes.json'
$ConfigPath = Join-Path $RuntimeDir 'sing-box-config.json'
$PidPath = Join-Path $RuntimeDir 'sing-box.pid'
$ProxyStatePath = Join-Path $RuntimeDir 'proxy-state.json'
$SingBoxExe = Join-Path $InstallRoot 'bin\sing-box.exe'
$ProxyListen = '127.0.0.1'
$ProxyPort = 10808

function Ensure-Dirs {
    New-Item -ItemType Directory -Force -Path $DataRoot, $RuntimeDir | Out-Null
}

function Read-JsonFile($Path, $Default) {
    if (-not (Test-Path -LiteralPath $Path)) { return $Default }
    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) { return $Default }
    return ($raw | ConvertFrom-Json)
}

function Write-JsonFile($Path, $Value) {
    $json = $Value | ConvertTo-Json -Depth 32
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($Path, $json, $utf8NoBom)
}

function Wait-Enter {
    [void](Read-Host 'Press Enter to continue')
}

function First-NonEmpty {
    foreach ($item in $args) {
        if (-not [string]::IsNullOrWhiteSpace([string]$item)) { return [string]$item }
    }
    return $null
}

function Get-QueryMap([string]$Query) {
    $map = @{}
    if ([string]::IsNullOrWhiteSpace($Query)) { return $map }
    $pairs = $Query.TrimStart('?') -split '&'
    foreach ($pair in $pairs) {
        if ([string]::IsNullOrWhiteSpace($pair)) { continue }
        $parts = $pair -split '=', 2
        $key = [Uri]::UnescapeDataString($parts[0].Replace('+', ' '))
        $value = ''
        if ($parts.Count -gt 1) { $value = [Uri]::UnescapeDataString($parts[1].Replace('+', ' ')) }
        if (-not [string]::IsNullOrWhiteSpace($key)) { $map[$key] = $value }
    }
    return $map
}

function Get-QueryValue($Map, [string[]]$Names) {
    foreach ($name in $Names) {
        if ($Map.ContainsKey($name) -and -not [string]::IsNullOrWhiteSpace([string]$Map[$name])) {
            return [string]$Map[$name]
        }
    }
    return $null
}

function Get-QueryBool($Map, [string[]]$Names) {
    $value = Get-QueryValue $Map $Names
    if ([string]::IsNullOrWhiteSpace($value)) { return $false }
    return @('1', 'true', 'yes', 'y') -contains $value.ToLowerInvariant()
}

function Decode-Base64Text([string]$Text) {
    $compact = ($Text -replace '\s', '').Trim()
    if ([string]::IsNullOrWhiteSpace($compact)) { return $null }
    $compact = $compact.Replace('-', '+').Replace('_', '/')
    $pad = (4 - ($compact.Length % 4)) % 4
    if ($pad -gt 0) { $compact = $compact + ('=' * $pad) }
    try {
        $bytes = [Convert]::FromBase64String($compact)
        return [Text.Encoding]::UTF8.GetString($bytes)
    } catch {
        return $null
    }
}

function Get-TrojanLinks([string]$Content) {
    $text = $Content
    if ($text -notmatch '(?i)trojan://') {
        $decoded = Decode-Base64Text $text
        if ($decoded -and $decoded -match '(?i)trojan://') { $text = $decoded }
    }

    $matches = [regex]::Matches($text, '(?i)trojan://[^\s<>"'']+')
    $seen = @{}
    $links = New-Object System.Collections.Generic.List[string]
    foreach ($match in $matches) {
        $link = $match.Value.Trim()
        if (-not $seen.ContainsKey($link)) {
            $seen[$link] = $true
            $links.Add($link) | Out-Null
        }
    }
    return $links.ToArray()
}

function Parse-TrojanUri([string]$Link) {
    try {
        $uri = [Uri]$Link
        if ($uri.Scheme.ToLowerInvariant() -ne 'trojan') { return $null }
        if ([string]::IsNullOrWhiteSpace($uri.Host) -or $uri.Port -le 0) { return $null }

        $query = Get-QueryMap $uri.Query
        $name = $null
        if (-not [string]::IsNullOrWhiteSpace($uri.Fragment)) {
            $name = [Uri]::UnescapeDataString($uri.Fragment.TrimStart('#').Replace('+', ' '))
        }
        if ([string]::IsNullOrWhiteSpace($name)) { $name = "$($uri.Host):$($uri.Port)" }

        $network = First-NonEmpty (Get-QueryValue $query @('type', 'network')) 'tcp'
        $path = First-NonEmpty (Get-QueryValue $query @('path')) '/'
        $hostHeader = Get-QueryValue $query @('host', 'headers.Host')
        $sni = First-NonEmpty (Get-QueryValue $query @('sni', 'peer')) $hostHeader $uri.Host
        $alpnRaw = Get-QueryValue $query @('alpn')
        $alpn = @()
        if (-not [string]::IsNullOrWhiteSpace($alpnRaw)) {
            $alpn = @($alpnRaw -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        }

        return [pscustomobject][ordered]@{
            name = $name
            server = $uri.Host
            port = [int]$uri.Port
            password = [Uri]::UnescapeDataString($uri.UserInfo)
            sni = $sni
            insecure = [bool](Get-QueryBool $query @('allowInsecure', 'allowinsecure', 'insecure', 'skip-cert-verify'))
            network = $network.ToLowerInvariant()
            path = $path
            hostHeader = $hostHeader
            alpn = $alpn
            raw = $Link
        }
    } catch {
        return $null
    }
}

function Get-Settings {
    $settings = Read-JsonFile $SettingsPath ([pscustomobject]@{ subscriptionUrl = ''; selectedIndex = 0 })
    if ($null -eq $settings.subscriptionUrl) { $settings | Add-Member -NotePropertyName subscriptionUrl -NotePropertyValue '' }
    if ($null -eq $settings.selectedIndex) { $settings | Add-Member -NotePropertyName selectedIndex -NotePropertyValue 0 }
    return $settings
}

function Save-Settings($Settings) {
    Write-JsonFile $SettingsPath $Settings
}

function Get-Nodes {
    $nodes = Read-JsonFile $NodesPath @()
    if ($null -eq $nodes) { return @() }
    if ($nodes -is [array]) { return @($nodes) }
    return @($nodes)
}

function Save-Nodes($Nodes) {
    Write-JsonFile $NodesPath @($Nodes)
}

function Refresh-Subscription([switch]$ForcePrompt) {
    Ensure-Dirs
    $settings = Get-Settings
    $url = [string]$settings.subscriptionUrl
    if ($ForcePrompt -or [string]::IsNullOrWhiteSpace($url)) {
        $inputUrl = Read-Host 'Paste subscription URL'
        if ([string]::IsNullOrWhiteSpace($inputUrl)) {
            Write-Host 'Subscription URL was not changed.'
            return
        }
        $url = $inputUrl.Trim()
        $settings.subscriptionUrl = $url
        Save-Settings $settings
    }

    Write-Host "Fetching subscription..."
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
    $response = Invoke-WebRequest -UseBasicParsing -Uri $url -Headers @{ 'User-Agent' = 'TrojanSubVPN/1.0' }
    $links = Get-TrojanLinks ([string]$response.Content)
    $nodes = New-Object System.Collections.Generic.List[object]
    foreach ($link in $links) {
        $node = Parse-TrojanUri $link
        if ($null -ne $node -and -not [string]::IsNullOrWhiteSpace($node.password)) {
            $nodes.Add($node) | Out-Null
        }
    }

    if ($nodes.Count -eq 0) {
        throw 'No trojan:// nodes were found. This simplified build supports link/base64 subscriptions that contain trojan:// entries.'
    }

    Save-Nodes $nodes.ToArray()
    if ([int]$settings.selectedIndex -ge $nodes.Count) { $settings.selectedIndex = 0 }
    Save-Settings $settings
    Write-Host ("Loaded {0} Trojan node(s)." -f $nodes.Count)
}

function Select-Node {
    Ensure-Dirs
    $nodes = Get-Nodes
    if ($nodes.Count -eq 0) {
        Write-Host 'No nodes cached yet. Refresh subscription first.'
        return
    }

    $limit = [Math]::Min($nodes.Count, 50)
    Write-Host ''
    for ($i = 0; $i -lt $limit; $i++) {
        $node = $nodes[$i]
        Write-Host ("{0,3}. {1}  [{2}:{3}]" -f ($i + 1), $node.name, $node.server, $node.port)
    }
    if ($nodes.Count -gt $limit) {
        Write-Host ("Showing first {0} of {1} nodes." -f $limit, $nodes.Count)
    }
    $choice = Read-Host 'Choose node number'
    $index = 0
    if (-not [int]::TryParse($choice, [ref]$index) -or $index -lt 1 -or $index -gt $nodes.Count) {
        Write-Host 'Invalid selection.'
        return
    }
    $settings = Get-Settings
    $settings.selectedIndex = $index - 1
    Save-Settings $settings
    Write-Host ("Selected: {0}" -f $nodes[$index - 1].name)
}

function New-SingBoxConfig($Node) {
    $tls = [ordered]@{
        enabled = $true
        server_name = [string]$Node.sni
        insecure = [bool]$Node.insecure
    }
    if ($Node.alpn -and $Node.alpn.Count -gt 0) { $tls.alpn = @($Node.alpn) }

    $outbound = [ordered]@{
        type = 'trojan'
        tag = 'proxy'
        server = [string]$Node.server
        server_port = [int]$Node.port
        password = [string]$Node.password
        tls = $tls
    }

    if ([string]$Node.network -eq 'ws') {
        $transport = [ordered]@{
            type = 'ws'
            path = (First-NonEmpty ([string]$Node.path) '/')
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$Node.hostHeader)) {
            $transport.headers = [ordered]@{ Host = [string]$Node.hostHeader }
        }
        $outbound.transport = $transport
    }

    return [ordered]@{
        log = [ordered]@{
            disabled = $false
            level = 'info'
            timestamp = $true
        }
        inbounds = @(
            [ordered]@{
                type = 'mixed'
                tag = 'mixed-in'
                listen = $ProxyListen
                listen_port = $ProxyPort
            }
        )
        outbounds = @(
            $outbound,
            [ordered]@{
                type = 'direct'
                tag = 'direct'
            }
        )
        route = [ordered]@{
            final = 'proxy'
            auto_detect_interface = $true
        }
    }
}

function Get-ProxyKeyPath {
    return 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
}

function Notify-ProxyChanged {
    try {
        if (-not ('WinInetNotify' -as [type])) {
            Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class WinInetNotify {
    [DllImport("wininet.dll", SetLastError=true)]
    public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);
}
'@
        }
        [void][WinInetNotify]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0)
        [void][WinInetNotify]::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0)
    } catch {
        Write-Host 'Proxy changed. Some apps may need restart to pick it up.'
    }
}

function Save-ProxyState {
    if (Test-Path -LiteralPath $ProxyStatePath) { return }
    $key = Get-ProxyKeyPath
    $current = Get-ItemProperty -Path $key
    $state = [ordered]@{
        ProxyEnable = [int](First-NonEmpty $current.ProxyEnable 0)
        ProxyServer = [string](First-NonEmpty $current.ProxyServer '')
        ProxyOverride = [string](First-NonEmpty $current.ProxyOverride '')
    }
    Write-JsonFile $ProxyStatePath $state
}

function Enable-SystemProxy {
    Save-ProxyState
    $key = Get-ProxyKeyPath
    Set-ItemProperty -Path $key -Name ProxyEnable -Value 1
    Set-ItemProperty -Path $key -Name ProxyServer -Value ("http={0}:{1};https={0}:{1};socks={0}:{1}" -f $ProxyListen, $ProxyPort)
    Set-ItemProperty -Path $key -Name ProxyOverride -Value '<local>'
    Notify-ProxyChanged
}

function Restore-SystemProxy {
    $key = Get-ProxyKeyPath
    if (Test-Path -LiteralPath $ProxyStatePath) {
        $state = Read-JsonFile $ProxyStatePath $null
        if ($null -ne $state) {
            Set-ItemProperty -Path $key -Name ProxyEnable -Value ([int]$state.ProxyEnable)
            if ([string]::IsNullOrEmpty([string]$state.ProxyServer)) {
                Remove-ItemProperty -Path $key -Name ProxyServer -ErrorAction SilentlyContinue
            } else {
                Set-ItemProperty -Path $key -Name ProxyServer -Value ([string]$state.ProxyServer)
            }
            if ([string]::IsNullOrEmpty([string]$state.ProxyOverride)) {
                Remove-ItemProperty -Path $key -Name ProxyOverride -ErrorAction SilentlyContinue
            } else {
                Set-ItemProperty -Path $key -Name ProxyOverride -Value ([string]$state.ProxyOverride)
            }
        }
        Remove-Item -LiteralPath $ProxyStatePath -Force -ErrorAction SilentlyContinue
    } else {
        Set-ItemProperty -Path $key -Name ProxyEnable -Value 0
    }
    Notify-ProxyChanged
}

function Get-RunningProcess {
    if (-not (Test-Path -LiteralPath $PidPath)) { return $null }
    $pidText = (Get-Content -LiteralPath $PidPath -Raw).Trim()
    $pidValue = 0
    if (-not [int]::TryParse($pidText, [ref]$pidValue)) { return $null }
    try {
        $process = Get-Process -Id $pidValue -ErrorAction Stop
        return $process
    } catch {
        return $null
    }
}

function Stop-CoreProcess {
    $process = Get-RunningProcess
    if ($null -ne $process) {
        try {
            Stop-Process -Id $process.Id -Force -ErrorAction Stop
        } catch {
            Write-Host "Failed to stop process $($process.Id): $($_.Exception.Message)"
        }
    }
    Remove-Item -LiteralPath $PidPath -Force -ErrorAction SilentlyContinue
}

function Start-Proxy {
    Ensure-Dirs
    if (-not (Test-Path -LiteralPath $SingBoxExe)) {
        throw "sing-box.exe was not found: $SingBoxExe"
    }

    $nodes = Get-Nodes
    if ($nodes.Count -eq 0) {
        Refresh-Subscription
        $nodes = Get-Nodes
    }
    if ($nodes.Count -eq 0) { throw 'No nodes available.' }

    $settings = Get-Settings
    $index = [int]$settings.selectedIndex
    if ($index -lt 0 -or $index -ge $nodes.Count) { $index = 0 }
    $node = $nodes[$index]
    $config = New-SingBoxConfig $node
    Write-JsonFile $ConfigPath $config

    Write-Host 'Checking config...'
    $checkOutput = & $SingBoxExe check -c $ConfigPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        $checkText = ($checkOutput | Out-String).Trim()
        throw "sing-box config check failed: $checkText"
    }

    Stop-CoreProcess
    Enable-SystemProxy
    $args = @('run', '-c', $ConfigPath)
    $process = Start-Process -FilePath $SingBoxExe -ArgumentList $args -WorkingDirectory (Split-Path -Parent $SingBoxExe) -WindowStyle Hidden -PassThru
    Set-Content -LiteralPath $PidPath -Value ([string]$process.Id) -Encoding ASCII
    Start-Sleep -Seconds 1
    if ($process.HasExited) {
        Restore-SystemProxy
        Remove-Item -LiteralPath $PidPath -Force -ErrorAction SilentlyContinue
        throw 'sing-box exited immediately. Check the node or subscription.'
    }

    Write-Host ''
    Write-Host ("Running: {0}" -f $node.name)
    Write-Host ("System proxy: {0}:{1}" -f $ProxyListen, $ProxyPort)
}

function Stop-Proxy {
    Stop-CoreProcess
    Restore-SystemProxy
    Write-Host 'Stopped and restored previous Windows proxy settings.'
}

function Show-Status {
    Ensure-Dirs
    $nodes = Get-Nodes
    $settings = Get-Settings
    $process = Get-RunningProcess
    Write-Host ''
    if ($null -ne $process) {
        Write-Host ("Status: running, PID {0}" -f $process.Id)
    } else {
        Write-Host 'Status: stopped'
    }
    Write-Host ("Cached nodes: {0}" -f $nodes.Count)
    if ($nodes.Count -gt 0) {
        $index = [int]$settings.selectedIndex
        if ($index -lt 0 -or $index -ge $nodes.Count) { $index = 0 }
        Write-Host ("Selected: {0}" -f $nodes[$index].name)
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$settings.subscriptionUrl)) {
        Write-Host ("Subscription: {0}" -f $settings.subscriptionUrl)
    }
    Write-Host ''
}

function Open-DataFolder {
    Ensure-Dirs
    Start-Process explorer.exe $DataRoot
}

function Main-Menu {
    Ensure-Dirs
    while ($true) {
        Clear-Host
        Write-Host 'TrojanSubVPN - simplified Trojan subscription client'
        Write-Host 'Powered by sing-box. No nodes are bundled.'
        Show-Status
        Write-Host '1. Start proxy'
        Write-Host '2. Stop proxy'
        Write-Host '3. Refresh subscription'
        Write-Host '4. Change subscription URL'
        Write-Host '5. Select node'
        Write-Host '6. Open data folder'
        Write-Host '0. Exit'
        $choice = Read-Host 'Choose'
        try {
            switch ($choice) {
                '1' { Start-Proxy; Wait-Enter }
                '2' { Stop-Proxy; Wait-Enter }
                '3' { Refresh-Subscription; Wait-Enter }
                '4' { Refresh-Subscription -ForcePrompt; Wait-Enter }
                '5' { Select-Node; Wait-Enter }
                '6' { Open-DataFolder; Wait-Enter }
                '0' { return }
                default { Write-Host 'Unknown option.'; Wait-Enter }
            }
        } catch {
            Write-Host ''
            Write-Host ("Error: {0}" -f $_.Exception.Message)
            Wait-Enter
        }
    }
}

if ($env:TROJANSUBVPN_NO_MENU -ne '1') {
    Main-Menu
}
