param()

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptRoot "..")
$lambdaRoot = Join-Path $repoRoot "lambda"
$buildDir = Join-Path $lambdaRoot "build"
$zipPath = Join-Path $lambdaRoot "lambda.zip"

if (Test-Path $buildDir) {
    Remove-Item -Recurse -Force $buildDir
}
if (Test-Path $zipPath) {
    Remove-Item -Force $zipPath
}

New-Item -ItemType Directory -Path $buildDir | Out-Null

python -m pip install --upgrade pip | Out-Null
python -m pip install -r (Join-Path $lambdaRoot "requirements.txt") -t $buildDir | Out-Null
Copy-Item (Join-Path $lambdaRoot "app.py") (Join-Path $buildDir "app.py")

$pyMysqlInit = Join-Path $buildDir "pymysql\__init__.py"
if (-not (Test-Path $pyMysqlInit)) {
    throw "PyMySQL no fue incluido en el paquete Lambda. Revisa la instalacion de dependencias."
}

Compress-Archive -Path (Join-Path $buildDir "*") -DestinationPath $zipPath -Force
Write-Host "Lambda empaquetada en $zipPath"
