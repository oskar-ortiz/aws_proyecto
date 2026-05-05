param(
    [string]$AwsRegion = "us-east-1",
    [string]$ProjectName = "university-enrollment",
    [string]$VpcCidr = "10.20.0.0/16",
    [string]$PublicSubnet1Cidr = "10.20.0.0/24",
    [string]$PublicSubnet2Cidr = "10.20.1.0/24",
    [string]$AppSubnet1Cidr = "10.20.10.0/24",
    [string]$AppSubnet2Cidr = "10.20.11.0/24",
    [string]$DbSubnet1Cidr = "10.20.20.0/24",
    [string]$DbSubnet2Cidr = "10.20.21.0/24",
    [string]$Az1 = "us-east-1a",
    [string]$Az2 = "us-east-1b",
    [string]$DbName = "university",
    [string]$DbUser = "admin",
    [string]$DbPassword = "ChangeMe123!",
    [string]$DbInstanceClass = "db.t3.micro",
    [string]$Ec2InstanceType = "t3.micro",
    [string]$SesSenderEmail = "verified-sender@example.com",
    [string]$SesRecipientEmail = "verified-recipient@example.com",
    [int]$AsgDesiredCapacity = 2,
    [int]$AsgMinSize = 2,
    [int]$AsgMaxSize = 6
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Invoke-AwsJson {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $output = & aws @Arguments --output json | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw "AWS CLI command failed: aws $($Arguments -join ' ')"
    }

    if ([string]::IsNullOrWhiteSpace($output)) {
        return $null
    }

    return $output | ConvertFrom-Json
}

function Invoke-AwsText {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $output = & aws @Arguments --output text | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw "AWS CLI command failed: aws $($Arguments -join ' ')"
    }

    return $output.Trim()
}

function Wait-ForIamPropagation {
    Start-Sleep -Seconds 15
}

function New-TempJsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Object
    )

    $path = Join-Path $env:TEMP ("aws-cli-" + [guid]::NewGuid().ToString() + ".json")
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($path, ($Object | ConvertTo-Json -Depth 20), $utf8NoBom)
    return $path
}

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Get-Base64FileContent {
    param([string]$Path)
    return [Convert]::ToBase64String([IO.File]::ReadAllBytes($Path))
}

function Get-LaunchUserData {
    param(
        [string]$DbWriteHost,
        [string]$DbReadHost
    )

    $backendAppB64 = Get-Base64FileContent (Join-Path $PSScriptRoot "..\app\backend\app.py")
    $backendRequirementsB64 = Get-Base64FileContent (Join-Path $PSScriptRoot "..\app\backend\requirements.txt")
    $backendServiceB64 = Get-Base64FileContent (Join-Path $PSScriptRoot "..\app\backend\university-backend.service")
    $nginxConfB64 = Get-Base64FileContent (Join-Path $PSScriptRoot "..\nginx\nginx.conf")

    $userData = @"
#!/bin/bash
set -euxo pipefail

dnf update -y
dnf install -y nginx python3 python3-pip

mkdir -p /opt/university/app

cat <<'EOF' | base64 -d > /opt/university/app/app.py
$backendAppB64
EOF

cat <<'EOF' | base64 -d > /opt/university/app/requirements.txt
$backendRequirementsB64
EOF

cat <<'EOF' | base64 -d > /etc/nginx/nginx.conf
$nginxConfB64
EOF

cat <<'EOF' | base64 -d > /etc/systemd/system/university-backend.service
$backendServiceB64
EOF

cat <<'EOF' > /opt/university/app/.env
DB_WRITE_HOST=$DbWriteHost
DB_READ_HOST=$DbReadHost
DB_NAME=$DbName
DB_USER=$DbUser
DB_PASSWORD=$DbPassword
APP_PORT=8000
AWS_REGION=$AwsRegion
SES_SENDER_EMAIL=$SesSenderEmail
EOF

python3 -m pip install -r /opt/university/app/requirements.txt

systemctl daemon-reload
systemctl enable nginx
systemctl restart nginx
systemctl enable university-backend
systemctl restart university-backend
"@

    return [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($userData))
}

if ($SesSenderEmail -like "*example.com" -or $SesRecipientEmail -like "*example.com") {
    throw "Reemplaza SesSenderEmail y SesRecipientEmail por correos reales verificables en SES sandbox antes de desplegar."
}

$deploymentTimestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$stackSuffix = $deploymentTimestamp.ToLower()
$resourcePrefix = "$ProjectName-$stackSuffix"
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptRoot "..")
$deploymentOutputPath = Join-Path $scriptRoot "deployment-output.json"

Write-Step "Empaquetar Lambda"
& (Join-Path $scriptRoot "package_lambda.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Fallo el empaquetado de Lambda."
}
$lambdaZipPath = Join-Path $repoRoot "lambda\lambda.zip"
if (-not (Test-Path $lambdaZipPath)) {
    throw "No se encontro el artefacto Lambda en $lambdaZipPath"
}

Write-Step "Resolver AMI Amazon Linux 2023"
$amiId = Invoke-AwsText @(
    "ssm", "get-parameter",
    "--region", $AwsRegion,
    "--name", "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64",
    "--query", "Parameter.Value"
)

Write-Step "Resolver version valida de MySQL 8.0 para RDS"
$mysqlEngineVersion = Invoke-AwsText @(
    "rds", "describe-db-engine-versions",
    "--region", $AwsRegion,
    "--engine", "mysql",
    "--query", "sort_by(DBEngineVersions[?starts_with(EngineVersion, '8.0')], &EngineVersion)[-1].EngineVersion"
)

$deployment = [ordered]@{
    project_name = $ProjectName
    resource_prefix = $resourcePrefix
    region = $AwsRegion
    account_id = (Invoke-AwsJson @("sts", "get-caller-identity")).Account
    timestamps = [ordered]@{
        started_at = (Get-Date).ToString("s")
    }
}

Write-Step "Crear VPC y networking"
$vpc = Invoke-AwsJson @(
    "ec2", "create-vpc",
    "--region", $AwsRegion,
    "--cidr-block", $VpcCidr,
    "--tag-specifications", "ResourceType=vpc,Tags=[{Key=Name,Value=$resourcePrefix-vpc}]"
)
$vpcId = $vpc.Vpc.VpcId
$deployment.vpc_id = $vpcId

& aws ec2 modify-vpc-attribute --region $AwsRegion --vpc-id $vpcId --enable-dns-support
& aws ec2 modify-vpc-attribute --region $AwsRegion --vpc-id $vpcId --enable-dns-hostnames

$igw = Invoke-AwsJson @(
    "ec2", "create-internet-gateway",
    "--region", $AwsRegion,
    "--tag-specifications", "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$resourcePrefix-igw}]"
)
$igwId = $igw.InternetGateway.InternetGatewayId
& aws ec2 attach-internet-gateway --region $AwsRegion --internet-gateway-id $igwId --vpc-id $vpcId

$publicSubnet1 = Invoke-AwsJson @("ec2", "create-subnet", "--region", $AwsRegion, "--vpc-id", $vpcId, "--cidr-block", $PublicSubnet1Cidr, "--availability-zone", $Az1, "--tag-specifications", "ResourceType=subnet,Tags=[{Key=Name,Value=$resourcePrefix-public-1}]")
$publicSubnet2 = Invoke-AwsJson @("ec2", "create-subnet", "--region", $AwsRegion, "--vpc-id", $vpcId, "--cidr-block", $PublicSubnet2Cidr, "--availability-zone", $Az2, "--tag-specifications", "ResourceType=subnet,Tags=[{Key=Name,Value=$resourcePrefix-public-2}]")
$appSubnet1 = Invoke-AwsJson @("ec2", "create-subnet", "--region", $AwsRegion, "--vpc-id", $vpcId, "--cidr-block", $AppSubnet1Cidr, "--availability-zone", $Az1, "--tag-specifications", "ResourceType=subnet,Tags=[{Key=Name,Value=$resourcePrefix-app-1}]")
$appSubnet2 = Invoke-AwsJson @("ec2", "create-subnet", "--region", $AwsRegion, "--vpc-id", $vpcId, "--cidr-block", $AppSubnet2Cidr, "--availability-zone", $Az2, "--tag-specifications", "ResourceType=subnet,Tags=[{Key=Name,Value=$resourcePrefix-app-2}]")
$dbSubnet1 = Invoke-AwsJson @("ec2", "create-subnet", "--region", $AwsRegion, "--vpc-id", $vpcId, "--cidr-block", $DbSubnet1Cidr, "--availability-zone", $Az1, "--tag-specifications", "ResourceType=subnet,Tags=[{Key=Name,Value=$resourcePrefix-db-1}]")
$dbSubnet2 = Invoke-AwsJson @("ec2", "create-subnet", "--region", $AwsRegion, "--vpc-id", $vpcId, "--cidr-block", $DbSubnet2Cidr, "--availability-zone", $Az2, "--tag-specifications", "ResourceType=subnet,Tags=[{Key=Name,Value=$resourcePrefix-db-2}]")

$publicSubnet1Id = $publicSubnet1.Subnet.SubnetId
$publicSubnet2Id = $publicSubnet2.Subnet.SubnetId
$appSubnet1Id = $appSubnet1.Subnet.SubnetId
$appSubnet2Id = $appSubnet2.Subnet.SubnetId
$dbSubnet1Id = $dbSubnet1.Subnet.SubnetId
$dbSubnet2Id = $dbSubnet2.Subnet.SubnetId

& aws ec2 modify-subnet-attribute --region $AwsRegion --subnet-id $publicSubnet1Id --map-public-ip-on-launch
& aws ec2 modify-subnet-attribute --region $AwsRegion --subnet-id $publicSubnet2Id --map-public-ip-on-launch

$eipAllocationId = Invoke-AwsText @("ec2", "allocate-address", "--region", $AwsRegion, "--domain", "vpc", "--query", "AllocationId")
$natGatewayId = Invoke-AwsText @("ec2", "create-nat-gateway", "--region", $AwsRegion, "--subnet-id", $publicSubnet1Id, "--allocation-id", $eipAllocationId, "--tag-specifications", "ResourceType=natgateway,Tags=[{Key=Name,Value=$resourcePrefix-nat}]", "--query", "NatGateway.NatGatewayId")
& aws ec2 wait nat-gateway-available --region $AwsRegion --nat-gateway-ids $natGatewayId

$publicRtId = Invoke-AwsText @("ec2", "create-route-table", "--region", $AwsRegion, "--vpc-id", $vpcId, "--query", "RouteTable.RouteTableId")
$privateAppRtId = Invoke-AwsText @("ec2", "create-route-table", "--region", $AwsRegion, "--vpc-id", $vpcId, "--query", "RouteTable.RouteTableId")
$privateDbRtId = Invoke-AwsText @("ec2", "create-route-table", "--region", $AwsRegion, "--vpc-id", $vpcId, "--query", "RouteTable.RouteTableId")

& aws ec2 create-tags --region $AwsRegion --resources $publicRtId --tags Key=Name,Value=$resourcePrefix-public-rt
& aws ec2 create-tags --region $AwsRegion --resources $privateAppRtId --tags Key=Name,Value=$resourcePrefix-private-app-rt
& aws ec2 create-tags --region $AwsRegion --resources $privateDbRtId --tags Key=Name,Value=$resourcePrefix-private-db-rt

& aws ec2 create-route --region $AwsRegion --route-table-id $publicRtId --destination-cidr-block 0.0.0.0/0 --gateway-id $igwId
& aws ec2 create-route --region $AwsRegion --route-table-id $privateAppRtId --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $natGatewayId

& aws ec2 associate-route-table --region $AwsRegion --subnet-id $publicSubnet1Id --route-table-id $publicRtId
& aws ec2 associate-route-table --region $AwsRegion --subnet-id $publicSubnet2Id --route-table-id $publicRtId
& aws ec2 associate-route-table --region $AwsRegion --subnet-id $appSubnet1Id --route-table-id $privateAppRtId
& aws ec2 associate-route-table --region $AwsRegion --subnet-id $appSubnet2Id --route-table-id $privateAppRtId
& aws ec2 associate-route-table --region $AwsRegion --subnet-id $dbSubnet1Id --route-table-id $privateDbRtId
& aws ec2 associate-route-table --region $AwsRegion --subnet-id $dbSubnet2Id --route-table-id $privateDbRtId

$deployment.network = [ordered]@{
    igw_id = $igwId
    nat_gateway_id = $natGatewayId
    public_subnet_ids = @($publicSubnet1Id, $publicSubnet2Id)
    app_subnet_ids = @($appSubnet1Id, $appSubnet2Id)
    db_subnet_ids = @($dbSubnet1Id, $dbSubnet2Id)
}

Write-Step "Crear security groups"
$albSgId = Invoke-AwsText @("ec2", "create-security-group", "--region", $AwsRegion, "--group-name", "$resourcePrefix-alb-sg", "--description", "ALB security group", "--vpc-id", $vpcId, "--query", "GroupId")
$ec2SgId = Invoke-AwsText @("ec2", "create-security-group", "--region", $AwsRegion, "--group-name", "$resourcePrefix-ec2-sg", "--description", "EC2 backend security group", "--vpc-id", $vpcId, "--query", "GroupId")
$lambdaSgId = Invoke-AwsText @("ec2", "create-security-group", "--region", $AwsRegion, "--group-name", "$resourcePrefix-lambda-sg", "--description", "Lambda security group", "--vpc-id", $vpcId, "--query", "GroupId")
$rdsSgId = Invoke-AwsText @("ec2", "create-security-group", "--region", $AwsRegion, "--group-name", "$resourcePrefix-rds-sg", "--description", "RDS security group", "--vpc-id", $vpcId, "--query", "GroupId")

& aws ec2 authorize-security-group-ingress --region $AwsRegion --group-id $albSgId --protocol tcp --port 80 --cidr 0.0.0.0/0
& aws ec2 authorize-security-group-ingress --region $AwsRegion --group-id $ec2SgId --protocol tcp --port 80 --source-group $albSgId
& aws ec2 authorize-security-group-ingress --region $AwsRegion --group-id $rdsSgId --protocol tcp --port 3306 --source-group $ec2SgId
& aws ec2 authorize-security-group-ingress --region $AwsRegion --group-id $rdsSgId --protocol tcp --port 3306 --source-group $lambdaSgId

$deployment.security_groups = [ordered]@{
    alb = $albSgId
    ec2 = $ec2SgId
    lambda = $lambdaSgId
    rds = $rdsSgId
}

Write-Step "Crear IAM roles para EC2 y Lambda"
$ec2AssumeRolePolicy = @{
    Version = "2012-10-17"
    Statement = @(
        @{
            Effect = "Allow"
            Principal = @{ Service = "ec2.amazonaws.com" }
            Action = "sts:AssumeRole"
        }
    )
}
$lambdaAssumeRolePolicy = @{
    Version = "2012-10-17"
    Statement = @(
        @{
            Effect = "Allow"
            Principal = @{ Service = "lambda.amazonaws.com" }
            Action = "sts:AssumeRole"
        }
    )
}

$ec2AssumeRoleFile = New-TempJsonFile $ec2AssumeRolePolicy
$lambdaAssumeRoleFile = New-TempJsonFile $lambdaAssumeRolePolicy

$ec2RoleName = "$resourcePrefix-ec2-role"
$lambdaRoleName = "$resourcePrefix-lambda-role"
$instanceProfileName = "$resourcePrefix-instance-profile"

$ec2RoleArn = Invoke-AwsText @("iam", "create-role", "--role-name", $ec2RoleName, "--assume-role-policy-document", "file://$ec2AssumeRoleFile", "--query", "Role.Arn")
$lambdaRoleArn = Invoke-AwsText @("iam", "create-role", "--role-name", $lambdaRoleName, "--assume-role-policy-document", "file://$lambdaAssumeRoleFile", "--query", "Role.Arn")

& aws iam attach-role-policy --role-name $ec2RoleName --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
& aws iam attach-role-policy --role-name $ec2RoleName --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
& aws iam attach-role-policy --role-name $lambdaRoleName --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
& aws iam attach-role-policy --role-name $lambdaRoleName --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole

$lambdaInlinePolicy = @{
    Version = "2012-10-17"
    Statement = @(
        @{
            Effect = "Allow"
            Action = @("ses:SendEmail", "ses:SendRawEmail")
            Resource = "*"
        }
    )
}
$lambdaPolicyFile = New-TempJsonFile $lambdaInlinePolicy
& aws iam put-role-policy --role-name $lambdaRoleName --policy-name "$resourcePrefix-lambda-inline" --policy-document "file://$lambdaPolicyFile"

& aws iam create-instance-profile --instance-profile-name $instanceProfileName
& aws iam add-role-to-instance-profile --instance-profile-name $instanceProfileName --role-name $ec2RoleName
Wait-ForIamPropagation

$deployment.iam = [ordered]@{
    ec2_role_arn = $ec2RoleArn
    lambda_role_arn = $lambdaRoleArn
    instance_profile_name = $instanceProfileName
}

Write-Step "Crear RDS Multi-AZ primario"
$dbSubnetGroupName = "$resourcePrefix-db-subnet-group"
& aws rds create-db-subnet-group --region $AwsRegion --db-subnet-group-name $dbSubnetGroupName --db-subnet-group-description "University DB subnet group" --subnet-ids $dbSubnet1Id $dbSubnet2Id

$primaryDbId = "$resourcePrefix-mysql-primary"
$replicaDbId = "$resourcePrefix-mysql-replica"

& aws rds create-db-instance `
    --region $AwsRegion `
    --db-instance-identifier $primaryDbId `
    --engine mysql `
    --engine-version $mysqlEngineVersion `
    --db-instance-class $DbInstanceClass `
    --allocated-storage 20 `
    --master-username $DbUser `
    --master-user-password $DbPassword `
    --db-name $DbName `
    --multi-az `
    --backup-retention-period 7 `
    --storage-encrypted `
    --no-publicly-accessible `
    --db-subnet-group-name $dbSubnetGroupName `
    --vpc-security-group-ids $rdsSgId `
    --tags Key=Name,Value=$primaryDbId

& aws rds wait db-instance-available --region $AwsRegion --db-instance-identifier $primaryDbId
$primaryDb = Invoke-AwsJson @("rds", "describe-db-instances", "--region", $AwsRegion, "--db-instance-identifier", $primaryDbId)
$primaryWriterEndpoint = $primaryDb.DBInstances[0].Endpoint.Address

Write-Step "Crear Read Replica"
& aws rds create-db-instance-read-replica `
    --region $AwsRegion `
    --db-instance-identifier $replicaDbId `
    --source-db-instance-identifier $primaryDbId `
    --db-instance-class $DbInstanceClass `
    --vpc-security-group-ids $rdsSgId `
    --no-publicly-accessible `
    --tags Key=Name,Value=$replicaDbId

& aws rds wait db-instance-available --region $AwsRegion --db-instance-identifier $replicaDbId
$replicaDb = Invoke-AwsJson @("rds", "describe-db-instances", "--region", $AwsRegion, "--db-instance-identifier", $replicaDbId)
$replicaReaderEndpoint = $replicaDb.DBInstances[0].Endpoint.Address

$deployment.database = [ordered]@{
    subnet_group_name = $dbSubnetGroupName
    primary_identifier = $primaryDbId
    primary_endpoint = $primaryWriterEndpoint
    replica_identifier = $replicaDbId
    replica_endpoint = $replicaReaderEndpoint
}

Write-Step "Configurar SES sandbox"
& aws ses verify-email-identity --region $AwsRegion --email-address $SesSenderEmail
& aws ses verify-email-identity --region $AwsRegion --email-address $SesRecipientEmail
$senderIdentity = Invoke-AwsJson @("sesv2", "get-email-identity", "--region", $AwsRegion, "--email-identity", $SesSenderEmail)
$recipientIdentity = Invoke-AwsJson @("sesv2", "get-email-identity", "--region", $AwsRegion, "--email-identity", $SesRecipientEmail)
$deployment.ses = [ordered]@{
    sender = [ordered]@{
        email = $SesSenderEmail
        verified_for_sending_status = $senderIdentity.VerifiedForSendingStatus
    }
    recipient = [ordered]@{
        email = $SesRecipientEmail
        verified_for_sending_status = $recipientIdentity.VerifiedForSendingStatus
    }
}

Write-Step "Crear Lambda"
$lambdaFunctionName = "$resourcePrefix-enrollment-email"
$lambdaArn = Invoke-AwsText @(
    "lambda", "create-function",
    "--region", $AwsRegion,
    "--function-name", $lambdaFunctionName,
    "--runtime", "python3.12",
    "--handler", "app.lambda_handler",
    "--role", $lambdaRoleArn,
    "--zip-file", "fileb://$lambdaZipPath",
    "--timeout", "30",
    "--memory-size", "256",
    "--vpc-config", "SubnetIds=$appSubnet1Id,$appSubnet2Id,SecurityGroupIds=$lambdaSgId",
    "--environment", "Variables={DB_HOST=$primaryWriterEndpoint,DB_NAME=$DbName,DB_USER=$DbUser,DB_PASSWORD=$DbPassword,SES_SENDER_EMAIL=$SesSenderEmail,MAX_RETRIES=3}",
    "--query", "FunctionArn"
)

$lambdaTargetGroupArn = Invoke-AwsText @("elbv2", "create-target-group", "--region", $AwsRegion, "--name", "$($resourcePrefix.Substring(0, [Math]::Min(20, $resourcePrefix.Length)))-lambda-tg", "--target-type", "lambda", "--query", "TargetGroups[0].TargetGroupArn")
& aws lambda add-permission --region $AwsRegion --function-name $lambdaFunctionName --statement-id AllowExecutionFromALB --action lambda:InvokeFunction --principal elasticloadbalancing.amazonaws.com --source-arn $lambdaTargetGroupArn
& aws elbv2 register-targets --region $AwsRegion --target-group-arn $lambdaTargetGroupArn --targets Id=$lambdaArn

$deployment.lambda = [ordered]@{
    function_name = $lambdaFunctionName
    function_arn = $lambdaArn
    target_group_arn = $lambdaTargetGroupArn
}

Write-Step "Crear ALB"
$albName = "$($resourcePrefix.Substring(0, [Math]::Min(24, $resourcePrefix.Length)))-alb"
$alb = Invoke-AwsJson @(
    "elbv2", "create-load-balancer",
    "--region", $AwsRegion,
    "--name", $albName,
    "--subnets", $publicSubnet1Id, $publicSubnet2Id,
    "--security-groups", $albSgId,
    "--type", "application"
)
$albArn = $alb.LoadBalancers[0].LoadBalancerArn
$albDnsName = $alb.LoadBalancers[0].DNSName
& aws elbv2 wait load-balancer-available --region $AwsRegion --load-balancer-arns $albArn

$ec2TargetGroupArn = Invoke-AwsText @(
    "elbv2", "create-target-group",
    "--region", $AwsRegion,
    "--name", "$($resourcePrefix.Substring(0, [Math]::Min(23, $resourcePrefix.Length)))-ec2-tg",
    "--protocol", "HTTP",
    "--port", "80",
    "--target-type", "instance",
    "--vpc-id", $vpcId,
    "--health-check-path", "/health",
    "--query", "TargetGroups[0].TargetGroupArn"
)

$listenerArn = Invoke-AwsText @(
    "elbv2", "create-listener",
    "--region", $AwsRegion,
    "--load-balancer-arn", $albArn,
    "--protocol", "HTTP",
    "--port", "80",
    "--default-actions", "Type=fixed-response,FixedResponseConfig={StatusCode=404,ContentType=text/plain,MessageBody=Route not found}",
    "--query", "Listeners[0].ListenerArn"
)

& aws elbv2 create-rule --region $AwsRegion --listener-arn $listenerArn --priority 10 --conditions Field=path-pattern,Values='/admin/*','/health' --actions Type=forward,TargetGroupArn=$ec2TargetGroupArn
& aws elbv2 create-rule --region $AwsRegion --listener-arn $listenerArn --priority 20 --conditions Field=path-pattern,Values='/api/*' --actions Type=forward,TargetGroupArn=$lambdaTargetGroupArn

$deployment.alb = [ordered]@{
    arn = $albArn
    dns_name = $albDnsName
    ec2_target_group_arn = $ec2TargetGroupArn
    lambda_target_group_arn = $lambdaTargetGroupArn
    listener_arn = $listenerArn
}

Write-Step "Crear Launch Template y Auto Scaling Group"
$launchTemplateName = "$resourcePrefix-lt"
$userDataB64 = Get-LaunchUserData -DbWriteHost $primaryWriterEndpoint -DbReadHost $replicaReaderEndpoint
$launchTemplateData = @{
    ImageId = $amiId
    InstanceType = $Ec2InstanceType
    IamInstanceProfile = @{
        Name = $instanceProfileName
    }
    UserData = $userDataB64
    NetworkInterfaces = @(
        @{
            DeviceIndex = 0
            AssociatePublicIpAddress = $false
            Groups = @($ec2SgId)
        }
    )
    TagSpecifications = @(
        @{
            ResourceType = "instance"
            Tags = @(
                @{ Key = "Name"; Value = "$resourcePrefix-backend" }
            )
        }
    )
}
$launchTemplateFile = New-TempJsonFile $launchTemplateData
$launchTemplateId = Invoke-AwsText @("ec2", "create-launch-template", "--region", $AwsRegion, "--launch-template-name", $launchTemplateName, "--launch-template-data", "file://$launchTemplateFile", "--query", "LaunchTemplate.LaunchTemplateId")

$asgName = "$resourcePrefix-asg"
& aws autoscaling create-auto-scaling-group `
    --region $AwsRegion `
    --auto-scaling-group-name $asgName `
    --launch-template "LaunchTemplateId=$launchTemplateId,Version=1" `
    --min-size $AsgMinSize `
    --max-size $AsgMaxSize `
    --desired-capacity $AsgDesiredCapacity `
    --vpc-zone-identifier "$appSubnet1Id,$appSubnet2Id" `
    --target-group-arns $ec2TargetGroupArn `
    --health-check-type ELB `
    --health-check-grace-period 300 `
    --default-cooldown 120 `
    --tags "Key=Name,Value=$resourcePrefix-backend,PropagateAtLaunch=true"

$policy60Arn = Invoke-AwsText @(
    "autoscaling", "put-scaling-policy",
    "--region", $AwsRegion,
    "--auto-scaling-group-name", $asgName,
    "--policy-name", "$resourcePrefix-cpu-60",
    "--policy-type", "StepScaling",
    "--adjustment-type", "ChangeInCapacity",
    "--estimated-instance-warmup", "180",
    "--step-adjustments", "MetricIntervalLowerBound=0,ScalingAdjustment=1",
    "--query", "PolicyARN"
)
$policy85Arn = Invoke-AwsText @(
    "autoscaling", "put-scaling-policy",
    "--region", $AwsRegion,
    "--auto-scaling-group-name", $asgName,
    "--policy-name", "$resourcePrefix-cpu-85",
    "--policy-type", "StepScaling",
    "--adjustment-type", "ChangeInCapacity",
    "--estimated-instance-warmup", "180",
    "--step-adjustments", "MetricIntervalLowerBound=0,ScalingAdjustment=3",
    "--query", "PolicyARN"
)

& aws cloudwatch put-metric-alarm --region $AwsRegion --alarm-name "$resourcePrefix-cpu-60" --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 120 --threshold 60 --comparison-operator GreaterThanOrEqualToThreshold --evaluation-periods 2 --dimensions Name=AutoScalingGroupName,Value=$asgName --alarm-actions $policy60Arn
& aws cloudwatch put-metric-alarm --region $AwsRegion --alarm-name "$resourcePrefix-cpu-85" --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 120 --threshold 85 --comparison-operator GreaterThanOrEqualToThreshold --evaluation-periods 2 --dimensions Name=AutoScalingGroupName,Value=$asgName --alarm-actions $policy85Arn

Start-Sleep -Seconds 30
$asgDescription = Invoke-AwsJson @("autoscaling", "describe-auto-scaling-groups", "--region", $AwsRegion, "--auto-scaling-group-names", $asgName)
$instanceIds = @($asgDescription.AutoScalingGroups[0].Instances.InstanceId | Where-Object { $_ })

$deployment.autoscaling = [ordered]@{
    launch_template_id = $launchTemplateId
    asg_name = $asgName
    desired_capacity = $AsgDesiredCapacity
    instance_ids = $instanceIds
    scale_policy_60_arn = $policy60Arn
    scale_policy_85_arn = $policy85Arn
}

$deployment.timestamps.finished_at = (Get-Date).ToString("s")
$deployment | ConvertTo-Json -Depth 20 | Set-Content -Path $deploymentOutputPath -Encoding UTF8

Write-Host ""
Write-Host "Despliegue completado. Evidencia guardada en $deploymentOutputPath" -ForegroundColor Green
Write-Host "ALB DNS: $albDnsName"
Write-Host "Writer endpoint: $primaryWriterEndpoint"
Write-Host "Reader endpoint: $replicaReaderEndpoint"
Write-Host "Instancias iniciales ASG: $($instanceIds -join ', ')"
Write-Host ""
Write-Host "Si SES aun no aparece verificado, confirma ambos correos y luego ejecuta scripts\\aws_cli_verify.ps1 con el deployment-output.json." -ForegroundColor Yellow
