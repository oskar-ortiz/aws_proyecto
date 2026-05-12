<#
.SYNOPSIS
  Adds ALB listener rules so /dashboard and /dashboard/* forward to the EC2 target group.

.DESCRIPTION
  Does not modify aws_cli_deploy.ps1.

  El nombre del ALB en tu cuenta puede ser university-enrollment-20-alb (sufijo numérico).
  Si no pasas -LoadBalancerName, se intenta ${ProjectName}-alb y luego se busca *${ProjectName}*-alb.

  Requires: AWS CLI, elbv2:DescribeLoadBalancers / DescribeRules / CreateRule.
#>
param(
    [string]$AwsRegion = "us-east-1",
    [string]$ProjectName = "university-enrollment",
    [string]$LoadBalancerName = ""
)

$ErrorActionPreference = "Stop"

function Invoke-AwsJson {
    param([string[]]$Arguments)
    $output = & aws @Arguments --output json | Out-String
    if ($LASTEXITCODE -ne 0) { throw "aws failed: $($Arguments -join ' ')" }
    if ([string]::IsNullOrWhiteSpace($output)) { return $null }
    return $output | ConvertFrom-Json
}

function Get-LoadBalancer {
    param([string]$Region, [string]$Project, [string]$Explicit)

    if ($Explicit) {
        $alb = Invoke-AwsJson @("elbv2", "describe-load-balancers", "--region", $Region, "--names", $Explicit)
        if ($alb.LoadBalancers.Count -lt 1) { throw "ALB '$Explicit' not found" }
        return $alb.LoadBalancers[0]
    }

    $tryExact = if ($Project.Length -le 24) { "${Project}-alb" } else { $Project.Substring(0, 24) }
    $raw = & aws elbv2 describe-load-balancers --region $Region --names $tryExact --output json 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($raw)) {
        $parsed = $raw | ConvertFrom-Json
        if ($parsed.LoadBalancers.Count -ge 1) {
            Write-Host "Using ALB: $($parsed.LoadBalancers[0].LoadBalancerName)" -ForegroundColor Green
            return $parsed.LoadBalancers[0]
        }
    }

    Write-Host "Exact name '$tryExact' not found. Searching *${Project}* ..." -ForegroundColor Yellow
    $all = Invoke-AwsJson @("elbv2", "describe-load-balancers", "--region", $Region)
    $rx = "^$([regex]::Escape($Project)).*-alb$"
    $hits = @($all.LoadBalancers | Where-Object { $_.LoadBalancerName -match $rx })
    if ($hits.Count -eq 0) {
        Write-Host "Load balancers in $Region :" -ForegroundColor Yellow
        $all.LoadBalancers | ForEach-Object { Write-Host "  $($_.LoadBalancerName)" }
        throw "No ALB matching pattern '$rx'. Pass -LoadBalancerName 'nombre-real-del-alb'."
    }
    if ($hits.Count -gt 1) {
        Write-Warning "Multiple ALBs matched project prefix; using: $($hits[0].LoadBalancerName)"
    } else {
        Write-Host "Using ALB: $($hits[0].LoadBalancerName)" -ForegroundColor Green
    }
    return $hits[0]
}

function Get-Ec2TargetGroupArnFromListenerRules {
    param($Rules)

    $arnSet = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($rule in $Rules.Rules) {
        foreach ($action in $rule.Actions) {
            if ($action.Type -eq "forward" -and $action.TargetGroupArn) {
                [void]$arnSet.Add($action.TargetGroupArn)
            }
        }
    }
    if ($arnSet.Count -eq 0) { throw "No forward actions found on listener rules" }

    $arnList = @($arnSet)
    $awsArgs = @("elbv2", "describe-target-groups", "--region", $AwsRegion)
    $awsArgs += "--target-group-arns"
    foreach ($a in $arnList) {
        $awsArgs += $a
    }
    $tgs = Invoke-AwsJson $awsArgs

    $ec2Tg = @($tgs.TargetGroups | Where-Object { $_.TargetType -eq "instance" -and $_.Port -eq 80 }) | Select-Object -First 1
    if (-not $ec2Tg) {
        throw "No instance:80 target group among listener forward targets. ARN candidates: $($arnList -join ', ')"
    }
    return $ec2Tg.TargetGroupArn
}

$lb = Get-LoadBalancer -Region $AwsRegion -Project $ProjectName -Explicit $LoadBalancerName
$albArn = $lb.LoadBalancerArn

$listeners = Invoke-AwsJson @("elbv2", "describe-listeners", "--region", $AwsRegion, "--load-balancer-arn", $albArn)
$http = $listeners.Listeners | Where-Object { $_.Port -eq 80 } | Select-Object -First 1
if (-not $http) { throw "HTTP listener on port 80 not found" }
$listenerArn = $http.ListenerArn

$rules = Invoke-AwsJson @("elbv2", "describe-rules", "--region", $AwsRegion, "--listener-arn", $listenerArn)
foreach ($rule in $rules.Rules) {
    foreach ($cond in $rule.Conditions) {
        if ($cond.Field -eq "path-pattern") {
            foreach ($v in @($cond.Values)) {
                if ($v -like "/dashboard*") {
                    Write-Host "Rule for dashboard already exists (priority $($rule.Priority)). Nothing to do." -ForegroundColor Green
                    exit 0
                }
            }
        }
    }
}

$ec2TgArn = Get-Ec2TargetGroupArnFromListenerRules -Rules $rules

$used = [System.Collections.Generic.HashSet[int]]::new()
foreach ($rule in $rules.Rules) {
    if ($rule.Priority -ne "default") { [void]$used.Add([int]$rule.Priority) }
}
$priority = 15
while ($used.Contains($priority)) { $priority++ }

Write-Host "ALB: $($lb.LoadBalancerName)" -ForegroundColor Cyan
Write-Host "Creating listener rule priority $priority -> $ec2TgArn" -ForegroundColor Cyan
& aws elbv2 create-rule `
    --region $AwsRegion `
    --listener-arn $listenerArn `
    --priority $priority `
    --conditions "Field=path-pattern,Values='/dashboard','/dashboard/*'" `
    --actions "Type=forward,TargetGroupArn=$ec2TgArn"

if ($LASTEXITCODE -ne 0) { throw "create-rule failed" }
Write-Host "Done. Open: http://$($lb.DNSName)/dashboard/" -ForegroundColor Green
