import os
import json
import boto3
from flask import Flask, jsonify, request
from aws_xray_sdk.core import xray_recorder
from aws_xray_sdk.ext.flask.middleware import XRayMiddleware
from aws_xray_sdk.core import patch_all

# Initialize Flask application
app = Flask(__name__)

# Configure X-Ray
xray_recorder.configure(service='user-service')
XRayMiddleware(app, xray_recorder)

# Patch all supported libraries for X-Ray tracing
patch_all()

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ.get('USER_TABLE_NAME', 'UserProfiles'))

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'healthy'}), 200

@app.route('/users', methods=['GET'])
@xray_recorder.capture('list_users')
def list_users():
    try:
        # Create a subsegment for database operation
        subsegment = xray_recorder.begin_subsegment('dynamodb_scan_users')
        
        # Add metadata about the request
        xray_recorder.put_annotation('operation', 'list_users')
        xray_recorder.put_metadata('request_info', {
            'path': request.path,
            'method': request.method,
            'query_params': request.args.to_dict()
        })
        
        # Scan DynamoDB table
        response = table.scan(
            ProjectionExpression="userId, #name, email",
            ExpressionAttributeNames={'#name': 'name'}
        )
        
        users = response.get('Items', [])
        
        # Add pagination if LastEvaluatedKey is present
        if 'LastEvaluatedKey' in response:
            next_key = response['LastEvaluatedKey']
            xray_recorder.put_metadata('pagination', {
                'has_more': True,
                'last_key': next_key['userId']
            })
        
        xray_recorder.end_subsegment()
        
        return jsonify({
            'users': users,
            'count': len(users)
        }), 200
        
    except Exception as e:
        xray_recorder.put_annotation('error', True)
        xray_recorder.put_metadata('error_details', str(e))
        
        return jsonify({
            'error': 'Failed to retrieve users',
            'message': str(e)
        }), 500

@app.route('/users/<user_id>', methods=['GET'])
@xray_recorder.capture('get_user')
def get_user(user_id):
    try:
        # Create a subsegment for database operation
        subsegment = xray_recorder.begin_subsegment('dynamodb_get_user')
        
        # Add metadata about the request
        xray_recorder.put_annotation('operation', 'get_user')
        xray_recorder.put_annotation('user_id', user_id)
        xray_recorder.put_metadata('request_info', {
            'path': request.path,
            'method': request.method
        })
        
        # Get user from DynamoDB
        response = table.get_item(Key={'userId': user_id})
        
        xray_recorder.end_subsegment()
        
        if 'Item' in response:
            user = response['Item']
            xray_recorder.put_annotation('user_found', True)
            
            return jsonify(user), 200
        else:
            xray_recorder.put_annotation('user_found', False)
            
            return jsonify({
                'error': 'User not found',
                'userId': user_id
            }), 404
            
    except Exception as e:
        xray_recorder.put_annotation('error', True)
        xray_recorder.put_metadata('error_details', str(e))
        
        return jsonify({
            'error': 'Failed to retrieve user',
            'message': str(e)
        }), 500

@app.route('/users', methods=['POST'])
@xray_recorder.capture('create_user')
def create_user():
    try:
        # Create a subsegment for request processing
        subsegment = xray_recorder.begin_subsegment('process_create_user')
        
        # Add metadata about the request
        xray_recorder.put_annotation('operation', 'create_user')
        xray_recorder.put_metadata('request_info', {
            'path': request.path,
            'method': request.method,
            'content_length': request.content_length
        })
        
        # Parse request data
        user_data = request.json
        
        # Validate required fields
        required_fields = ['userId', 'name', 'email']
        for field in required_fields:
            if field not in user_data:
                xray_recorder.put_annotation('validation_error', True)
                xray_recorder.put_metadata('missing_field', field)
                
                xray_recorder.end_subsegment()
                
                return jsonify({
                    'error': 'Validation error',
                    'message': f'Missing required field: {field}'
                }), 400
        
        xray_recorder.end_subsegment()
        
        # Create a subsegment for database operation
        subsegment = xray_recorder.begin_subsegment('dynamodb_put_user')
        
        # Store user in DynamoDB
        table.put_item(Item=user_data)
        
        xray_recorder.end_subsegment()
        
        return jsonify({
            'message': 'User created successfully',
            'userId': user_data['userId']
        }), 201
        
    except Exception as e:
        xray_recorder.put_annotation('error', True)
        xray_recorder.put_metadata('error_details', str(e))
        
        return jsonify({
            'error': 'Failed to create user',
            'message': str(e)
        }), 500

if __name__ == '__main__':
    # Start the X-Ray recorder
    xray_recorder.begin_segment('user_service_app')
    
    # Get port from environment variable or use default
    port = int(os.environ.get('PORT', 5000))
    
    # Run the Flask application
    app.run(host='0.0.0.0', port=port)