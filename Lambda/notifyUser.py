import json
import boto3
from botocore.exceptions import ClientError
from boto3.dynamodb.conditions import Attr
def get_user_email(dynamodb, table_name, user_id):
    table = dynamodb.Table(table_name)
    try:
        response = table.scan(
            FilterExpression=Attr('ID').eq(user_id)  # Ensure 'ID' is the correct attribute name
        )
        items = response.get('Items', [])
        if not items:
            print(f"No records found for UserID: {user_id}")
            return None
        email = items[0]['email']  # Ensure 'Email' is the correct attribute name
        if not email:
            print(f"Email attribute not found in the record for UserID: {user_id}")
            return None
        return email
    except Exception as e:
        print(f"Error occurred while fetching user email: {e}")
        return None

def send_email(ses, sender_email, recipient_email, subject, body):
    print(sender_email)
    print("asdasdsadsadsada")
    print(recipient_email)
    try:
        response = ses.send_email(
            Source=sender_email,
            Destination={'ToAddresses': [recipient_email]},
            Message={
                'Subject': {'Data': subject},
                'Body': {'Text': {'Data': body}}
            }
        )
        return response
    except ClientError as e:
        print(e.response['Error']['Message'])
        return None
def lambda_handler(event, context):
    # Initialize AWS services clients
    dynamodb = boto3.resource('dynamodb')
    ses = boto3.client('ses')
    body = json.loads(event['body'])
    # Extract data from the event
    user_id = body["userID"]
    transaction_id = body["transactionID"]
    # Configuration
    user_table_name = 'Users'  # Replace with your user table name
    sender_email = 's201915790@kfupm.edu.sa'  # Replace with your verified sender email address
    subject = "Payment"
    body = f"Your transaction with ID {transaction_id} has been processed."
    # Get user email
    user_email = get_user_email(dynamodb, user_table_name, user_id)
    if not user_email:
        return {'statusCode': 400, 'body': json.dumps(user_email)}
    # Send email
    email_response = send_email(ses, sender_email, user_email, subject, body)
    if email_response is None:
        return {'statusCode': 500, 'body': json.dumps("Failed to send email.")}
    # Success response
    return {'statusCode': 200, 'body': json.dumps("Email sent successfully.")}