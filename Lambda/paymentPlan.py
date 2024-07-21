import json
import boto3
from decimal import Decimal
from boto3.dynamodb.conditions import Attr

# Create a DynamoDB resource
dynamodb = boto3.resource('dynamodb')
table_name = 'Transactions'
transactions_table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    body = json.loads(event['body'])
    user_id = body['userID']
    plan_type = body['planType']

    # Validate inputs
    if not user_id or not plan_type:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Missing userID or planType'})
        }

    # Retrieve and convert transactions for the user
    transactions = convert_decimals(get_transactions_from_dynamodb(user_id))

    # Analyze spending patterns and calculate percentages
    spending_summary, total_spent = analyze_spending(transactions)

    # Generate a financial plan based on the plan type
    financial_plan = generate_plan(plan_type, spending_summary, total_spent)

    # Enhanced response with better readability
    response_message = {
        "Welcome Message": financial_plan['welcome_message'],
        "Summary": financial_plan['summary'],
        "Suggestions": financial_plan['suggestions'],
        "Total Spending Analyzed": f"${total_spent:.2f}"
    }

    # Return the enhanced financial plan
    return {
        'statusCode': 200,
        'body': response_message
    }

def get_transactions_from_dynamodb(user_id):
    # Scan the DynamoDB table for transactions related to the user
    response = transactions_table.scan(
        FilterExpression=Attr('userID').eq(user_id)
    )
    return response.get('Items', [])

def analyze_spending(transactions):
    spending_summary = {}
    total_spent = 0

    # Summarize spending by category and calculate the total spent
    for transaction in transactions:
        category = transaction['category']
        amount = transaction['amount']
        spending_summary[category] = spending_summary.get(category, 0) + amount
        total_spent += amount

    return spending_summary, total_spent

def generate_plan(plan_type, spending_summary, total_spent):
    plan = {
        'planType': plan_type,
        'welcome_message': "🌟 Welcome to Your Personal Finance Assistant! Let's optimize your finances.",
        'suggestions': [],
        'summary': ""
    }

    if plan_type == 'saving':
        plan['summary'] = "Here's your personalized saving plan aimed at boosting your savings:"
        # Calculating suggestions based on spending percentages
        for category, amount in spending_summary.items():
            percentage = (amount / total_spent) * 100  # Spending percentage in each category
            if percentage > 5:  # Focus on categories with significant spending
                suggested_reduction = amount * 0.1  # Suggesting a 10% reduction
                # Adding detailed suggestions with calculations
                plan['suggestions'].append(
                    f"Reduce by 10% in {category} (currently ${amount:.2f}, {percentage:.2f}% of total). Potential saving: ${suggested_reduction:.2f} per month.")
        plan['welcome_message'] += "\n\n💡 Saving Plan: Your guide to smart savings and financial growth."

    elif plan_type == 'debt_reduction':
        plan['summary'] = "Debt reduction strategy to help you minimize debts more efficiently:"
        # Suggesting reductions in non-essential categories for debt repayment
        for category in ['Entertainment', 'Shopping', 'Luxury Items']:
            if category in spending_summary and spending_summary[category] > 0:
                percentage = (spending_summary[category] / total_spent) * 100
                plan['suggestions'].append(
                    f"Consider reducing {category} expenses (${spending_summary[category]:.2f}, {percentage:.2f}% of total) for faster debt repayment.")
        plan['suggestions'].append("Prioritize repaying debts first.")
        plan['welcome_message'] += "\n\n🚀 Debt Reduction Plan: A strategic approach to minimize and eliminate debt."

    elif plan_type == 'budgeting':
        plan['summary'] = "Customized budgeting plan to maintain a balanced financial life:"
        essential_categories = ['Housing', 'Groceries', 'Healthcare']
        non_essential_categories = ['Entertainment', 'Dining Out', 'Shopping']
        # Analyzing essential and non-essential spending
        for category in essential_categories + non_essential_categories:
            if category in spending_summary:
                percentage = (spending_summary[category] / total_spent) * 100
                if category in essential_categories:
                    plan['suggestions'].append(
                        f"Maintain essential spending in {category} (${spending_summary[category]:.2f}, {percentage:.2f}% of total).")
                else:
                    suggested_reduction = spending_summary[category] * 0.1  # 10% reduction suggestion
                    plan['suggestions'].append(
                        f"Consider reducing non-essential {category} spending by 10% (${suggested_reduction:.2f} potential saving).")
        plan['welcome_message'] += "\n\n📊 Budgeting Plan: Crafting a balanced and sustainable financial lifestyle."

    elif plan_type == 'investment':
        plan['summary'] = "Investment guidance to help grow your wealth:"
        # Investment suggestions based on discretionary spending
        for category, amount in spending_summary.items():
            if category not in ['Housing', 'Groceries', 'Healthcare', 'Savings', 'Debt Repayment']:
                suggested_investment = amount * 0.05  # Suggesting a 5% investment
                plan['suggestions'].append(
                    f"Consider investing 5% of {category} spending (${suggested_investment:.2f} potential investment) for long-term growth.")
        plan['welcome_message'] += "\n\n📈 Investment Plan: Unlocking the potential of your finances for future prosperity."

    return plan

def convert_decimals(obj):
    # Convert DynamoDB Decimal types to Python native int or float
    if isinstance(obj, list):
        return [convert_decimals(x) for x in obj]
    elif isinstance(obj, dict):
        return {k: convert_decimals(v) for k, v in obj.items()}
    elif isinstance(obj, Decimal):
        if obj % 1 == 0:
            return int(obj)
        else:
            return float(obj)
    else:
        return obj

# Example usage
# result = lambda_handler({'userID': '123', 'planType': 'saving'}, {})
# print(result)
