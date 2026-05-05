# AWS Resource Inventory

Deployment source: [deployment-output.json](/C:/aws_proyecto/scripts/deployment-output.json)

- Account ID: `159178776030`
- Region: `us-east-1`
- Project: `university-enrollment`
- Resource prefix: `university-enrollment-20260505-091645`
- Deployment window: `2026-05-05T09:17:15` to `2026-05-05T09:50:17`

## Inventory

| Service | Resource | Name | ID / ARN / Endpoint | State | AWS Console location | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| VPC | VPC | `university-enrollment-20260505-091645-vpc` | `vpc-094f72142723bb32b` | Active | `VPC > Your VPCs` | CIDR `10.20.0.0/16` |
| VPC | Public Subnet | `university-enrollment-20260505-091645-public-1` | `subnet-060eccd68f6d097c8` | Active | `VPC > Subnets` | AZ `us-east-1a`, CIDR `10.20.0.0/24` |
| VPC | Public Subnet | `university-enrollment-20260505-091645-public-2` | `subnet-029a693934b35aa6b` | Active | `VPC > Subnets` | AZ `us-east-1b`, CIDR `10.20.1.0/24` |
| VPC | App Subnet | `university-enrollment-20260505-091645-app-1` | `subnet-0054abb10070f29c0` | Active | `VPC > Subnets` | AZ `us-east-1a`, CIDR `10.20.10.0/24` |
| VPC | App Subnet | `university-enrollment-20260505-091645-app-2` | `subnet-0e7c4d5330200f829` | Active | `VPC > Subnets` | AZ `us-east-1b`, CIDR `10.20.11.0/24` |
| VPC | DB Subnet | `university-enrollment-20260505-091645-db-1` | `subnet-04c9192e206b4a296` | Active | `VPC > Subnets` | AZ `us-east-1a`, CIDR `10.20.20.0/24` |
| VPC | DB Subnet | `university-enrollment-20260505-091645-db-2` | `subnet-0631d6a6c8b3f55f5` | Active | `VPC > Subnets` | AZ `us-east-1b`, CIDR `10.20.21.0/24` |
| VPC | Internet Gateway | `university-enrollment-20260505-091645-igw` | `igw-01e2cf7b54d579f27` | Attached | `VPC > Internet Gateways` | Attached to `vpc-094f72142723bb32b` |
| VPC | NAT Gateway | `university-enrollment-20260505-091645-nat` | `nat-0e371c9a183ba5398` | `available` | `VPC > NAT Gateways` | In subnet `subnet-060eccd68f6d097c8` |
| VPC | Elastic IP | N/A | `eipalloc-0a022bbae39ee2239` / `44.217.114.187` | Allocated | `VPC > Elastic IPs` | Associated to NAT via `eipassoc-01f4e674087a62255` |
| VPC | Route Table | `university-enrollment-20260505-091645-public-rt` | `rtb-02319de6654d36cef` | Active | `VPC > Route Tables` | Associated to both public subnets |
| VPC | Route Table | `university-enrollment-20260505-091645-private-app-rt` | `rtb-05ef597281626bda8` | Active | `VPC > Route Tables` | Associated to both app subnets |
| VPC | Route Table | `university-enrollment-20260505-091645-private-db-rt` | `rtb-0bd29fda465a26972` | Active | `VPC > Route Tables` | Associated to both DB subnets |
| EC2 | Security Group | `university-enrollment-20260505-091645-alb-sg` | `sg-0091137566ce5cfa8` | In use | `EC2 > Security Groups` | Ingress `80/tcp` from `0.0.0.0/0` |
| EC2 | Security Group | `university-enrollment-20260505-091645-ec2-sg` | `sg-0c1099d5a5b2eaba5` | In use | `EC2 > Security Groups` | Ingress `80/tcp` from ALB SG |
| EC2 | Security Group | `university-enrollment-20260505-091645-lambda-sg` | `sg-024ab3df4e21640d7` | In use | `EC2 > Security Groups` | Used by Lambda VPC attachment |
| EC2 | Security Group | `university-enrollment-20260505-091645-rds-sg` | `sg-0e5e2f4fb7562d0a1` | In use | `EC2 > Security Groups` | Ingress `3306/tcp` from EC2 and Lambda SGs |
| ELB | Application Load Balancer | `university-enrollment-20-alb` | `university-enrollment-20-alb-1579634256.us-east-1.elb.amazonaws.com` | `active` | `EC2 > Load Balancers` | ARN `arn:aws:elasticloadbalancing:us-east-1:159178776030:loadbalancer/app/university-enrollment-20-alb/753fd885ff9a6c5a` |
| ELB | Listener | HTTP `:80` | `arn:aws:elasticloadbalancing:us-east-1:159178776030:listener/app/university-enrollment-20-alb/753fd885ff9a6c5a/74188ee7dd453919` | Active | `EC2 > Load Balancers > Listeners and rules` | Default action returns `404 Route not found` |
| ELB | Target Group | `university-enrollment-2-ec2-tg` | `arn:aws:elasticloadbalancing:us-east-1:159178776030:targetgroup/university-enrollment-2-ec2-tg/b42fb7840eeb75c7` | Healthy | `EC2 > Target Groups` | Type `instance`, port `80`, health path `/health` |
| ELB | Target Group | `university-enrollmen-lambda-tg` | `arn:aws:elasticloadbalancing:us-east-1:159178776030:targetgroup/university-enrollmen-lambda-tg/d64621ccb2e88454` | `unavailable` | `EC2 > Target Groups` | Type `lambda`; `Target.HealthCheckDisabled` is expected |
| ELB | Listener Rule | `/admin/*`, `/health` | Priority `10` | Active | `EC2 > Load Balancers > Listeners and rules` | Forwards to EC2 target group |
| ELB | Listener Rule | `/api/*` | Priority `20` | Active | `EC2 > Load Balancers > Listeners and rules` | Forwards to Lambda target group |
| Auto Scaling | Auto Scaling Group | `university-enrollment-20260505-091645-asg` | `university-enrollment-20260505-091645-asg` | Active | `EC2 > Auto Scaling Groups` | Desired `2`, min `2`, max `6` |
| EC2 | Launch Template | `university-enrollment-20260505-091645-lt` | `lt-0ab3f4257cd4da92a` | Active | `EC2 > Launch Templates` | Created by `arn:aws:iam::159178776030:root` |
| EC2 | Instance | `university-enrollment-20260505-091645-backend` | `i-09b14cc6d6a8a9963` | `running` | `EC2 > Instances` | Private IP `10.20.10.226`, subnet `subnet-0054abb10070f29c0`, AZ `us-east-1a` |
| EC2 | Instance | `university-enrollment-20260505-091645-backend` | `i-07ed9bbd793da08ca` | `running` | `EC2 > Instances` | Private IP `10.20.11.11`, subnet `subnet-0e7c4d5330200f829`, AZ `us-east-1b` |
| RDS | DB Subnet Group | `university-enrollment-20260505-091645-db-subnet-group` | `university-enrollment-20260505-091645-db-subnet-group` | `Complete` | `RDS > Subnet groups` | VPC `vpc-094f72142723bb32b` |
| RDS | Primary DB Instance | `university-enrollment-20260505-091645-mysql-primary` | `university-enrollment-20260505-091645-mysql-primary.cobes2goaplc.us-east-1.rds.amazonaws.com` | `available` | `RDS > Databases` | MySQL `db.t3.micro`, writer |
| RDS | Read Replica | `university-enrollment-20260505-091645-mysql-replica` | `university-enrollment-20260505-091645-mysql-replica.cobes2goaplc.us-east-1.rds.amazonaws.com` | `available` | `RDS > Databases` | MySQL `db.t3.micro`, reader |
| Lambda | Function | `university-enrollment-20260505-091645-enrollment-email` | `arn:aws:lambda:us-east-1:159178776030:function:university-enrollment-20260505-091645-enrollment-email` | Active | `Lambda > Functions` | Runtime `python3.12` |
| IAM | Role | `university-enrollment-20260505-091645-ec2-role` | `arn:aws:iam::159178776030:role/university-enrollment-20260505-091645-ec2-role` | Active | `IAM > Roles` | Attached to instance profile |
| IAM | Role | `university-enrollment-20260505-091645-lambda-role` | `arn:aws:iam::159178776030:role/university-enrollment-20260505-091645-lambda-role` | Active | `IAM > Roles` | Used by Lambda |
| IAM | Instance Profile | `university-enrollment-20260505-091645-instance-profile` | `arn:aws:iam::159178776030:instance-profile/university-enrollment-20260505-091645-instance-profile` | Active | `IAM > Roles` or `EC2 > Launch Templates` | Contains EC2 role |
| CloudWatch | Alarm | `university-enrollment-20260505-091645-cpu-60` | `university-enrollment-20260505-091645-cpu-60` | `OK` | `CloudWatch > Alarms` | Triggers scale-out `+1` at 60% CPU |
| CloudWatch | Alarm | `university-enrollment-20260505-091645-cpu-85` | `university-enrollment-20260505-091645-cpu-85` | `OK` | `CloudWatch > Alarms` | Triggers scale-out `+3` at 85% CPU |
| Auto Scaling | Scaling Policy | `university-enrollment-20260505-091645-cpu-60` | `arn:aws:autoscaling:us-east-1:159178776030:scalingPolicy:fa93b031-f356-46c5-b7bc-35ab97b1ee81:autoScalingGroupName/university-enrollment-20260505-091645-asg:policyName/university-enrollment-20260505-091645-cpu-60` | Active | `EC2 > Auto Scaling Groups > Automatic scaling` | Step scaling `+1` |
| Auto Scaling | Scaling Policy | `university-enrollment-20260505-091645-cpu-85` | `arn:aws:autoscaling:us-east-1:159178776030:scalingPolicy:580d6ec0-9350-4589-8917-bdd768856115:autoScalingGroupName/university-enrollment-20260505-091645-asg:policyName/university-enrollment-20260505-091645-cpu-85` | Active | `EC2 > Auto Scaling Groups > Automatic scaling` | Step scaling `+3` |
| SES | Verified Identity | `oskarortiz124@gmail.com` | `oskarortiz124@gmail.com` | Verified | `SES > Verified identities` | Identity type `EMAIL_ADDRESS` |
| SES | Verified Identity | `a70310794@gmail.com` | `a70310794@gmail.com` | Verified | `SES > Verified identities` | Identity type `EMAIL_ADDRESS` |

## Notes

- The ALB and target group names are truncated because AWS name length limits apply.
- The Lambda target group shows `Target.HealthCheckDisabled`, which is expected for this setup.
- The EC2 target group currently reports both backend instances as healthy.
