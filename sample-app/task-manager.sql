-- Task Manager Sample App for plplg-api
-- This sample app demonstrates how to use plplg-api to create a simple task management system
-- It showcases the persistence layer, JSON manipulation, error handling, and dynamic function calling

-- Create the task_manager schema
CREATE SCHEMA IF NOT EXISTS task_manager;

-- Create the task category table
CREATE TABLE task_manager.category
(
    id          BIGSERIAL PRIMARY KEY,
    name        TEXT NOT NULL,
    description TEXT,
    created_at  TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp
);

-- Create the task table
CREATE TABLE task_manager.task
(
    id          BIGSERIAL PRIMARY KEY,
    title       TEXT    NOT NULL,
    description TEXT,
    status      TEXT    NOT NULL         DEFAULT 'pending',
    priority    INTEGER NOT NULL         DEFAULT 1,
    category_id BIGINT REFERENCES task_manager.category (id),
    metadata    jsonb                    DEFAULT '{}'::jsonb,
    due_date    TIMESTAMP WITH TIME ZONE,
    created_at  TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp,
    updated_at  TIMESTAMP WITH TIME ZONE DEFAULT current_timestamp
);

-- Task Manager Type Definitions
-- This file contains the type definitions for the task manager API

-- Make sure the schema exists
CREATE SCHEMA IF NOT EXISTS task_manager;

-- Category types
DROP TYPE IF EXISTS task_manager.category_id_type CASCADE;
CREATE TYPE task_manager.category_id_type AS
(
    id BIGINT
);

DROP TYPE IF EXISTS task_manager.category_create_type CASCADE;
CREATE TYPE task_manager.category_create_type AS
(
    name        TEXT,
    description TEXT
);

DROP TYPE IF EXISTS task_manager.category_update_type CASCADE;
CREATE TYPE task_manager.category_update_type AS
(
    id          BIGINT,
    name        TEXT,
    description TEXT
);

-- Task types
DROP TYPE IF EXISTS task_manager.task_id_type CASCADE;
CREATE TYPE task_manager.task_id_type AS
(
    id BIGINT
);

DROP TYPE IF EXISTS task_manager.task_create_type CASCADE;
CREATE TYPE task_manager.task_create_type AS
(
    title       TEXT,
    description TEXT,
    status      TEXT,
    priority    INTEGER,
    category_id BIGINT,
    metadata    jsonb,
    due_date    TIMESTAMP WITH TIME ZONE
);

DROP TYPE IF EXISTS task_manager.task_update_type CASCADE;
CREATE TYPE task_manager.task_update_type AS
(
    id          BIGINT,
    title       TEXT,
    description TEXT,
    status      TEXT,
    priority    INTEGER,
    category_id BIGINT,
    metadata    jsonb,
    due_date    TIMESTAMP WITH TIME ZONE
);

DROP TYPE IF EXISTS task_manager.task_filter_type CASCADE;
CREATE TYPE task_manager.task_filter_type AS
(
    category_id BIGINT,
    status      TEXT,
    priority    INTEGER
);

DROP TYPE IF EXISTS task_manager.task_tag_type CASCADE;
CREATE TYPE task_manager.task_tag_type AS
(
    id  BIGINT,
    tag TEXT
);

-- Result type for delete operations
DROP TYPE IF EXISTS task_manager.delete_result_type CASCADE;
CREATE TYPE task_manager.delete_result_type AS
(
    success BOOLEAN,
    message TEXT,
    id      BIGINT
);

-- Sample data for categories
INSERT INTO task_manager.category (name, description)
VALUES ('Work', 'Work-related tasks'),
       ('Personal', 'Personal tasks'),
       ('Shopping', 'Shopping list items');

-- Sample data for tasks
INSERT INTO task_manager.task (title, description, status, priority, category_id, metadata, due_date)
VALUES ('Complete project proposal', 'Write up the proposal for the new client project', 'pending', 3, 1, '{
  "assigned_to": "John",
  "estimated_hours": 4
}'::jsonb, current_timestamp + INTERVAL '3 days'),
       ('Buy groceries', 'Get milk, eggs, and bread', 'pending', 2, 3, '{
         "store": "Supermarket"
       }'::jsonb, current_timestamp + INTERVAL '1 day'),
       ('Schedule dentist appointment', 'Call dentist to schedule annual checkup', 'pending', 1, 2, '{}'::jsonb,
        current_timestamp + INTERVAL '7 days');