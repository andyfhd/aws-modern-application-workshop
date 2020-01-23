aws cloudformation create-stack --stack-name MythicalMysfitsCoreStack --capabilities CAPABILITY_NAMED_IAM --template-body file://module-2/cfn/core.yml   

docker build ./module-2/webapi -t $(aws sts get-caller-identity --query Account --output text).dkr.ecr.$(aws configure get region).amazonaws.com/mythicalmysfits/service:latest

aws ecr create-repository --repository-name mythicalmysfits/service

$(aws ecr get-login --no-include-email)

docker push $(aws sts get-caller-identity --query Account --output text).dkr.ecr.$(aws configure get region).amazonaws.com/mythicalmysfits/service:latest

aws ecs create-cluster --cluster-name MythicalMysfits-Cluster

aws logs create-log-group --log-group-name mythicalmysfits-logs



cat module-2/aws-cli/task-definition.json \
| jq ".taskRoleArn |= $(aws cloudformation describe-stacks --stack-name MythicalMysfitsCoreStack | jq '.Stacks[0].Outputs[] | select(.OutputKey == "ECSTaskRole").OutputValue')" \
| jq ".executionRoleArn |= $(aws cloudformation describe-stacks --stack-name MythicalMysfitsCoreStack | jq '.Stacks[0].Outputs[] | select(.OutputKey == "EcsServiceRole").OutputValue')" \
| jq ".containerDefinitions[0].image |= \"$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$(aws configure get region).amazonaws.com/mythicalmysfits/service:latest\"" \
| jq ".containerDefinitions[0].logConfiguration.options[\"awslogs-region\"] |= \"$(aws configure get region)\"" \
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


cat module-2/aws-cli/service-definition.json \
| jq -r ".networkConfiguration.awsvpcConfiguration.securityGroups |= [$(aws cloudformation describe-stacks --stack-name MythicalMysfitsCoreStack | jq '.Stacks[0].Outputs[] | select(.OutputKey == "FargateContainerSecurityGroup").OutputValue')]" \
| jq -r ".networkConfiguration.awsvpcConfiguration.subnets[0] |= $(aws cloudformation describe-stacks --stack-name MythicalMysfitsCoreStack | jq '.Stacks[0].Outputs[] | select(.OutputKey == "PrivateSubnetOne").OutputValue')" \
| jq -r ".networkConfiguration.awsvpcConfiguration.subnets[1] |= $(aws cloudformation describe-stacks --stack-name MythicalMysfitsCoreStack | jq '.Stacks[0].Outputs[] | select(.OutputKey == "PrivateSubnetTwo").OutputValue')" \
| jq -r ".loadBalancers[0].targetGroupArn |= $(aws elbv2 describe-target-groups | jq '.TargetGroups[0].TargetGroupArn')" \
> module-2/aws-cli/service-definition.json

aws ecs create-service --cli-input-json file://module-2/aws-cli/service-definition.json

# replace environment.prod.ts
./module-2/deploy-frontend-scripts/deploy_frontend.sh


PROJECT_NAME="mythical-mysfits"
S3_ARTIFACTS_BUCKET_NAME="$PROJECT_NAME-artifacts-$(aws sts get-caller-identity --query Account --output text)"

aws s3 mb s3://$S3_ARTIFACTS_BUCKET_NAME

cat module-2/aws-cli/artifacts-bucket-policy.json \
| jq ".Statement[].Principal.AWS[0] |= $(aws cloudformation describe-stacks --stack-name MythicalMysfitsCoreStack | jq '.Stacks[0].Outputs[] | select(.OutputKey == "CodeBuildRole").OutputValue')" \
| jq ".Statement[].Principal.AWS[1] |= $(aws cloudformation describe-stacks --stack-name MythicalMysfitsCoreStack | jq '.Stacks[0].Outputs[] | select(.OutputKey == "CodePipelineRole").OutputValue')" \
| jq ".Statement[].Resource[0] |= \"arn:aws:s3:::$S3_ARTIFACTS_BUCKET_NAME/*\"" \
| jq ".Statement[].Resource[1] |= \"arn:aws:s3:::$S3_ARTIFACTS_BUCKET_NAME\"" \
> module-2/aws-cli/artifacts-bucket-policy.json

aws s3api put-bucket-policy --bucket $S3_ARTIFACTS_BUCKET_NAME --policy file://module-2/aws-cli/artifacts-bucket-policy.json


aws codecommit create-repository --repository-name MythicalMysfitsService-Repository

cat module-2/aws-cli/code-build-project.json \
| jq ".environment.environmentVariables[0].value |= $(aws sts get-caller-identity --query Account)" \
| jq ".serviceRole |= $(aws cloudformation describe-stacks --stack-name MythicalMysfitsCoreStack | jq '.Stacks[0].Outputs[] | select(.OutputKey == "CodeBuildRole").OutputValue')" \
> module-2/aws-cli/code-build-project.json

aws codebuild create-project --cli-input-json file://module-2/aws-cli/code-build-project.json


cat module-2/aws-cli/code-pipeline.json \
| jq ".pipeline.roleArn |= $(aws cloudformation describe-stacks --stack-name MythicalMysfitsCoreStack | jq '.Stacks[0].Outputs[] | select(.OutputKey == "CodePipelineRole").OutputValue')" \
| jq ".pipeline.artifactStore.location |= \"$S3_ARTIFACTS_BUCKET_NAME\"" \
> module-2/aws-cli/code-pipeline.json

aws codepipeline create-pipeline --cli-input-json file://module-2/aws-cli/code-pipeline.json

cat module-2/aws-cli/ecr-policy.json \
| jq ".Statement[].Principal.AWS[0] |= $(aws cloudformation describe-stacks --stack-name MythicalMysfitsCoreStack | jq '.Stacks[0].Outputs[] | select(.OutputKey == "CodeBuildRole").OutputValue')" \
> module-2/aws-cli/ecr-policy.json

aws ecr set-repository-policy --repository-name mythicalmysfits/service --policy-text file://module-2/aws-cli/ecr-policy.json

rm -drf MythicalMysfitsService-Repository/
git clone https://git-codecommit.us-east-1.amazonaws.com/v1/repos/MythicalMysfitsService-Repository
cp -r ./module-2/webapi/* ./MythicalMysfitsService-Repository/
cd ./MythicalMysfitsService-Repository/
git add .
git commit -m "I changed the age of one of the mysfits."
git push
cd ../..



aws dynamodb create-table --cli-input-json file://module-3/aws-cli/dynamodb-table.json

aws dynamodb batch-write-item --request-items file://./module-3/aws-cli/populate-dynamodb.json

cp -r ./module-3/webapi/* ./MythicalMysfitsService-Repository/

./module-3/deploy-frontend-scripts/deploy_frontend.sh


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
