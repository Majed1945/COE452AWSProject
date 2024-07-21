import boto3
import json

def lambda_handler(event, context):
    # Initialize a DynamoDB client
    dynamodb = boto3.resource('dynamodb')

    # References to the 'Users' and 'Transactions' tables
    users_table = dynamodb.Table('Users')
    transactions_table = dynamodb.Table('Transactions')
    body = json.loads(event['body'])
    # Extract the unique ID of the user to be deleted from the event
    user_id = body["id"]

    # Step 1: Delete the user data from the Users table
    user_response = users_table.delete_item(
        Key={
            'id': user_id  # Use the user ID as the primary key
        }
    )

    # Step 2: Scan and delete all transactions associated with the user
    transactions_response = transactions_table.scan(
        FilterExpression=boto3.dynamodb.conditions.Attr('userID').eq(user_id)
    )

    for transaction in transactions_response['Items']:
        transactions_table.delete_item(
            Key={
                'id': transaction['id']  # Use transaction ID as the primary key for deletion
            }
        )

    # Check if the user deletion operation was successful
    if user_response.get('ResponseMetadata', {}).get('HTTPStatusCode') == 200:
        user_message = f'User with ID: {user_id} deleted successfully.'
    else:
        user_message = f'Failed to delete user with ID: {user_id}.'

    # Return a message indicating the result of the operations
    return {
        'statusCode': user_response.get('ResponseMetadata', {}).get('HTTPStatusCode', 500),
        'body': json.dumps({
            'userMessage': user_message,
            'transactionMessage': 'Associated transactions deleted successfully.' if transactions_response['Items'] else 'No associated transactions to delete.'
        })
    }
