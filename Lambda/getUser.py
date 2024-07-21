import boto3
import json

def lambda_handler(event, context):
    # Initialize a DynamoDB client
    dynamodb = boto3.resource('dynamodb')

    # Reference to the 'Users' table
    users_table = dynamodb.Table('Users')
    body = json.loads(event['body'])
    # Extract the unique ID of the user from the event
    user_id = body["id"]

    # Fetch the user data from the DynamoDB table using the user ID
    response = users_table.get_item(
        Key={
            'id': user_id  # Use the user ID as the primary key
        }
    )

    # Check if the user data was found
    if 'Item' in response:
        user_data = response['Item']
        return_message = f'User data retrieved successfully for ID: {user_id}.'
        status_code = 200
    else:
        user_data = {}
        return_message = f'User data not found for ID: {user_id}.'
        status_code = 404

    # Return the user data and a message
    return {
        'statusCode': status_code,
        'body': json.dumps({
            'message': return_message,
            'userData': user_data
        })
    }
