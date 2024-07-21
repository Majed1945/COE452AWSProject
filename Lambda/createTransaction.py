import json
import boto3
import uuid
from decimal import Decimal

def add_transaction(table, amount, category, date, title, user_id):
    # Generate a unique UUID for the transaction
    transaction_id = str(uuid.uuid4())

    # Add a transaction to the DynamoDB table
    response = table.put_item(
        Item={
            'id': transaction_id,  # Use the UUID as the transaction ID
            'amount': amount,
            'category': category,
            'date': date,
            'title': title,
            'userID': user_id
        }
    )
    return response

def lambda_handler(event, context):
    # Initialize a boto3 DynamoDB resource
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('Transactions')  # Replace with your table name

    # Extract transaction details from the event
    body = json.loads(event['body'])

    amount = Decimal(str(body["amount"]))
    category = body["category"]
    date = body["date"]
    title = body["title"]
    user_id = body["userID"]

    # Ensure all necessary details are provided
    if not all([amount, category, date, title, user_id]):
        return {
            'statusCode': 400,
            'body': json.dumps('Missing one or more transaction details')
        }

    # Add the transaction to the DynamoDB table
    response = add_transaction(table, amount, category, date, title, user_id)

    # Return the result
    return {
        'statusCode': 200,
        'body': json.dumps(response)
    }