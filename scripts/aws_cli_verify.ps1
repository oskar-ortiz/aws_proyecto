param(
    [string]$DeploymentOutputPath = ".\scripts\deployment-output.json",
    [string]$StudentName = "Ana Perez",
    [string]$StudentEmail = "verified-recipient@example.com",
    [string]$CourseCode = "CS101"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $DeploymentOutputPath)) {
    throw "No existe el archivo de despliegue: $DeploymentOutputPath"
}

$deployment = Get-Content $DeploymentOutputPath | ConvertFrom-Json
$albDns = $deployment.alb.dns_name
$region = $deployment.region
$primaryDbId = $deployment.database.primary_identifier

Write-Host "Verificando health endpoint..."
$health = Invoke-RestMethod -Uri "http://$albDns/health" -Method Get
$adminHealth = Invoke-RestMethod -Uri "http://$albDns/admin/health" -Method Get

Write-Host "Creando matrícula..."
$enrollmentBody = @{
    student_name  = $StudentName
    student_email = $StudentEmail
    course_code   = $CourseCode
} | ConvertTo-Json

$created = Invoke-RestMethod -Uri "http://$albDns/admin/enrollments" -Method Post -ContentType "application/json" -Body $enrollmentBody

Write-Host "Consultando desde endpoint de lectura..."
$enrollments = Invoke-RestMethod -Uri "http://$albDns/admin/enrollments" -Method Get

Write-Host "Invocando Lambda via ALB..."
$confirmBody = @{
    enrollment_id = $created.enrollment_id
    student_name  = $StudentName
    student_email = $StudentEmail
    course_code   = $CourseCode
} | ConvertTo-Json

$confirm = Invoke-RestMethod -Uri "http://$albDns/api/confirm" -Method Post -ContentType "application/json" -Body $confirmBody

$result = [ordered]@{
    alb_dns_name = $albDns
    health = $health
    admin_health = $adminHealth
    created_enrollment = $created
    read_response = $enrollments
    lambda_confirmation = $confirm
    verified_at = (Get-Date).ToString("s")
}

$result | ConvertTo-Json -Depth 10
