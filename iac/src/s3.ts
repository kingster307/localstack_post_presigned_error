import * as aws from '@pulumi/aws';
import {PulumiUtil} from "./pulumi-provider";

export const reportsOutputPrefix = 'reports/';
export const presignedUrlPrefix = 'presigned_url_prefix/';

export const siteBucket = new aws.s3.Bucket(
    'proj-bucket',
    {
        bucketPrefix: 'proj-bucket-prefix-',
        forceDestroy: true,
        versioning: {
            enabled: false
        },
        acl: 'private',
        corsRules: [{
            allowedHeaders: ['*'],
            allowedMethods: [
                'PUT',
                'POST'
            ],
            allowedOrigins: ['*'],
            exposeHeaders: ['ETag'],
            maxAgeSeconds: 3000
        }]
    },
    {provider: PulumiUtil.awsProvider}
);