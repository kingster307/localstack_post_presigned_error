import * as aws from '@pulumi/aws';
import * as awsx from '@pulumi/awsx';
import * as pulumi from '@pulumi/pulumi';
import {s3_create_presigned_url_lambda} from "./s3_create_presigned_url_lambda";
import {PulumiUtil} from './pulumi-provider'

// create log group for api access
export const apiAccessLogGroup = new aws.cloudwatch.LogGroup(
  'api-access-log-group',
  {
    name: `/api-gw/api-access-log-group`,
    retentionInDays: 3
  },
  { provider: PulumiUtil.awsProvider }
);


const responseParameters = {
  'gatewayresponse.header.method.response.header.Access-Control-Allow-Headers': `'Content-Type, Authorization, X-Amz-Date, X-Api-Key, X-Amz-Security-Token, Origin, X-Requested-With, Accept'`,
  'gatewayresponse.header.method.response.header.Access-Control-Allow-Methods': `'GET, POST, OPTIONS, PUT, PATCH, DELETE'`,
  'gatewayresponse.header.method.response.header.Access-Control-Allow-Origin': `'*'`
};

const mockRoute = (body: any, requireApiKey: boolean = false): any => {
  const ret: any = {
    'consumes': ['application/json'],
    'produces': ['application/json'],
    'responses': {
      '200': {
        'description': '200 response',
        'schema': {
          'type': 'object'
        },
        'headers': {
          'Access-Control-Allow-Origin': {
            'type': 'string'
          },
          'Access-Control-Allow-Methods': {
            'type': 'string'
          },
          'Access-Control-Allow-Headers': {
            'type': 'string'
          }
        }
      }
    },
    'x-amazon-apigateway-integration': {
      'responses': {
        'default': {
          'statusCode': 200,
          'responseParameters': {
            'method.response.header.Access-Control-Allow-Methods': '\'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT\'',
            'method.response.header.Access-Control-Allow-Headers': '\'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token\'',
            'method.response.header.Access-Control-Allow-Origin': '\'*\''
          },
          'responseTemplates': {
            'application/json': body ? JSON.stringify(body) : ''
          }
        }
      },
      'requestTemplates': {
        'application/json': '{"statusCode": 200}'
      },
      'passthroughBehavior': 'when_no_match',
      'type': 'mock'
    }
  };
  if (requireApiKey) {
    ret.security = [
      {
        'api_key': []
      }
    ];
  }
  return ret;
};

export const api = new awsx.apigateway.API(
  'apiGateway',
  {
    deploymentArgs: {
      description: 'API testing onObjectCreated Localstack bug'
    },
    routes: [
      // This enables CORS on all routes.
      {
        path: '/{proxy+}',
        method: 'OPTIONS',
        data: mockRoute(null, true)
      },
      {
        path: '/get_presigned_url',
        method: 'GET',
        apiKeyRequired: true,
        eventHandler: s3_create_presigned_url_lambda
      },
    ],
    gatewayResponses: {
      'UNAUTHORIZED': {
        statusCode: 401,
        responseParameters,
        responseTemplates: {
          'application/json': '{"message":$context.error.messageString}'
        }
      },
      'ACCESS_DENIED': {
        statusCode: 401,
        responseParameters,
        responseTemplates: {
          'application/json': '{"message":$context.error.messageString}'
        }
      },
      'MISSING_AUTHENTICATION_TOKEN': {
        statusCode: 401,
        responseParameters,
        responseTemplates: {
          'application/json': '{"message":$context.error.messageString}'
        }
      },
      'EXPIRED_TOKEN': {
        statusCode: 403,
        responseParameters,
        responseTemplates: {
          'application/json': '{"message":$context.error.messageString}'
        }
      }
    },
    stageName: 'api',
    apiKeySource: 'HEADER',
    restApiArgs: {
      binaryMediaTypes: ['needs_this_so_pulumi_does_not_add/default_binary_media_type']
    },
    stageArgs: {
      description: 'Stage api',
      accessLogSettings: {
        destinationArn: apiAccessLogGroup.arn,
        format: JSON.stringify({
          'requestId': '$context.requestId',
          'ip': '$context.identity.sourceIp',
          'caller': '$context.identity.caller',
          'user': '$context.identity.user',
          'requestTime': '$context.requestTime',
          'httpMethod': '$context.httpMethod',
          'resourcePath': '$context.resourcePath',
          'status': '$context.status',
          'protocol': '$context.protocol',
          'responseLength': '$context.responseLength'
        })
      }
    }
  },
  { provider: PulumiUtil.awsProvider }
);

export const apiStageName = api.stage.stageName;
// export the auto-generated API Gateway URL which includes stage name.
export const apiGwUrl = api.url;
// export only domain portion for use by cloudwatch.
export const apiDomain = pulumi.all([api.url, api.stage.stageName])
  .apply(([url, stage]) => url.replace('/' + stage, '').replace(/(\/|https?:)/ig, ''));
