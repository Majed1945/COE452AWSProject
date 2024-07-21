provider "aws" {
  region     = "us-east-1"
  access_key = ""
  secret_key = ""
}


#Add the Lambda functions in the collection
provider "archive" {}

data "archive_file" "LambdaFunctions" {
  type        = "zip"
  source_dir  = "./Lambda"
  output_path = "./Lambda.zip"
}


# VPC Configuration
resource "aws_vpc" "my_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

#Creating the public subnet 
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

#Creating the private subnet 
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false
}

#Create the internet gateway of the vpc
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id
}

#Create the public route table and add the internetgateway
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

#Add the public route table to the public subnet
resource "aws_route_table_association" "public_route_table_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

#Create the security group for the vpc
resource "aws_security_group" "sg_lambda" {
  name        = "lambda_vpc_sg"
  description = "Security group for Lambda functions in VPC"
  vpc_id      = aws_vpc.my_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Create permissions (Rules) for the lambda functions in the vpc
data "aws_iam_policy_document" "lambda_vpc_access" {
  statement {
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    actions = [
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:GetItem",
      "dynamodb:Scan",
      "dynamodb:Query",
      "dynamodb:DeleteItem",
      "dynamodb:*"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    actions = [
      "lambda:InvokeFunction",
      "lambda:*",
      "lambda:InvokeAsync"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    actions = [
      "ses:*"
    ]
    effect    = "Allow"
    resources = ["*"]
  }


}

#Create a DynamoDB table 
resource "aws_dynamodb_table" "Transactions" {
  name         = "Transactions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id" # Replace with your primary key attribute name

  attribute {
    name = "id" # Replace with your primary key attribute name
    type = "S"  # 'S' for string, 'N' for number, 'B' for binary
  }
}

#Create a DynamoDB table 
resource "aws_dynamodb_table" "Users" {
  name         = "Users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id" # Replace with your primary key attribute name

  attribute {
    name = "id" # Replace with your primary key attribute name
    type = "S"  # 'S' for string, 'N' for number, 'B' for binary
  }
}

#This is the polic that Allows Lambda functions to work with VPC and DynamoDB. This is done after the last two steps
resource "aws_iam_policy" "lambda_vpc_policy" {
  name        = "lambda_vpc_policy"
  description = "Allows Lambda functions to work with VPC and DynamoDB"
  policy      = data.aws_iam_policy_document.lambda_vpc_access.json
}


#This policy allows to create the lambda in terraform?????
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

#This is the policy that manages all roles configured in Terraform ?
resource "aws_iam_role" "finalRoler" {
  name               = "finalRoler"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}


#Add the policy in the VPC
resource "aws_iam_role_policy_attachment" "lambda_vpc_attach" {
  role       = aws_iam_role.finalRoler.name
  policy_arn = aws_iam_policy.lambda_vpc_policy.arn
}

#Create the lambda function (createTransaction) and invoke the archived file (Lambda)
resource "aws_lambda_function" "createTransaction" {
  function_name    = "createTransaction"
  filename         = data.archive_file.LambdaFunctions.output_path
  source_code_hash = data.archive_file.LambdaFunctions.output_base64sha256
  role             = aws_iam_role.finalRoler.arn
  handler          = "createTransaction.lambda_handler"
  runtime          = "python3.9"

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet.id]
    security_group_ids = [aws_security_group.sg_lambda.id]
  }
}

#Create the lambda function (paymentPlan) and invoke the archived file (Lambda)
resource "aws_lambda_function" "paymentPlan" {
  function_name    = "paymentPlan"
  filename         = data.archive_file.LambdaFunctions.output_path
  source_code_hash = data.archive_file.LambdaFunctions.output_base64sha256
  role             = aws_iam_role.finalRoler.arn
  handler          = "paymentPlan.lambda_handler"
  runtime          = "python3.9"

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet.id]
    security_group_ids = [aws_security_group.sg_lambda.id]
  }
}

#Create the lambda function (makeQattah) and invoke the archived file (Lambda)
resource "aws_lambda_function" "makeQattah" {
  function_name    = "makeQattah"
  filename         = data.archive_file.LambdaFunctions.output_path
  source_code_hash = data.archive_file.LambdaFunctions.output_base64sha256
  role             = aws_iam_role.finalRoler.arn
  handler          = "makeQattah.lambda_handler"
  runtime          = "python3.9"

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet.id]
    security_group_ids = [aws_security_group.sg_lambda.id]
  }
}

#Create the lambda function (qattahMarkPaid) and invoke the archived file (Lambda)
resource "aws_lambda_function" "markPaid" {
  function_name    = "markPaid"
  filename         = data.archive_file.LambdaFunctions.output_path
  source_code_hash = data.archive_file.LambdaFunctions.output_base64sha256
  role             = aws_iam_role.finalRoler.arn
  handler          = "markPaid.lambda_handler"
  runtime          = "python3.9"

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet.id]
    security_group_ids = [aws_security_group.sg_lambda.id]
  }
}

#Create the lambda function (createUser) and invoke the archived file (Lambda)
resource "aws_lambda_function" "createUser" {
  function_name    = "createUser"
  filename         = data.archive_file.LambdaFunctions.output_path
  source_code_hash = data.archive_file.LambdaFunctions.output_base64sha256
  role             = aws_iam_role.finalRoler.arn
  handler          = "createUser.lambda_handler"
  runtime          = "python3.9"

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet.id]
    security_group_ids = [aws_security_group.sg_lambda.id]
  }
}

#Create the lambda function (deleteUser) and invoke the archived file (Lambda)
resource "aws_lambda_function" "deleteUser" {
  function_name    = "deleteUser"
  filename         = data.archive_file.LambdaFunctions.output_path
  source_code_hash = data.archive_file.LambdaFunctions.output_base64sha256
  role             = aws_iam_role.finalRoler.arn
  handler          = "deleteUser.lambda_handler"
  runtime          = "python3.9"

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet.id]
    security_group_ids = [aws_security_group.sg_lambda.id]
  }
}

#Create the lambda function (updateUser) and invoke the archived file (Lambda)
resource "aws_lambda_function" "updateUser" {
  function_name    = "updateUser"
  filename         = data.archive_file.LambdaFunctions.output_path
  source_code_hash = data.archive_file.LambdaFunctions.output_base64sha256
  role             = aws_iam_role.finalRoler.arn
  handler          = "updateUser.lambda_handler"
  runtime          = "python3.9"

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet.id]
    security_group_ids = [aws_security_group.sg_lambda.id]
  }
}

#Create the lambda function (getUser) and invoke the archived file (Lambda)
resource "aws_lambda_function" "getUser" {
  function_name    = "getUser"
  filename         = data.archive_file.LambdaFunctions.output_path
  source_code_hash = data.archive_file.LambdaFunctions.output_base64sha256
  role             = aws_iam_role.finalRoler.arn
  handler          = "getUser.lambda_handler"
  runtime          = "python3.9"

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet.id]
    security_group_ids = [aws_security_group.sg_lambda.id]
  }
}

#Create the lambda function (categorization) and invoke the archived file (Lambda)
resource "aws_lambda_function" "transactionsCategorization" {
  function_name    = "transactionsCategorization"
  filename         = data.archive_file.LambdaFunctions.output_path
  source_code_hash = data.archive_file.LambdaFunctions.output_base64sha256
  role             = aws_iam_role.finalRoler.arn
  handler          = "transactionsCategorization.lambda_handler"
  runtime          = "python3.9"

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet.id]
    security_group_ids = [aws_security_group.sg_lambda.id]
  }
}

#Create the lambda function (notifyUser) and invoke the archived file (Lambda) 
resource "aws_lambda_function" "notifyUser" {
  function_name    = "notifyUser"
  filename         = data.archive_file.LambdaFunctions.output_path
  source_code_hash = data.archive_file.LambdaFunctions.output_base64sha256
  role             = aws_iam_role.finalRoler.arn
  handler          = "notifyUser.lambda_handler"
  runtime          = "python3.9"

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet.id]
    security_group_ids = [aws_security_group.sg_lambda.id]
  }
}

#Create the api gateway of the lambda that has been created and enable CORS to fully connected to the DynamoDB
resource "aws_apigatewayv2_api" "lambda" {
  name          = "CampusPay"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"] # Adjust as needed
    allow_methods = ["POST", "GET", "OPTIONS"]
    allow_headers = ["content-type", "x-amz-date", "authorization", "x-api-key", "x-amz-security-token"]
    max_age       = 300
  }
}



// to enable auto deployment (update the deployed function whenever the lambda function is updated)
resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "serverless_lambda_stage"
  auto_deploy = true
}

#Create the createTransaction Lambda function call to the apigateway
resource "aws_apigatewayv2_integration" "createTransaction" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.createTransaction.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

#Integrate the createTransaction Lambda function to the apigateway
resource "aws_lambda_permission" "api_gw_createTransaction" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.createTransaction.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

# ------------------------------------
#Create the createUser Lambda function call to the apigateway
resource "aws_apigatewayv2_integration" "createUser" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.createUser.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

#Integrate the createUser Lambda function to the apigateway
resource "aws_lambda_permission" "createUser" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.createUser.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

#----------------------------------------

# ------------------------------------
#Create the paymentPlan Lambda function call to the apigateway
resource "aws_apigatewayv2_integration" "paymentPlan" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.paymentPlan.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

#Integrate the paymentPlan Lambda function to the apigateway
resource "aws_lambda_permission" "paymentPlan" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.paymentPlan.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

#----------------------------------------

# ------------------------------------
#Create the makeQattah Lambda function call to the apigateway
resource "aws_apigatewayv2_integration" "makeQattah" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.makeQattah.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

#Integrate the makeQattah Lambda function to the apigateway
resource "aws_lambda_permission" "makeQattah" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.makeQattah.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

#----------------------------------------

# ------------------------------------
#Create the qattahMarkPaid Lambda function call to the apigateway
resource "aws_apigatewayv2_integration" "markPaid" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.markPaid.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

#Integrate the qattahMarkPaid Lambda function to the apigateway
resource "aws_lambda_permission" "markPaid" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.markPaid.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

#----------------------------------------

# ------------------------------------
#Create the deleteUser Lambda function call to the apigateway
resource "aws_apigatewayv2_integration" "deleteUser" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.deleteUser.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

#Integrate the deleteUser Lambda function to the apigateway
resource "aws_lambda_permission" "deleteUser" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.deleteUser.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

#----------------------------------------

# ------------------------------------
#Create the getUser Lambda function call to the apigateway
resource "aws_apigatewayv2_integration" "getUser" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.getUser.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

#Integrate the getUser Lambda function to the apigateway
resource "aws_lambda_permission" "getUser" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.getUser.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

#----------------------------------------

# ------------------------------------
#Create the updateUser Lambda function call to the apigateway
resource "aws_apigatewayv2_integration" "updateUser" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.updateUser.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

#Integrate the updateUser Lambda function to the apigateway
resource "aws_lambda_permission" "updateUser" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.updateUser.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

#----------------------------------------

# ------------------------------------
#Create the categorization Lambda function call to the apigateway
resource "aws_apigatewayv2_integration" "transactionsCategorization" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.transactionsCategorization.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

#Integrate the categorization Lambda function to the apigateway
resource "aws_lambda_permission" "transactionsCategorization" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.transactionsCategorization.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

#----------------------------------------

#Create the notifyUser Lambda function call to the apigateway
resource "aws_apigatewayv2_integration" "notifyUser" {
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.notifyUser.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

#Integrate the notifyUser Lambda function to the apigateway
resource "aws_lambda_permission" "notifyUser" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notifyUser.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

#----------------------------------------

#Create the NAT gateway in the VPC
resource "aws_eip" "nat_gateway_eip" {
  domain = "vpc"
}

#Add the nat gateway in the public subnet
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.public_subnet.id
}

# Connect a Route Table for the private subnet with a route to the NAT Gateway
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
}

# Associate the private route table with the private subnet
resource "aws_route_table_association" "private_route_table_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

#Add the route to the API GateWay
resource "aws_apigatewayv2_route" "POST_createTransaction" {
  api_id    = aws_apigatewayv2_api.lambda.id
  route_key = "POST transactions/createTransaction"
  target    = "integrations/${aws_apigatewayv2_integration.createTransaction.id}"
}

#----------------------------------------------

resource "aws_apigatewayv2_route" "POST_createUser" {
  api_id    = aws_apigatewayv2_api.lambda.id
  route_key = "POST users/createUser"
  target    = "integrations/${aws_apigatewayv2_integration.createUser.id}"
}

#----------------------------------------------

#----------------------------------------------

resource "aws_apigatewayv2_route" "GET_paymentPlan" {
  api_id    = aws_apigatewayv2_api.lambda.id
  route_key = "GET transactions/paymentPlan"
  target    = "integrations/${aws_apigatewayv2_integration.paymentPlan.id}"
}

#----------------------------------------------

#----------------------------------------------

resource "aws_apigatewayv2_route" "POST_makeQattah" {
  api_id    = aws_apigatewayv2_api.lambda.id
  route_key = "POST transactions/makeQattah"
  target    = "integrations/${aws_apigatewayv2_integration.makeQattah.id}"
}

#----------------------------------------------

#----------------------------------------------

resource "aws_apigatewayv2_route" "POST_markPaid" {
  api_id    = aws_apigatewayv2_api.lambda.id
  route_key = "POST transactions/markPaid"
  target    = "integrations/${aws_apigatewayv2_integration.markPaid.id}"
}

#----------------------------------------------

#----------------------------------------------

resource "aws_apigatewayv2_route" "DELETE_deleteUser" {
  api_id    = aws_apigatewayv2_api.lambda.id
  route_key = "DELETE users/deleteUser"
  target    = "integrations/${aws_apigatewayv2_integration.deleteUser.id}"
}

#----------------------------------------------

#----------------------------------------------

resource "aws_apigatewayv2_route" "GET_getUser" {
  api_id    = aws_apigatewayv2_api.lambda.id
  route_key = "GET users/getUser"
  target    = "integrations/${aws_apigatewayv2_integration.getUser.id}"
}

#----------------------------------------------

#----------------------------------------------

resource "aws_apigatewayv2_route" "PUT_updateUser" {
  api_id    = aws_apigatewayv2_api.lambda.id
  route_key = "PUT users/updateUser"
  target    = "integrations/${aws_apigatewayv2_integration.updateUser.id}"
}

#----------------------------------------------

#----------------------------------------------

resource "aws_apigatewayv2_route" "GET_transactionsCategorization" {
  api_id    = aws_apigatewayv2_api.lambda.id
  route_key = "GET transactions/transactionsCategorization"
  target    = "integrations/${aws_apigatewayv2_integration.transactionsCategorization.id}"
}

#----------------------------------------------

#Add the route to the API GateWay
resource "aws_apigatewayv2_route" "POST_notifyUser" {
  api_id    = aws_apigatewayv2_api.lambda.id
  route_key = "POST transactions/notifyUser"
  target    = "integrations/${aws_apigatewayv2_integration.notifyUser.id}"
}



