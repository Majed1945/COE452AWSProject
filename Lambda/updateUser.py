import boto3
import json

def lambda_handler(event, context):
    # Initialize a DynamoDB client
    dynamodb = boto3.resource('dynamodb')

    # Reference to the 'Users' table
    table = dynamodb.Table('Users')
    body = json.loads(event['body'])
    # Extract the user ID from the event
    user_id = body["id"]

    # Prepare update expression, attribute values, and attribute names
    update_expression = 'SET '
    expression_attribute_values = {}
    expression_attribute_names = {}

    # Add each attribute to the update expression
    for key in body:
        if key != 'id':
            placeholder = f"#{key}"
            update_expression += f"{placeholder} = :{key}, "
            expression_attribute_values[f":{key}"] = event[key]
            expression_attribute_names[placeholder] = key

    # Remove trailing comma and space
    update_expression = update_expression.rstrip(', ')

    # Update the user data in the DynamoDB table
    response = table.update_item(
        Key={'id': user_id},
        UpdateExpression=update_expression,
        ExpressionAttributeValues=expression_attribute_values,
        ExpressionAttributeNames=expression_attribute_names  # Include this in the call
    )

    # Return a success message
    return {
        'statusCode': 200,
        'body': json.dumps('User updated successfully.')
    }
