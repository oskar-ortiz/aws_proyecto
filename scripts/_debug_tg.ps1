$awsArgs = @("elbv2", "describe-target-groups", "--region", "us-east-1", "--target-group-arns", "arn:aws:elasticloadbalancing:us-east-1:159178776030:targetgroup/university-enrollment-2-ec2-tg/b42fb7840eeb75c7", "arn:aws:elasticloadbalancing:us-east-1:159178776030:targetgroup/university-enrollmen-lambda-tg/d64621ccb2e88454")
$raw = & aws $awsArgs --output json
$tgs = $raw | ConvertFrom-Json
$ec2Tg = @($tgs.TargetGroups | Where-Object { $_.TargetType -eq "instance" -and $_.Port -eq 80 }) | Select-Object -First 1
Write-Host "Raw output length: $($raw.Length)"
Write-Host "EC2 Target group: $($ec2Tg | ConvertTo-Json)"
