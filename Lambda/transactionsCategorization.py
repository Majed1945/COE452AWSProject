import json
import boto3
from boto3.dynamodb.conditions import Attr
from decimal import Decimal
from json import JSONEncoder

# Custom JSON encoder to handle Decimal types
class DecimalEncoder(JSONEncoder):
    def default(self, o):
        if isinstance(o, Decimal):
            if o % 1 == 0:
                return int(o)
            else:
                return float(o)
        return super(DecimalEncoder, self).default(o)

def scan_transactions(table, user_id):
    # Scan the table for the given user
    response = table.scan(
        FilterExpression=Attr('userID').eq(user_id))
    
    # Aggregate amounts by category
    category_amounts = {}
    for item in response['Items']:
        category = item['category']
        amount = item['amount']
        if category in category_amounts:
            category_amounts[category] += amount
        else:
            category_amounts[category] = amount
    
    return category_amounts

def calculate_percentages(category_amounts):
    total_amount = sum(category_amounts.values())
    percentages = {category: "{:.2f}%".format((amount / total_amount) * 100) for category, amount in category_amounts.items()}
    return percentages

# Rest of your code remains the same


def lambda_handler(event, context):
    # Initialize a boto3 DynamoDB resource
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('Transactions')  # Replace with your table name
    body = json.loads(event['body'])
    # Extract UserID from the event
    user_id = body["userID"]

    # Ensure UserID is provided
    if not user_id:
        return {
            'statusCode': 400,
            'body': json.dumps('Missing UserID')
        }

    # Scan the DynamoDB table
    category_amounts = scan_transactions(table, user_id)

    # Calculate the percentages
    percentages = calculate_percentages(category_amounts)

    # Return the result using the custom JSON encoder
    return {
        'statusCode': 200,
        'body': percentages
    }
