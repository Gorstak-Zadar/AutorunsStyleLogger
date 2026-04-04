# Parity with GEDR JobAutorunsStyleLogger: enumerate Run keys + startup folders to NDJSON log.
$AgentsAvBin = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Bin'))
. (Join-Path $AgentsAvBin '_JobLog.ps1')

function Invoke-AutorunsStyleLogger {
    $logDir = "$env:ProgramData\Antivirus\Logs"
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    $ndjson = Join-Path $logDir 'autoruns_style.ndjson'
    try {
        $stamp = (Get-Date).ToString('o')
        $regRoots = @('HKLM:\Software\Microsoft\Windows\CurrentVersion\Run', 'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce')
        foreach ($rp in $regRoots) {
            if (-not (Test-Path $rp)) { continue }
            $p = Get-ItemProperty -Path $rp -ErrorAction SilentlyContinue
            foreach ($x in $p.PSObject.Properties) {
                if ($x.Name -match '^PS') { continue }
                $v = [string]$x.Value
                if ([string]::IsNullOrWhiteSpace($v)) { continue }
                $line = (@{ t = $stamp; kind = 'RunKey'; key = $rp; name = $x.Name; value = $v } | ConvertTo-Json -Compress -Depth 4)
                Add-Content -LiteralPath $ndjson -Value $line -Encoding UTF8
            }
        }
        $dirs = @(
            [Environment]::GetFolderPath('Startup'),
            [Environment]::GetFolderPath('CommonStartup')
        ) | Select-Object -Unique
        foreach ($d in $dirs) {
            if ([string]::IsNullOrWhiteSpace($d) -or -not (Test-Path -LiteralPath $d)) { continue }
            Get-ChildItem -LiteralPath $d -File -ErrorAction SilentlyContinue | ForEach-Object {
                $line = (@{ t = $stamp; kind = 'StartupFolder'; path = $_.FullName } | ConvertTo-Json -Compress)
                Add-Content -LiteralPath $ndjson -Value $line -Encoding UTF8
            }
        }
        Write-JobLog '[AutorunsStyleLogger] Snapshot appended to autoruns_style.ndjson' 'INFO' 'autoruns_style.log'
    } catch {
        Write-JobLog "[AutorunsStyleLogger] $_" 'ERROR' 'autoruns_style.log'
    }
}

if ($MyInvocation.InvocationName -ne '.') { Invoke-AutorunsStyleLogger }
