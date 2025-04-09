def lambda_handler(event, context):
    print("Hello World from S3 event ✅")
    return {
        'statusCode': 200,
        'body': 'Hello World from Lambda!'
    }
