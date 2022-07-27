# Localstack onObjectCreated Issue

## Getting started
1) run `make all`
   1) make all will build everything, install deps, and run test
      1) test will say pass since we aren't checking any returns
   2) flow of test 
      1) hit apigw route get presigned post url
      2) post to url 
      3) S3 presigned post triggers lambda

## Issue
getting 500 on the POST.

Tests have some comments within for easier debugging [here](./tests/upload_fail_test.py)

logs can be seen [here](./tests/logs)
