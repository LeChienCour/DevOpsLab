import os
import time
import random
import json
import requests
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('load-generator')

# Service URLs
USER_SERVICE_URL = os.environ.get('USER_SERVICE_URL', 'http://user-service:5000')
ORDER_SERVICE_URL = os.environ.get('ORDER_SERVICE_URL', 'http://order-service:5001')

# Sample user IDs
USER_IDS = ['user123', 'user456', 'nonexistent']

# Sample order IDs
ORDER_IDS = ['order123', 'order456', 'nonexistent']

# Sample products for order creation
PRODUCTS = [
    {'id': 'prod1', 'name': 'Product 1', 'price': 29.99},
    {'id': 'prod2', 'name': 'Product 2', 'price': 49.99},
    {'id': 'prod3', 'name': 'Product 3', 'price': 19.99},
    {'id': 'prod4', 'name': 'Product 4', 'price': 99.99},
    {'id': 'prod5', 'name': 'Product 5', 'price': 9.99}
]

def generate_random_order(user_id):
    """Generate a random order for testing"""
    # Select 1-3 random products
    num_products = random.randint(1, 3)
    selected_products = random.sample(PRODUCTS, num_products)
    
    # Create order items
    items = []
    total = 0
    
    for product in selected_products:
        quantity = random.randint(1, 3)
        price = product['price']
        item_total = price * quantity
        total += item_total
        
        items.append({
            'id': product['id'],
            'name': product['name'],
            'price': price,
            'quantity': quantity
        })
    
    # Create order
    return {
        'userId': user_id,
        'items': items,
        'total': round(total, 2),
        'status': 'pending'
    }

def simulate_user_traffic():
    """Simulate user traffic to generate X-Ray traces"""
    try:
        # Get all users
        logger.info("Requesting all users")
        response = requests.get(f"{USER_SERVICE_URL}/users")
        logger.info(f"Users response: {response.status_code}")
        
        # Get specific users (including error case)
        for user_id in USER_IDS:
            logger.info(f"Requesting user: {user_id}")
            response = requests.get(f"{USER_SERVICE_URL}/users/{user_id}")
            logger.info(f"User {user_id} response: {response.status_code}")
            time.sleep(random.uniform(0.1, 0.5))
        
        # Get all orders
        logger.info("Requesting all orders")
        response = requests.get(f"{ORDER_SERVICE_URL}/orders")
        logger.info(f"Orders response: {response.status_code}")
        
        # Get specific orders (including error case)
        for order_id in ORDER_IDS:
            logger.info(f"Requesting order: {order_id}")
            response = requests.get(f"{ORDER_SERVICE_URL}/orders/{order_id}")
            logger.info(f"Order {order_id} response: {response.status_code}")
            
            # Sometimes request with user details
            if random.random() > 0.5 and response.status_code == 200:
                logger.info(f"Requesting order with user details: {order_id}")
                response = requests.get(f"{ORDER_SERVICE_URL}/orders/{order_id}?includeUser=true")
                logger.info(f"Order with user details response: {response.status_code}")
            
            time.sleep(random.uniform(0.1, 0.5))
        
        # Create new order (sometimes)
        if random.random() > 0.7:
            # Use a valid user ID
            user_id = random.choice(USER_IDS[:2])  # Exclude nonexistent
            order_data = generate_random_order(user_id)
            
            logger.info(f"Creating new order for user: {user_id}")
            response = requests.post(
                f"{ORDER_SERVICE_URL}/orders",
                json=order_data,
                headers={'Content-Type': 'application/json'}
            )
            logger.info(f"Create order response: {response.status_code}")
            
            # If successful, get the new order
            if response.status_code == 201:
                order_id = response.json().get('orderId')
                if order_id:
                    logger.info(f"Requesting newly created order: {order_id}")
                    response = requests.get(f"{ORDER_SERVICE_URL}/orders/{order_id}")
                    logger.info(f"New order response: {response.status_code}")
    
    except Exception as e:
        logger.error(f"Error in traffic simulation: {str(e)}")

def main():
    """Main function to continuously generate traffic"""
    logger.info("Starting load generator")
    logger.info(f"User service URL: {USER_SERVICE_URL}")
    logger.info(f"Order service URL: {ORDER_SERVICE_URL}")
    
    # Wait for services to be ready
    time.sleep(5)
    
    while True:
        try:
            simulate_user_traffic()
            
            # Random pause between traffic bursts
            sleep_time = random.uniform(1.0, 3.0)
            logger.info(f"Sleeping for {sleep_time:.2f} seconds")
            time.sleep(sleep_time)
            
        except Exception as e:
            logger.error(f"Error in main loop: {str(e)}")
            time.sleep(5)  # Longer sleep on error

if __name__ == "__main__":
    main()