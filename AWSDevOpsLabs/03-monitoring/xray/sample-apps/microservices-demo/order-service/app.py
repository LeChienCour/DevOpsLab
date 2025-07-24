import os
import json
import uuid
import boto3
import requests
from datetime import datetime
from flask import Flask, jsonify, request
from aws_xray_sdk.core import xray_recorder
from aws_xray_sdk.ext.flask.middleware import XRayMiddleware
from aws_xray_sdk.core import patch_all

# Initialize Flask application
app = Flask(__name__)

# Configure X-Ray
xray_recorder.configure(service='order-service')
XRayMiddleware(app, xray_recorder)

# Patch all supported libraries for X-Ray tracing
patch_all()

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
orders_table = dynamodb.Table(os.environ.get('ORDERS_TABLE_NAME', 'Orders'))

# User service URL
USER_SERVICE_URL = os.environ.get('USER_SERVICE_URL', 'http://user-service:5000')

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'healthy'}), 200

@app.route('/orders', methods=['GET'])
@xray_recorder.capture('list_orders')
def list_orders():
    try:
        # Create a subsegment for database operation
        subsegment = xray_recorder.begin_subsegment('dynamodb_scan_orders')
        
        # Add metadata about the request
        xray_recorder.put_annotation('operation', 'list_orders')
        xray_recorder.put_metadata('request_info', {
            'path': request.path,
            'method': request.method,
            'query_params': request.args.to_dict()
        })
        
        # Get user_id from query parameters
        user_id = request.args.get('userId')
        
        # Scan DynamoDB table
        if user_id:
            # Filter by user_id if provided
            xray_recorder.put_annotation('filter_by_user', True)
            xray_recorder.put_annotation('user_id', user_id)
            
            # Note: In a production environment, you would use a GSI for this query
            # This is a simplified example that scans and filters
            response = orders_table.scan(
                FilterExpression="userId = :userId",
                ExpressionAttributeValues={':userId': user_id}
            )
        else:
            response = orders_table.scan()
        
        orders = response.get('Items', [])
        
        # Add pagination if LastEvaluatedKey is present
        if 'LastEvaluatedKey' in response:
            next_key = response['LastEvaluatedKey']
            xray_recorder.put_metadata('pagination', {
                'has_more': True,
                'last_key': next_key['orderId']
            })
        
        xray_recorder.end_subsegment()
        
        return jsonify({
            'orders': orders,
            'count': len(orders)
        }), 200
        
    except Exception as e:
        xray_recorder.put_annotation('error', True)
        xray_recorder.put_metadata('error_details', str(e))
        
        return jsonify({
            'error': 'Failed to retrieve orders',
            'message': str(e)
        }), 500

@app.route('/orders/<order_id>', methods=['GET'])
@xray_recorder.capture('get_order')
def get_order(order_id):
    try:
        # Create a subsegment for database operation
        subsegment = xray_recorder.begin_subsegment('dynamodb_get_order')
        
        # Add metadata about the request
        xray_recorder.put_annotation('operation', 'get_order')
        xray_recorder.put_annotation('order_id', order_id)
        xray_recorder.put_metadata('request_info', {
            'path': request.path,
            'method': request.method
        })
        
        # Get order from DynamoDB
        response = orders_table.get_item(Key={'orderId': order_id})
        
        xray_recorder.end_subsegment()
        
        if 'Item' in response:
            order = response['Item']
            xray_recorder.put_annotation('order_found', True)
            
            # Get user details if requested
            include_user = request.args.get('includeUser', 'false').lower() == 'true'
            
            if include_user and 'userId' in order:
                # Create a subsegment for user service call
                subsegment = xray_recorder.begin_subsegment('get_user_details')
                
                try:
                    user_id = order['userId']
                    user_url = f"{USER_SERVICE_URL}/users/{user_id}"
                    
                    xray_recorder.put_annotation('user_id', user_id)
                    xray_recorder.put_metadata('user_service_url', user_url)
                    
                    # Call user service
                    user_response = requests.get(user_url)
                    
                    if user_response.status_code == 200:
                        user_data = user_response.json()
                        order['userDetails'] = user_data
                        xray_recorder.put_annotation('user_found', True)
                    else:
                        xray_recorder.put_annotation('user_found', False)
                        xray_recorder.put_metadata('user_service_error', {
                            'status_code': user_response.status_code,
                            'response': user_response.text
                        })
                except Exception as e:
                    xray_recorder.put_annotation('user_service_error', True)
                    xray_recorder.put_metadata('error_details', str(e))
                
                xray_recorder.end_subsegment()
            
            return jsonify(order), 200
        else:
            xray_recorder.put_annotation('order_found', False)
            
            return jsonify({
                'error': 'Order not found',
                'orderId': order_id
            }), 404
            
    except Exception as e:
        xray_recorder.put_annotation('error', True)
        xray_recorder.put_metadata('error_details', str(e))
        
        return jsonify({
            'error': 'Failed to retrieve order',
            'message': str(e)
        }), 500

@app.route('/orders', methods=['POST'])
@xray_recorder.capture('create_order')
def create_order():
    try:
        # Create a subsegment for request processing
        subsegment = xray_recorder.begin_subsegment('process_create_order')
        
        # Add metadata about the request
        xray_recorder.put_annotation('operation', 'create_order')
        xray_recorder.put_metadata('request_info', {
            'path': request.path,
            'method': request.method,
            'content_length': request.content_length
        })
        
        # Parse request data
        order_data = request.json
        
        # Validate required fields
        required_fields = ['userId', 'items']
        for field in required_fields:
            if field not in order_data:
                xray_recorder.put_annotation('validation_error', True)
                xray_recorder.put_metadata('missing_field', field)
                
                xray_recorder.end_subsegment()
                
                return jsonify({
                    'error': 'Validation error',
                    'message': f'Missing required field: {field}'
                }), 400
        
        # Validate user exists
        user_id = order_data['userId']
        
        # Create a subsegment for user validation
        subsegment_user = xray_recorder.begin_subsegment('validate_user')
        
        try:
            user_url = f"{USER_SERVICE_URL}/users/{user_id}"
            
            xray_recorder.put_annotation('user_id', user_id)
            xray_recorder.put_metadata('user_service_url', user_url)
            
            # Call user service
            user_response = requests.get(user_url)
            
            if user_response.status_code != 200:
                xray_recorder.put_annotation('user_found', False)
                xray_recorder.put_metadata('user_service_error', {
                    'status_code': user_response.status_code,
                    'response': user_response.text
                })
                
                xray_recorder.end_subsegment()
                
                return jsonify({
                    'error': 'User not found',
                    'userId': user_id
                }), 400
                
            xray_recorder.put_annotation('user_found', True)
            
        except Exception as e:
            xray_recorder.put_annotation('user_service_error', True)
            xray_recorder.put_metadata('error_details', str(e))
            
            xray_recorder.end_subsegment()
            
            return jsonify({
                'error': 'Failed to validate user',
                'message': str(e)
            }), 500
            
        xray_recorder.end_subsegment()
        
        # Generate order ID and add metadata
        order_id = str(uuid.uuid4())
        order_data['orderId'] = order_id
        order_data['status'] = 'pending'
        order_data['createdAt'] = datetime.utcnow().isoformat()
        
        # Calculate total if not provided
        if 'total' not in order_data:
            total = 0
            for item in order_data['items']:
                price = float(item.get('price', 0))
                quantity = int(item.get('quantity', 1))
                total += price * quantity
            
            order_data['total'] = total
        
        xray_recorder.end_subsegment()
        
        # Create a subsegment for database operation
        subsegment = xray_recorder.begin_subsegment('dynamodb_put_order')
        
        # Store order in DynamoDB
        orders_table.put_item(Item=order_data)
        
        xray_recorder.end_subsegment()
        
        return jsonify({
            'message': 'Order created successfully',
            'orderId': order_id
        }), 201
        
    except Exception as e:
        xray_recorder.put_annotation('error', True)
        xray_recorder.put_metadata('error_details', str(e))
        
        return jsonify({
            'error': 'Failed to create order',
            'message': str(e)
        }), 500

@app.route('/orders/<order_id>', methods=['PUT'])
@xray_recorder.capture('update_order')
def update_order(order_id):
    try:
        # Create a subsegment for request processing
        subsegment = xray_recorder.begin_subsegment('process_update_order')
        
        # Add metadata about the request
        xray_recorder.put_annotation('operation', 'update_order')
        xray_recorder.put_annotation('order_id', order_id)
        xray_recorder.put_metadata('request_info', {
            'path': request.path,
            'method': request.method,
            'content_length': request.content_length
        })
        
        # Parse request data
        order_data = request.json
        
        # Ensure orderId matches path parameter
        if 'orderId' in order_data and order_data['orderId'] != order_id:
            xray_recorder.put_annotation('validation_error', True)
            xray_recorder.put_metadata('error_details', 'orderId mismatch')
            
            xray_recorder.end_subsegment()
            
            return jsonify({
                'error': 'Validation error',
                'message': 'orderId in body must match orderId in path'
            }), 400
        
        # Force orderId to match path parameter
        order_data['orderId'] = order_id
        
        xray_recorder.end_subsegment()
        
        # Create a subsegment for database operation
        subsegment = xray_recorder.begin_subsegment('dynamodb_update_order')
        
        # Check if order exists
        response = orders_table.get_item(Key={'orderId': order_id})
        
        if 'Item' not in response:
            xray_recorder.put_annotation('order_found', False)
            
            xray_recorder.end_subsegment()
            
            return jsonify({
                'error': 'Order not found',
                'orderId': order_id
            }), 404
        
        # Update order in DynamoDB
        orders_table.put_item(Item=order_data)
        
        xray_recorder.put_annotation('order_found', True)
        xray_recorder.end_subsegment()
        
        return jsonify({
            'message': 'Order updated successfully',
            'orderId': order_id
        }), 200
        
    except Exception as e:
        xray_recorder.put_annotation('error', True)
        xray_recorder.put_metadata('error_details', str(e))
        
        return jsonify({
            'error': 'Failed to update order',
            'message': str(e)
        }), 500

if __name__ == '__main__':
    # Start the X-Ray recorder
    xray_recorder.begin_segment('order_service_app')
    
    # Get port from environment variable or use default
    port = int(os.environ.get('PORT', 5001))
    
    # Run the Flask application
    app.run(host='0.0.0.0', port=port)