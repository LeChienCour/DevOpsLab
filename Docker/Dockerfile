# Use an official Python runtime as a parent image
FROM python:3.11-alpine3.18

# Set the working directory to /app
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY /Projects/. /app/

# Install any needed packages specified in requirements.txt
RUN pip install --trusted-host pypi.python.org -r requirements.txt

# Define environment variable
ENV NAME World

# Run app.py when the container launches
CMD ["python", "/app/Projects/test_calculator.py"]
