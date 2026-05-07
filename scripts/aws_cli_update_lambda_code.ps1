param(
    [string]$DeploymentFile = (Join-Path $PSScriptRoot "deployment-output.json")
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Get-RequiredValue {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Value,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        throw "No se encontro un valor valido para '$Name' en $DeploymentFile"
    }

    return [string]$Value
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$packageScript = Join-Path $PSScriptRoot "package_lambda.ps1"
$lambdaZipPath = Join-Path $repoRoot "lambda\lambda.zip"

if (-not (Test-Path $DeploymentFile)) {
    throw "No se encontro el archivo de despliegue en $DeploymentFile"
}

$deployment = Get-Content $DeploymentFile -Raw | ConvertFrom-Json
$awsRegion = Get-RequiredValue -Value $deployment.region -Name "region"
$functionName = Get-RequiredValue -Value $deployment.lambda.function_name -Name "lambda.function_name"

Write-Step "Empaquetar Lambda con dependencias"
& $packageScript
if ($LASTEXITCODE -ne 0) {
    throw "Fallo el empaquetado de Lambda."
}

if (-not (Test-Path $lambdaZipPath)) {
    throw "No se encontro el artefacto Lambda en $lambdaZipPath"
}

Write-Step "Actualizar codigo de la Lambda en AWS"
$updateResult = aws lambda update-function-code `
    --region $awsRegion `
    --function-name $functionName `
    --zip-file "fileb://$lambdaZipPath" `
    --query "{FunctionName:FunctionName,LastModified:LastModified,CodeSha256:CodeSha256,Version:Version}" `
    --output json | Out-String

if ($LASTEXITCODE -ne 0) {
    throw "AWS CLI no pudo actualizar el codigo de la Lambda."
}

$updateInfo = $updateResult | ConvertFrom-Json
Write-Host $updateResult.Trim()

Write-Step "Esperar a que AWS termine la actualizacion"
aws lambda wait function-updated `
    --region $awsRegion `
    --function-name $functionName

if ($LASTEXITCODE -ne 0) {
    throw "AWS CLI reporto un problema esperando la actualizacion de la Lambda."
}

Write-Step "Resumen final"
Write-Host "Lambda actualizada correctamente." -ForegroundColor Green
Write-Host "Region: $awsRegion"
Write-Host "Funcion: $($updateInfo.FunctionName)"
Write-Host "Version: $($updateInfo.Version)"
Write-Host "LastModified: $($updateInfo.LastModified)"
Write-Host "CodeSha256: $($updateInfo.CodeSha256)"
Write-Host ""
Write-Host "Prueba sugerida en AWS Console:" -ForegroundColor Yellow
Write-Host "1. Abre Lambda > Functions > $functionName"
Write-Host "2. Ve a Test"
Write-Host "3. Ejecuta el evento de prueba otra vez"
