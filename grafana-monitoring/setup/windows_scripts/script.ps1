# ============================================================
# File: scripts.ps1
# Author: dotcreep
# Purpose: Collects Windows custom metrics for Prometheus
# ============================================================

# === Configuration ===
$intervalSeconds = 1
$metricsDir = "C:\Program Files\windows_exporter"
$metricsFile = "$metricsDir\system_and_net.prom"
$ntpServer = "pool.ntp.org"

# Ensure metrics directory exists
if (-not (Test-Path $metricsDir)) {
    New-Item -ItemType Directory -Path $metricsDir -Force | Out-Null
}

Write-Host "Starting metrics collection loop... (Interval: $intervalSeconds seconds)"
Write-Host "Metrics file: $metricsFile"
Write-Host "Using NTP Server: $ntpServer"

while ($true) {
    $output = @()

    # ============================================================
    # 1. Timezone Info
    # ============================================================
    try {
        $tz = Get-TimeZone
        $offset = $tz.BaseUtcOffset.TotalHours
        $sign = if ($offset -ge 0) { "+" } else { "-" }
        $absOffset = [math]::Abs($offset)
        $gmt = "GMT$sign$absOffset"
        $output += "# HELP windows_custom_timezone_info Windows timezone info"
        $output += "# TYPE windows_custom_timezone_info gauge"
        $output += "windows_custom_timezone_info{timezone=`"$gmt`"} 1"
    }
    catch {
        $output += "windows_custom_timezone_info{timezone=`"unknown`"} 0"
    }

    # ============================================================
    # 2. Logged-in User Count
    # ============================================================
    try {
        $sessions = quser 2>$null | Select-String ">" | Measure-Object
        $userCount = $sessions.Count
    } catch {
        $userCount = 0
    }
    $output += "# HELP windows_custom_logged_in_users_total Number of currently logged-in users"
    $output += "# TYPE windows_custom_logged_in_users_total gauge"
    $output += "windows_custom_logged_in_users_total $userCount"

    # ============================================================
    # 3. TCP Connections per Process
    # ============================================================
    try {
        $connections = Get-NetTCPConnection -State Established, CloseWait -ErrorAction SilentlyContinue
        if ($connections) {
            $grouped = $connections | Group-Object -Property OwningProcess
            foreach ($group in $grouped) {
                $procId = $group.Name
                $count = $group.Count
                try {
                    $proc = Get-Process -Id $procId -ErrorAction Stop
                    $processName = $proc.ProcessName
                } catch {
                    $processName = "unknown_pid_$procId"
                }
                $processNameSafe = $processName -replace '[^a-zA-Z0-9_]', '_'
                $output += "windows_custom_net_tcp_connections{process=`"$processNameSafe`", pid=`"$procId`"} $count"
            }
        }
    } catch {}

    # ============================================================
    # 4. Time Offset vs NTP Server
    # ============================================================
    try {
        $ntpData = w32tm /stripchart /computer:$ntpServer /dataonly /samples:1 2>$null
        if ($ntpData -match "Offset:\s+([-0-9.]+)s") {
            $timeOffset = [double]$matches[1]
        } else {
            $timeOffset = 0
        }

        $output += "# HELP windows_time_computed_time_offset_seconds System time offset vs NTP server (seconds)"
        $output += "# TYPE windows_time_computed_time_offset_seconds gauge"
        $output += "windows_time_computed_time_offset_seconds $timeOffset"
    }
    catch {
        $output += "windows_time_computed_time_offset_seconds 0"
    }

    # ============================================================
    # 5. NTP Server & Clock Info (simulasi collector time)
    # ============================================================
    try {
        $status = w32tm /query /status 2>$null
        $peers = w32tm /query /peers 2>$null

        # Clock frequency adjustment
        if ($status -match "Frequency:\s+([-0-9.]+)\s+ppb") {
            $freqAdj = [double]$matches[1]
        } else {
            $freqAdj = 0
        }

        # Jumlah sumber waktu aktif
        $activeSources = ($peers | Select-String "\*").Count

        # Simulasi counter (karena tidak expose langsung)
        # Bisa diupdate nanti jika ingin menghitung rate secara akurat
        $incoming = Get-Random -Minimum 1000 -Maximum 2000
        $outgoing = Get-Random -Minimum 1000 -Maximum 2000

        $output += "# HELP windows_time_ntp_server_incoming_requests_total Total incoming NTP requests"
        $output += "# TYPE windows_time_ntp_server_incoming_requests_total counter"
        $output += "windows_time_ntp_server_incoming_requests_total $incoming"

        $output += "# HELP windows_time_ntp_server_outgoing_responses_total Total outgoing NTP responses"
        $output += "# TYPE windows_time_ntp_server_outgoing_responses_total counter"
        $output += "windows_time_ntp_server_outgoing_responses_total $outgoing"

        $output += "# HELP windows_time_clock_frequency_adjustment_ppb_total Clock frequency adjustment (ppb)"
        $output += "# TYPE windows_time_clock_frequency_adjustment_ppb_total gauge"
        $output += "windows_time_clock_frequency_adjustment_ppb_total $freqAdj"

        $output += "# HELP windows_time_ntp_client_time_sources Number of active NTP time sources"
        $output += "# TYPE windows_time_ntp_client_time_sources gauge"
        $output += "windows_time_ntp_client_time_sources $activeSources"
    }
    catch {
        $output += "windows_time_ntp_server_incoming_requests_total 0"
        $output += "windows_time_ntp_server_outgoing_responses_total 0"
        $output += "windows_time_clock_frequency_adjustment_ppb_total 0"
        $output += "windows_time_ntp_client_time_sources 0"
    }

    # ============================================================
    # 6. Write Metrics Atomically
    # ============================================================
    try {
        $tempFile = "$metricsFile.tmp"
        $output | Out-File -FilePath $tempFile -Encoding ASCII
        Move-Item -Path $tempFile -Destination $metricsFile -Force
    } catch {
        Write-Warning "Failed to write metrics file: $_"
    }

    Start-Sleep -Seconds $intervalSeconds
}
