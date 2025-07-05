-- Task Manager Database Schema
-- Simple schema for Lab 3: Microservices + Database

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tasks table
CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    priority VARCHAR(10) DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high')),
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed')),
    due_date DATE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_tasks_user_id ON tasks(user_id);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_priority ON tasks(priority);
CREATE INDEX idx_tasks_created_at ON tasks(created_at);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tasks_updated_at 
    BEFORE UPDATE ON tasks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert sample data
INSERT INTO users (username, email, password_hash) 
VALUES (
    'demo', 
    'demo@taskmanager.com', 
    '$2b$10$8K1p/a0dLDZQEKHzSJz.R.6.2W9jNxsUzQ3sUDWrQvK4FhsIqE4S6' -- password: demo123
);

-- Insert sample tasks
INSERT INTO tasks (title, description, user_id, priority, status) 
VALUES 
    (
        'Learn Docker Basics',
        'Complete Docker fundamentals course and practice with containers',
        (SELECT id FROM users WHERE username = 'demo'),
        'high',
        'completed'
    ),
    (
        'Build First Microservice',
        'Create a simple API with Node.js and connect to PostgreSQL',
        (SELECT id FROM users WHERE username = 'demo'),
        'medium',
        'in_progress'
    ),
    (
        'Docker Compose Setup',
        'Configure multi-container application with docker-compose',
        (SELECT id FROM users WHERE username = 'demo'),
        'high',
        'pending'
    ),
    (
        'Frontend Integration',
        'Connect React frontend to the API backend',
        (SELECT id FROM users WHERE username = 'demo'),
        'medium',
        'pending'
    ),
    (
        'Database Optimization',
        'Add indexes and optimize database queries',
        (SELECT id FROM users WHERE username = 'demo'),
        'low',
        'pending'
    );

-- Create a simple stats view
CREATE VIEW task_stats AS
SELECT 
    u.username,
    COUNT(t.id) as total_tasks,
    COUNT(CASE WHEN t.status = 'completed' THEN 1 END) as completed_tasks,
    COUNT(CASE WHEN t.status = 'in_progress' THEN 1 END) as in_progress_tasks,
    COUNT(CASE WHEN t.status = 'pending' THEN 1 END) as pending_tasks,
    COUNT(CASE WHEN t.priority = 'high' THEN 1 END) as high_priority_tasks
FROM users u
LEFT JOIN tasks t ON u.id = t.user_id
GROUP BY u.id, u.username; 