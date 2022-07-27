import * as pulumi from '@pulumi/pulumi';
import * as aws from '@pulumi/aws';
import {PulumiUtil} from './pulumi-provider'
import {siteBucket, presignedUrlPrefix} from './s3'
import {lambdaExecPolicy,lambdaLoggingPolicy} from './policies'

// allow lambda to write reports under /reports in s3 bucket
export const apiGwFuelUploadLambdaS3 = new aws.iam.Policy(
    's3CreatePresignedUrlLambdaS3',
    {
        path: '/',
        description: 'IAM policy allowing lambda to write fuel pricing files to S3',
        policy: {
            Version: '2012-10-17',
            Statement: [
                {
                    Effect: 'Allow',
                    Action: ['s3:*'],
                    Resource: [
                        pulumi.interpolate`${siteBucket.arn}/${presignedUrlPrefix}`,
                        pulumi.interpolate`${siteBucket.arn}/${presignedUrlPrefix}**`
                    ]
                }
            ]
        },
    },
    {provider: PulumiUtil.awsProvider}
);


export const apiGwFuelUploadLambdaRole = new aws.iam.Role(
    's3CreatePresignedUrlLambdaRole',
    {
        assumeRolePolicy: {
            Version: '2012-10-17',
            Statement: [
                {
                    Action: 'sts:AssumeRole',
                    Principal: {
                        Service: 'lambda.amazonaws.com'
                    },
                    Effect: 'Allow'
                }
            ]
        },
    },
    {provider: PulumiUtil.awsProvider}
);

const apiGwFuelUploadLambdaLoggingRoleAttachment = new aws.iam.RolePolicyAttachment(
    's3CreatePresignedUrlLambdaLoggingRoleAttachment',
    {
        role: apiGwFuelUploadLambdaRole.name,
        policyArn: lambdaLoggingPolicy.arn
    },
    {provider: PulumiUtil.awsProvider}
);

const apiGwFuelUploadLambdaExecPolicyRoleAttachment = new aws.iam.RolePolicyAttachment(
    's3CreatePresignedUrlLambdaExecPolicyRoleAttachment',
    {
        role: apiGwFuelUploadLambdaRole.name,
        policyArn: lambdaExecPolicy.arn
    },
    {provider: PulumiUtil.awsProvider}
);

const apiGwFuelUploadLambdaWriteReportS3RoleAttachment = new aws.iam.RolePolicyAttachment(
    's3CreatePresignedUrlLambdaWriteReportS3RoleAttachment',
    {
        role: apiGwFuelUploadLambdaRole.name,
        policyArn: apiGwFuelUploadLambdaS3.arn
    },
    {provider: PulumiUtil.awsProvider}
);

export const s3_create_presigned_url_lambda = new aws.lambda.Function(
    's3CreatePresignedUrlLambda',
    {
        code: new pulumi.asset.AssetArchive({
            "lambda_function.py": new pulumi.asset.FileAsset("../s3_create_presigned_url_lambda/lambda_function.py"),
        }),
        role: apiGwFuelUploadLambdaRole.arn,
        handler: 'lambda_function.lambda_handler',
        runtime: 'python3.7',
        memorySize: 128,
        timeout: 29,
        environment: {
            variables: {
                BUCKET: siteBucket.bucket,
                PREFIX: presignedUrlPrefix,
                ENV: PulumiUtil.env,
            }
        },
    },
    {
        provider: PulumiUtil.awsProvider,
        dependsOn: [
            apiGwFuelUploadLambdaLoggingRoleAttachment,
            apiGwFuelUploadLambdaExecPolicyRoleAttachment,
            apiGwFuelUploadLambdaWriteReportS3RoleAttachment,
        ]
    }
);
