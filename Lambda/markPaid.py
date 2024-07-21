import boto3
import json

def mark_transaction_as_paid(transaction_table, transaction_id, user_id):
    response = transaction_table.update_item(
        Key={'id': transaction_id},
        UpdateExpression='SET is_paid = :val',
        ExpressionAttributeValues={':val': True, ':user_id': user_id},  # Define :user_id attribute value
        ConditionExpression='userID = :user_id',  # Use :user_id in the ConditionExpression
        ReturnValues='UPDATED_NEW'
    )
    return response

def lambda_handler(event, context):
    dynamodb = boto3.resource('dynamodb')
    transaction_table = dynamodb.Table('Transactions')
    body = json.loads(event['body'])
    # Extract details from the event

    transaction_id = body['transactionID']
    user_id = body['userID']

    # Update the transaction
    response = mark_transaction_as_paid(transaction_table, transaction_id, user_id)

    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Transaction marked as paid', 'response': response})
    }
