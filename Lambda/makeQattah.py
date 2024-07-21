import boto3
import uuid
from decimal import Decimal
import json
from datetime import datetime

def create_split_transactions(transaction_table, amount, category, date, title, user_ids, creator_id):
    total_people = len(user_ids) + 1  # Including the creator
    split_amount = Decimal(str(round(amount / total_people, 2)))
    responses = []

    # Transaction for the creator
    creator_transaction_id = str(uuid.uuid4())
    creator_transaction = {
        'id': creator_transaction_id,
        'amount': split_amount,
        'category': category,
        'date': date,
        'title': title,
        'userID': creator_id,
        'is_paid': True,
        'came_from': creator_id
    }
    transaction_table.put_item(Item=creator_transaction)
    responses.append(creator_transaction)

    # Transactions for each participant
    for user_id in user_ids:
        participant_transaction_id = str(uuid.uuid4())
        participant_transaction = {
            'id': participant_transaction_id,
            'amount': split_amount,
            'category': category,
            'date': date,
            'title': title,
            'userID': user_id,
            'is_paid': False,
            'came_from': creator_id
        }
        response = transaction_table.put_item(Item=participant_transaction)
        responses.append(response)

    return responses

def lambda_handler(event, context):
    dynamodb = boto3.resource('dynamodb')
    transaction_table = dynamodb.Table('Transactions')
    body = json.loads(event['body'])
    # Extract transaction details from the event
    amount = Decimal(str(body['amount']))
    category = body['category']
    date = body['date']
    title = body['title']
    user_ids = body['users']
    creator_id = body['creatorID']

    # Validate category and user_ids
    if not all([amount, category, date, title, user_ids, creator_id]):
        return {
            'statusCode': 400,
            'body': json.dumps('Missing one or more transaction details')
        }

    if category.lower() != "qattah":
        return {
            'statusCode': 400,
            'body': json.dumps('Invalid category. This endpoint is for Qattah transactions only.')
        }

    # Split the transaction among users including the creator
    responses = create_split_transactions(transaction_table, amount, category, date, title, user_ids, creator_id)

    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Qattah transactions created successfully', 'responses': responses})
    }
