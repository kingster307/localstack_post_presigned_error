import os
import uuid
import boto3
import json


def lambda_handler(event, context):
    print(event)

    region = os.getenv("AWS_REGION", 'us-west-2')
    bucket = os.environ["BUCKET"]
    key = os.environ["PREFIX"] + str(uuid.uuid4())
    params = event["queryStringParameters"]
    meta = {
        "content-type": params.get("content_type"),
        "x-amz-meta-action": params.get("action", ""),
        "x-amz-meta-filename": params.get("file_name", ""),
        "x-amz-meta-very-important": params.get("very_important_meta", ""),
    }

    res = create_presigned_post(
        bucket,
        key,
        3600,
        meta,
        region
    )

    return {
        "statusCode": 200,
        "headers": {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Credentials": "true",
            "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
        },
        "body": json.dumps({"status": True, "message": None, "data": res}),
    }


def create_presigned_post(
        bucket_name: str, object_name: str, expiration: int = 3600, metadata: dict = None, region="us-west-2"
):
    s3_client = boto3.client("s3", region_name=region)

    metadata = metadata if metadata else {}
    conditions = [
        ["eq", "$key", object_name],  # key must match
        [
            "content-length-range",
            1,
            1000000000,
        ],  # file size not zero and no more than 1GB
    ]
    for key, value in metadata.items():
        conditions.append(
            ["eq", "$" + key, value]
        )  # require all other values from metadata be present
    return s3_client.generate_presigned_post(
        Bucket=bucket_name,
        Key=object_name,
        Fields=metadata,
        ExpiresIn=expiration,
        Conditions=conditions,
    )
