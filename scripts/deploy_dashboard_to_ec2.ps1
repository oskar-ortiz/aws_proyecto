<#
.SYNOPSIS
  Build Next export, sube artefactos a S3, y en instancias EC2 (SSM) descomprime en /opt/university/frontend/out
  y aplica nginx/nginx.conf del repo, luego nginx -t + reload.

.NOTAS
  - No modifica aws_cli_deploy.ps1.
  - No usa permisos S3 en el rol de EC2: descarga vía curl con URL prefirmada.
  - Requiere: AWS CLI autenticado, SSM en instancias (AmazonSSMManagedInstanceCore), salida HTTPS hacia S3.
#>
param(
    [string]$AwsRegion = "us-east-1",
    [string]$RepoRoot = "",
    [string]$DeploymentJsonPath = "",
    [string]$S3Bucket = "",
    [string]$AsgName = "",
    [string[]]$InstanceIds = @(),
    [switch]$SkipBuild,
    [switch]$CreateBucketIfMissing
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $RepoRoot) { $RepoRoot = Resolve-Path (Join-Path $scriptRoot "..") }
if (-not $DeploymentJsonPath) { $DeploymentJsonPath = Join-Path $scriptRoot "deployment-output.json" }

$frontendOut = Join-Path $RepoRoot "frontend\out"
$nginxConf = Join-Path $RepoRoot "nginx\nginx.conf"
$flaskApp = Join-Path $RepoRoot "app\backend\app.py"
$frontendDir = Join-Path $RepoRoot "frontend"

function Invoke-AwsText {
    param([string[]]$Arguments)
    $output = & aws @Arguments --output text | Out-String
    if ($LASTEXITCODE -ne 0) { throw "aws failed: aws $($Arguments -join ' ')" }
    return $output.Trim()
}

function Invoke-AwsJson {
    param([string[]]$Arguments)
    $output = & aws @Arguments --output json | Out-String
    if ($LASTEXITCODE -ne 0) { throw "aws failed: aws $($Arguments -join ' ')" }
    if ([string]::IsNullOrWhiteSpace($output)) { return $null }
    return $output | ConvertFrom-Json
}

Write-Host "==> FASE 1: validar frontend/out" -ForegroundColor Cyan
if (-not (Test-Path $frontendOut)) { throw "No existe $frontendOut" }
if (-not (Test-Path (Join-Path $frontendOut "index.html"))) { throw "Falta index.html en out/" }
if (-not (Test-Path (Join-Path $frontendOut "_next"))) { throw "Falta _next en out/" }
Write-Host "OK: out/ contiene build." -ForegroundColor Green

if (-not $SkipBuild) {
    Write-Host "==> FASE 2: npm run build (export)" -ForegroundColor Cyan
    $acct = (Invoke-AwsJson @("sts", "get-caller-identity")).Account
    $env:NEXT_PUBLIC_AWS_ACCOUNT_ID = $acct
    Push-Location $frontendDir
    try {
        if (Test-Path "package-lock.json") { npm ci } else { npm install }
        npm run build
    } finally {
        Pop-Location
    }
    Write-Host "OK: build generado." -ForegroundColor Green
} else {
    Write-Host "==> FASE 2: omitida (-SkipBuild)" -ForegroundColor Yellow
}

Write-Host "==> Resolver instancias (ASG o deployment-output.json)" -ForegroundColor Cyan
if (-not $AsgName -and (Test-Path $DeploymentJsonPath)) {
    $dep = Get-Content $DeploymentJsonPath -Raw | ConvertFrom-Json
    if ($dep.autoscaling.asg_name) {
        $AsgName = [string]$dep.autoscaling.asg_name
        Write-Host "ASG desde JSON: $AsgName" -ForegroundColor Gray
    }
}
if (-not $AsgName) {
    throw "Define -AsgName o coloca scripts\deployment-output.json con autoscaling.asg_name"
}

$liveIds = Invoke-AwsText @(
    "autoscaling", "describe-auto-scaling-groups",
    "--region", $AwsRegion,
    "--auto-scaling-group-names", $AsgName,
    "--query", "AutoScalingGroups[0].Instances[?LifecycleState=='InService'].InstanceId",
    "--output", "text"
)
$ids = @($liveIds -split "\s+" | Where-Object { $_ })
if ($InstanceIds.Count -gt 0) { $ids = $InstanceIds }
if ($ids.Count -eq 0) { throw "No hay instancias InService en ASG $AsgName" }
Write-Host "Instancias: $($ids -join ', ')" -ForegroundColor Green

Write-Host "==> FASE 3: empaquetar y subir a S3" -ForegroundColor Cyan
$account = (Invoke-AwsJson @("sts", "get-caller-identity")).Account
if (-not $S3Bucket) { $S3Bucket = "university-enrollment-dashboard-$account" }

$oldErrorAction = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$null = & aws s3api head-bucket --bucket $S3Bucket --region $AwsRegion 2>$null
$headCode = $LASTEXITCODE
$ErrorActionPreference = $oldErrorAction
if ($headCode -ne 0) {
    if (-not $CreateBucketIfMissing) {
        throw "Bucket $S3Bucket no existe. Crealo o pasa -CreateBucketIfMissing"
    }
    Write-Host "Creando bucket $S3Bucket ..." -ForegroundColor Yellow
    if ($AwsRegion -eq "us-east-1") {
        & aws s3api create-bucket --bucket $S3Bucket --region $AwsRegion
    } else {
        & aws s3api create-bucket --bucket $S3Bucket --region $AwsRegion --create-bucket-configuration "LocationConstraint=$AwsRegion"
    }
    if ($LASTEXITCODE -ne 0) { throw "No se pudo crear el bucket" }
}

$zipPath = Join-Path $env:TEMP ("dashboard-out-" + [guid]::NewGuid().ToString("N") + ".zip")
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Push-Location $frontendOut
try { tar -a -c -f $zipPath * } finally { Pop-Location }

$keyZip = "dashboard/site.zip"
$keyNginx = "dashboard/nginx.conf"
$keyFlask = "dashboard/flask-app.py"
& aws s3 cp $zipPath "s3://$S3Bucket/$keyZip" --region $AwsRegion
if ($LASTEXITCODE -ne 0) { throw "s3 cp zip fallo" }
& aws s3 cp $nginxConf "s3://$S3Bucket/$keyNginx" --region $AwsRegion
if ($LASTEXITCODE -ne 0) { throw "s3 cp nginx fallo" }
& aws s3 cp $flaskApp "s3://$S3Bucket/$keyFlask" --region $AwsRegion
if ($LASTEXITCODE -ne 0) { throw "s3 cp flask fallo" }

$zipUrl = Invoke-AwsText @("s3", "presign", "s3://$S3Bucket/$keyZip", "--region", $AwsRegion, "--expires-in", "7200")
$nginxUrl = Invoke-AwsText @("s3", "presign", "s3://$S3Bucket/$keyNginx", "--region", $AwsRegion, "--expires-in", "7200")
$flaskUrl = Invoke-AwsText @("s3", "presign", "s3://$S3Bucket/$keyFlask", "--region", $AwsRegion, "--expires-in", "7200")
Write-Host "URLs prefirmadas (7200s)." -ForegroundColor Green

Write-Host "==> FASE 4-5: SSM - instalar unzip, sitio, nginx, Flask, reload" -ForegroundColor Cyan
$bash = @"
set -euxo pipefail; sudo mkdir -p /opt/university/frontend/out; sudo dnf install -y unzip; sudo rm -rf /opt/university/frontend/out/*; curl -fsSL '$zipUrl' -o /tmp/dashboard-site.zip; sudo unzip -qo /tmp/dashboard-site.zip -d /opt/university/frontend/out/; curl -fsSL '$nginxUrl' | sudo tee /etc/nginx/nginx.conf >/dev/null; curl -fsSL '$flaskUrl' | sudo tee /opt/university/app/app.py >/dev/null; sudo nginx -t; sudo systemctl reload nginx; sudo systemctl restart university-backend; echo DASHBOARD_DEPLOY_OK
"@

$paramPath = Join-Path $env:TEMP ("ssm-dashboard-" + [guid]::NewGuid().ToString("N") + ".json")
$payload = @{ commands = @($bash) } | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($paramPath, $payload, [System.Text.UTF8Encoding]::new($false))

$paramUri = "file://$paramPath"
$sendArgs = @(
    "ssm", "send-command",
    "--region", $AwsRegion,
    "--document-name", "AWS-RunShellScript",
    "--comment", "Deploy Next dashboard + nginx",
    "--parameters", $paramUri,
    "--output", "json",
    "--instance-ids"
) + $ids

$sendOut = & aws @sendArgs | Out-String
if ($LASTEXITCODE -ne 0) { throw "ssm send-command fallo: $sendOut" }
$sendJson = $sendOut | ConvertFrom-Json
$cmdId = $sendJson.Command.CommandId
Write-Host "SSM CommandId: $cmdId" -ForegroundColor Cyan
Remove-Item $paramPath -Force -ErrorAction SilentlyContinue
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "==> FASE 6: comprobar resultado (espera ~60s y ejecuta):" -ForegroundColor Yellow
Write-Host "aws ssm list-command-invocations --region $AwsRegion --command-id $cmdId --details --query \"CommandInvocations[*].[InstanceId,Status,CommandPlugins[0].Output]\" --output text" -ForegroundColor White
$albDns = $null
if (Test-Path $DeploymentJsonPath) {
    $dep2 = Get-Content $DeploymentJsonPath -Raw | ConvertFrom-Json
    $albDns = $dep2.alb.dns_name
}
if ($albDns) {
    Write-Host ""
    Write-Host "Abrir: http://$albDns/dashboard/" -ForegroundColor Green
}
