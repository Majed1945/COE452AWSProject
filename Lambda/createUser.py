import boto3
import json
import uuid  # Import the UUID library

def lambda_handler(event, context):
    # Initialize a DynamoDB client
    dynamodb = boto3.resource('dynamodb')

    # Reference to the 'Users' table
    table = dynamodb.Table('Users')

    # Generate a unique UUID for the new user
    unique_id = str(uuid.uuid4())

    body = json.loads(event['body'])
    # Extract user data from the event and add the generated UUID
    user_data = {
        'id': unique_id,  # Use the generated UUID as the user ID
        'name': body["name"],
        'email': body["email"],
        'phone': body["phone"]
    }

    # Insert the user data into the DynamoDB table
    response = table.put_item(Item=user_data)

    # Check if the insert operation was successful
    if response.get('ResponseMetadata', {}).get('HTTPStatusCode') == 200:
        return_message = 'User created successfully.'
        status_code = 200
    else:
        return_message = 'Failed to create user.'
        status_code = response.get('ResponseMetadata', {}).get('HTTPStatusCode', 500)

    # Return the user data and a success message
    return {
        'statusCode': status_code,
        'body': json.dumps({
            'message': return_message,
            'userData': user_data
        })
    }
