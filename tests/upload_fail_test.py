import os
import json
import requests


def presigned_url_lambda_apigw_url() -> str:
    with open(f"../pulumi_output.json", "r") as read_file:
        pulumi_output = json.load(read_file)

    api_id = pulumi_output["api"]["restAPI"]["id"]
    api_stage = pulumi_output["api"]["stage"]["stageName"]
    the_sauce = ".execute-api.localhost.localstack.cloud:4566/"
    return "http://" + api_id + the_sauce + api_stage + "/get_presigned_url"


def change_host_of_url(url: str):
    url = "http://" + url.split(":4566/")[1] + "." + os.environ["LOCALSTACK_HOSTNAME"] + ":4566"
    return url


def format_res(resp) -> dict:
    resp_dict = {
        "status": resp.status_code,
        "url": resp.url,
        "redirect": resp.is_redirect,
        "headers": resp.headers,
    }
    try:
        resp_dict["content"] = json.loads(resp.content)
        resp_dict["links"] = resp.links
    except Exception:
        resp_dict["content"] = resp.content

    return resp_dict


def test_error_no_files():
    items = {
        "L": "large.csv",
        "XL": "larger.csv",
        "XXL": "largest.csv"
    }
    for meta, file_name in items.items():
        # get the apigw url for s3_create_presigned_url_lambda
        create_presigned_url = presigned_url_lambda_apigw_url()

        # query string passes in metadata into lambda for presigned post
        query_string = {
            "action": "upload",
            "file_name": f"{file_name}",
            "very_important_meta": meta,
            "content_type": f"{os.path.splitext(file_name)[1][1:]}",
        }

        # get presigned url
        res = format_res(requests.get(create_presigned_url, params=query_string))

        # parse out url & fields
        post_url = res["content"]["data"]["url"]
        post_fields = res["content"]["data"]["fields"]
        # add file as last in post fields
        files = {"file" : open(f"./test_data/{query_string['file_name']}", "rb")}

        # TODO looks like despite hitting apigw presigned 3 times it returns the same key all 3 times -> can be seen in print
        # s3_create_presigned_url_lambda is designed to give unique keys even if key name is the same
        # seems like localstack is caching & reusing previous results
        # ============================================================================
        # produces 500 error -> view ./logs for more infor
        # make post request to presigned url | should trigger lambda & display logs
        res2 = format_res(requests.post(change_host_of_url(post_url), data=post_fields, files=files))

        print(res2)
