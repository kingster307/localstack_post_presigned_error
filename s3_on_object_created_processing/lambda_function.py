import urllib.parse


def lambda_handler(event, context):
    objects = []
    for record in event["Records"]:
        bucket = record["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(record["s3"]["object"]["key"], encoding="utf-8")

        print("bucket - " + bucket + "\n")
        print("key - " + key + "\n")
        objects.append(f"{bucket}/{key}")
    return objects
