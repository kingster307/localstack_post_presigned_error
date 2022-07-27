import * as pulumi from '@pulumi/pulumi';
import * as aws from '@pulumi/aws';
import {PulumiUtil} from './pulumi-provider'
import {presignedUrlPrefix, reportsOutputPrefix, siteBucket} from './s3';
import {
    lambdaExecPolicy,
    lambdaLoggingPolicy
} from './policies';


export const s3OnObjectCreatedLambdaWriteReportS3 = new aws.iam.Policy(
    's3OnObjectCreatedLambdaWriteReportS3',
    {
        path: '/',
        description: 'IAM policy allowing lambda to write reports',
        policy: {
            Version: '2012-10-17',
            Statement: [
                {
                    Effect: 'Allow',
                    Action: [
                        's3:*'
                    ],
                    Resource: [
                        pulumi.interpolate`${siteBucket.arn}/${presignedUrlPrefix}`,
                        pulumi.interpolate`${siteBucket.arn}/${presignedUrlPrefix}**`,
                        pulumi.interpolate`${siteBucket.arn}/${reportsOutputPrefix}`,
                        pulumi.interpolate`${siteBucket.arn}/${reportsOutputPrefix}**`
                    ]
                }
            ]
        },
    },
    {provider: PulumiUtil.awsProvider}
);

export const s3OnObjectCreatedLambdaRole = new aws.iam.Role(
    's3OnObjectCreatedLambdaRole',
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

const s3OnObjectCreatedLambdaLoggingRoleAttachment = new aws.iam.RolePolicyAttachment(
    's3OnObjectCreatedLambdaLoggingRoleAttachment',
    {
        role: s3OnObjectCreatedLambdaRole.name,
        policyArn: lambdaLoggingPolicy.arn
    },
    {provider: PulumiUtil.awsProvider}
);

const s3OnObjectCreatedLambdaExecPolicyRoleAttachment = new aws.iam.RolePolicyAttachment(
    's3OnObjectCreatedLambdaExecPolicyRoleAttachment',
    {
        role: s3OnObjectCreatedLambdaRole.name,
        policyArn: lambdaExecPolicy.arn
    },
    {provider: PulumiUtil.awsProvider}
);

const s3OnObjectCreatedLambdaWriteReportS3RoleAttachment = new aws.iam.RolePolicyAttachment(
    's3OnObjectCreatedLambdaWriteReportS3RoleAttachment',
    {
        role: s3OnObjectCreatedLambdaRole.name,
        policyArn: s3OnObjectCreatedLambdaWriteReportS3.arn
    },
    {provider: PulumiUtil.awsProvider}
);

export const s3_on_object_created_lambda = new aws.lambda.Function(
    's3OnObjectCreatedLambda',
    {
        code: new pulumi.asset.AssetArchive({
            "lambda_function.py": new pulumi.asset.FileAsset("../s3_on_object_created_processing/lambda_function.py"),
        }),
        role: s3OnObjectCreatedLambdaRole.arn,
        handler: 'lambda_function.lambda_handler',
        runtime: 'python3.7',
        memorySize: 512,
        timeout: 15 * 60,
    },
    {
        provider: PulumiUtil.awsProvider,
        dependsOn: [
            s3OnObjectCreatedLambdaLoggingRoleAttachment,
            s3OnObjectCreatedLambdaExecPolicyRoleAttachment,
            s3OnObjectCreatedLambdaWriteReportS3RoleAttachment
        ]
    }
);

// log group for lambda. only keeps logs for 3 days.
export const s3OnObjectCreatedLambdaLogGroup = new aws.cloudwatch.LogGroup(
    's3OnObjectCreatedLambdaLogGroup',
    {
        name: pulumi.interpolate`/aws/lambda/${s3_on_object_created_lambda.name}`,
        retentionInDays: 3,
    },
    {provider: PulumiUtil.awsProvider}
);


export const s3OnObjectCreatedLambdaEvent = siteBucket.onObjectCreated(
    's3OnObjectCreatedLambdaEvent',
    s3_on_object_created_lambda,
    {
        event: '*',
        filterPrefix: presignedUrlPrefix
    },
    {provider: PulumiUtil.awsProvider}
);
