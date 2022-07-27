# Localstack onObjectCreated Issue

## Getting started
1) run `make all`
   1) make all will build everything, install deps, and run test
      1) test will say pass since we aren't checking any returns
   2) flow of test 
      1) hit apigw route get presigned post url
      2) post to url 
      3) this should trigger [s3_on_object_created_processing](./s3_on_object_created_processing/lambda_function.py)
         1) This should emit logs but doesn't
      4) run `make get-logs-aws` to view logs