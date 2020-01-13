cat module-2/aws-cli/task-definition.json \
| jq ".taskRoleArn |= $(aws cloudformation describe-stacks --stack-name MythicalMysfitsCoreStack | jq '.Stacks[0].Outputs[] | select(.OutputKey == "ECSTaskRole").OutputValue')" \
| jq ".executionRoleArn |= $(aws cloudformation describe-stacks --stack-name MythicalMysfitsCoreStack | jq '.Stacks[0].Outputs[] | select(.OutputKey == "EcsServiceRole").OutputValue')" \
| jq ".containerDefinitions[0].image |= \"$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$(aws configure get region).amazonaws.com/mythicalmysfits/service:latest\"" \
| jq  ".containerDefinitions[0].logConfiguration.options[\"awslogs-region\"] |= \"$(aws configure get region)\"" \
> module-2/aws-cli/task-definition.json

aws ecs register-task-definition --cli-input-json file://module-2/aws-cli/task-definition.json

aws elbv2 create-load-balancer --name mysfits-nlb --scheme internet-facing --type network --subnets \
$(aws cloudformation describe-stacks --stack-name MythicalMysfitsCoreStack | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PublicSubnetOne").OutputValue') \
$(aws cloudformation describe-stacks --stack-name MythicalMysfitsCoreStack | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PublicSubnetTwo").OutputValue')


aws elbv2 create-target-group --name MythicalMysfits-TargetGroup --port 8080 --protocol TCP --target-type ip \
--vpc-id $(aws cloudformation describe-stacks --stack-name MythicalMysfitsCoreStack | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "VPCId").OutputValue') \
--health-check-interval-seconds 10 --health-check-protocol HTTP --healthy-threshold-count 3 --unhealthy-threshold-count 3

aws elbv2 create-listener --default-actions \
TargetGroupArn=$(aws elbv2 describe-target-groups | jq -r '.TargetGroups[0].TargetGroupArn'),Type=forward \
--load-balancer-arn $(aws elbv2 describe-load-balancers | jq -r '.LoadBalancers[0].LoadBalancerArn') --port 80 --protocol TCP


#todo
cat module-2/aws-cli/service-definition.json \
| jq -r ".networkConfiguration.awsvpcConfiguration.securityGroups |= [$(aws cloudformation describe-stacks --stack-name MythicalMysfitsCoreStack | jq '.Stacks[0].Outputs[] | select(.OutputKey == "FargateContainerSecurityGroup").OutputValue')]" \
| jq -r ".networkConfiguration.awsvpcConfiguration.subnets[0] |= $(aws cloudformation describe-stacks --stack-name MythicalMysfitsCoreStack | jq '.Stacks[0].Outputs[] | select(.OutputKey == "PrivateSubnetOne").OutputValue')" \
| jq -r ".networkConfiguration.awsvpcConfiguration.subnets[1] |= $(aws cloudformation describe-stacks --stack-name MythicalMysfitsCoreStack | jq '.Stacks[0].Outputs[] | select(.OutputKey == "PrivateSubnetTwo").OutputValue')" 

{   
    "Stacks": [
        {
            "StackId": "arn:aws:cloudformation:us-east-1:482643299915:stack/MythicalMysfitsCoreStack/7d1a0970-35e6-11ea-b4a5-0ac97ebd7097",
            "StackName": "MythicalMysfitsCoreStack",
            "Description": "This stack deploys the core network infrastructure and IAM resources to be used for a service hosted in Amazon ECS using AWS Fargate.",
            "CreationTime": "2020-01-13T09:24:24.796Z",
            "RollbackConfiguration": {},
            "StackStatus": "CREATE_COMPLETE",
            "DisableRollback": false,
            "NotificationARNs": [],
            "Capabilities": [
                "CAPABILITY_NAMED_IAM"
            ],
            "Outputs": [
                {
                    "OutputKey": "CurrentAccount",
                    "OutputValue": "482643299915",
                    "Description": "The ID of the Account being used.",
                    "ExportName": "MythicalMysfitsCoreStack:CurrentAccount"
                },
                {
                    "OutputKey": "FargateContainerSecurityGroup",
                    "OutputValue": "sg-0d7adace005e79b1d",
                    "Description": "A security group used to allow Fargate containers to receive traffic",
                    "ExportName": "MythicalMysfitsCoreStack:FargateContainerSecurityGroup"
                },
                {
                    "OutputKey": "PublicSubnetOne",
                    "OutputValue": "subnet-03fb1e696c8f9595c",
                    "Description": "Public subnet one",
                    "ExportName": "MythicalMysfitsCoreStack:PublicSubnetOne"
                },
                {
                    "OutputKey": "ECSTaskRole",
                    "OutputValue": "arn:aws:iam::482643299915:role/MythicalMysfitsCoreStack-ECSTaskRole-1ERBVGAK5Q26B",
                    "Description": "The ARN of the ECS Task role",
                    "ExportName": "MythicalMysfitsCoreStack:ECSTaskRole"
                },
                {
                    "OutputKey": "PrivateSubnetTwo",
                    "OutputValue": "subnet-0429f34a2b3dfa350",
                    "Description": "Private subnet two",
                    "ExportName": "MythicalMysfitsCoreStack:PrivateSubnetTwo"
                },
                {
                    "OutputKey": "CurrentRegion",
                    "OutputValue": "us-east-1",
                    "Description": "The string representation of the region being used.",
                    "ExportName": "MythicalMysfitsCoreStack:CurrentRegion"
                },
                {
                    "OutputKey": "VPCId",
                    "OutputValue": "vpc-0562b5865caeed539",
                    "Description": "The ID of the VPC that this stack is deployed in",
                    "ExportName": "MythicalMysfitsCoreStack:VPCId"
                },
                {
                    "OutputKey": "PublicSubnetTwo",
                    "OutputValue": "subnet-09dee5f75a367a367",
                    "Description": "Public subnet two",
                    "ExportName": "MythicalMysfitsCoreStack:PublicSubnetTwo"
                },
                {
                    "OutputKey": "CodeBuildRole",
                    "OutputValue": "arn:aws:iam::482643299915:role/MythicalMysfitsServiceCodeBuildServiceRole",
                    "Description": "The ARN of the CodeBuild role",
                    "ExportName": "MythicalMysfitsCoreStack:MythicalMysfitsServiceCodeBuildServiceRole"
                },
                {
                    "OutputKey": "CodePipelineRole",
                    "OutputValue": "arn:aws:iam::482643299915:role/MythicalMysfitsServiceCodePipelineServiceRole",
                    "Description": "The ARN of the CodePipeline role",
                    "ExportName": "MythicalMysfitsCoreStack:MythicalMysfitsServiceCodePipelineServiceRole"
                },
                {
                    "OutputKey": "EcsServiceRole",
                    "OutputValue": "arn:aws:iam::482643299915:role/MythicalMysfitsCoreStack-EcsServiceRole-7WFD6U4LS3BG",
                    "Description": "The ARN of the ECS Service role",
                    "ExportName": "MythicalMysfitsCoreStack:EcsServiceRole"
                },
                {
                    "OutputKey": "PrivateSubnetOne",
                    "OutputValue": "subnet-0be7a3bd051965fff",
                    "Description": "Private subnet one",
                    "ExportName": "MythicalMysfitsCoreStack:PrivateSubnetOne"
                }
            ],
            "Tags": [],
            "EnableTerminationProtection": false,
            "DriftInformation": {
                "StackDriftStatus": "NOT_CHECKED"
            }
        }
    ]
}
