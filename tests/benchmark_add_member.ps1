$Iterations = 5000

Write-Host "Running Benchmark with $Iterations iterations..." -ForegroundColor Cyan

# Baseline Measurement
$baselineTime = Measure-Command {
    1..$Iterations | ForEach-Object {
        $obj = [PSCustomObject]@{
            Name = "Test"
            Value = 123
        }
        $obj | Add-Member -MemberType NoteProperty -Name "nsfw_bypass" -Value $true -Force
        $obj | Add-Member -MemberType NoteProperty -Name "nsfw_disabled" -Value $true -Force
        $obj | Add-Member -MemberType NoteProperty -Name "bypass_safety_check" -Value $true -Force
        $obj | Add-Member -MemberType NoteProperty -Name "safety_check_threshold" -Value 9999.0 -Force
        $obj | Add-Member -MemberType NoteProperty -Name "STARK_MARKER" -Value "STARK-Surgical" -Force
    }
}

Write-Host "Baseline (Multiple Add-Member): $($baselineTime.TotalMilliseconds) ms" -ForegroundColor Yellow

# Optimized Measurement
$optimizedTime = Measure-Command {
    1..$Iterations | ForEach-Object {
        $obj = [PSCustomObject]@{
            Name = "Test"
            Value = 123
        }
        $obj | Add-Member -NotePropertyMembers @{
            "nsfw_bypass" = $true
            "nsfw_disabled" = $true
            "bypass_safety_check" = $true
            "safety_check_threshold" = 9999.0
            "STARK_MARKER" = "STARK-Surgical"
        } -Force
    }
}

Write-Host "Optimized (Single Add-Member): $($optimizedTime.TotalMilliseconds) ms" -ForegroundColor Green

$improvement = $baselineTime.TotalMilliseconds - $optimizedTime.TotalMilliseconds
$percent = ($improvement / $baselineTime.TotalMilliseconds) * 100

Write-Host "Improvement: $($percent.ToString("F2"))%" -ForegroundColor White
