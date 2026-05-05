param(
    [string]$DeploymentOutputPath = ".\scripts\deployment-output.json"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $DeploymentOutputPath)) {
    throw "No existe el archivo de despliegue: $DeploymentOutputPath"
}

$deployment = Get-Content $DeploymentOutputPath | ConvertFrom-Json
$region = $deployment.region
$primaryDbId = $deployment.database.primary_identifier
$writerEndpointBefore = $deployment.database.primary_endpoint

Write-Host "Forzando failover controlado sobre $primaryDbId ..."
aws rds reboot-db-instance `
    --region $region `
    --db-instance-identifier $primaryDbId `
    --force-failover | Out-Null

aws rds wait db-instance-available `
    --region $region `
    --db-instance-identifier $primaryDbId

$db = aws rds describe-db-instances `
    --region $region `
    --db-instance-identifier $primaryDbId `
    --output json | ConvertFrom-Json

$writerEndpointAfter = $db.DBInstances[0].Endpoint.Address

[ordered]@{
    primary_identifier = $primaryDbId
    writer_endpoint_before = $writerEndpointBefore
    writer_endpoint_after = $writerEndpointAfter
    checked_at = (Get-Date).ToString("s")
} | ConvertTo-Json -Depth 5
