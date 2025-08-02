SELECT api.set_log_level('DEBUG');

DO
$$
    BEGIN
        IF NOT exists (SELECT 1 FROM pg_tables WHERE schemaname = 'task_manager' AND tablename = 'category') THEN
            RAISE EXCEPTION 'The task_manager.category table does not exist. Please run task-manager.sql first.';
        END IF;

        IF NOT exists (SELECT 1 FROM pg_tables WHERE schemaname = 'task_manager' AND tablename = 'task') THEN
            RAISE EXCEPTION 'The task_manager.task table does not exist. Please run task-manager.sql first.';
        END IF;
    END
$$;

CREATE OR REPLACE FUNCTION task_manager.get_all_categories()
    RETURNS SETOF task_manager.category AS
$$
BEGIN
    RETURN QUERY SELECT * FROM task_manager.category;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION task_manager.get_category(p_category_id task_manager.category_id_type)
    RETURNS task_manager.category AS
$$
BEGIN
    RETURN api_persist.fetch_record(NULL::task_manager.category, p_category_id.id::TEXT, TRUE);
END;
$$ LANGUAGE plpgsql;

-- Function to create a new category
CREATE OR REPLACE FUNCTION task_manager.create_category(
    p_create task_manager.category_create_type
)
    RETURNS task_manager.category AS
$$
BEGIN
    RETURN api_persist.insert_record(
            jsonb_populate_record(NULL::task_manager.category, to_jsonb(p_create))
           );
END;
$$ LANGUAGE plpgsql;

-- Function to update a category
CREATE OR REPLACE FUNCTION task_manager.update_category(
    p_update task_manager.category_update_type
)
    RETURNS task_manager.category AS
$$
BEGIN
    RETURN api_persist.update_record(
            jsonb_populate_record(NULL::task_manager.category, to_jsonb(p_update))
           );
END;
$$ LANGUAGE plpgsql;

-- Function to delete a category
CREATE OR REPLACE FUNCTION task_manager.delete_category(p_category_id category_id_type)
    RETURNS category AS
$$
BEGIN
    RETURN api_persist.delete_record(
            jsonb_populate_record(NULL::task_manager.category, to_jsonb(p_category_id))
           );
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS task_manager.get_task(p_task_id task_manager.task_id_type);
CREATE OR REPLACE FUNCTION task_manager.get_task(p_task_id task_manager.task_id_type)
    RETURNS jsonb AS
$$
DECLARE
    v_task task_manager.task;
BEGIN
    v_task = api_persist.fetch_record(NULL::task_manager.task, p_task_id.id::TEXT, TRUE);
    RETURN to_jsonb(v_task) || jsonb_build_object(
            'category',
            CASE
                WHEN v_task.category_id IS NULL THEN NULL
                ELSE api_persist.fetch_record(NULL::task_manager.category, v_task.category_id::TEXT, TRUE)
                END
                               );
END;
$$ LANGUAGE plpgsql;

-- Function to create a new task
CREATE OR REPLACE FUNCTION task_manager.create_task(
    p_create task_manager.task_create_type
)
    RETURNS task_manager.task AS
$$
BEGIN
    -- Validate the category if provided
    IF p_create.category_id IS NOT NULL AND NOT exists (SELECT 1
                                                        FROM task_manager.category
                                                        WHERE id = p_create.category_id) THEN
        PERFORM api.throw_invalid('Category with ID ' || p_create.category_id || ' does not exist');
    END IF;
    RAISE NOTICE 'Creating task with data: %', p_create;
    -- Use the persistence layer to insert the record
    RETURN api_persist.insert_record(
            jsonb_populate_record(NULL::task_manager.task, to_jsonb(p_create))
           );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION task_manager.update_task(
    p_update task_manager.task_update_type
)
    RETURNS task_manager.task AS
$$
BEGIN
    RETURN api_persist.update_record(
            jsonb_populate_record(NULL::task_manager.task, to_jsonb(p_update))
           );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION task_manager.delete_task(p_task_id task_id_type)
    RETURNS task_manager.task AS
$$
BEGIN
    RETURN api_persist.delete_record(
            jsonb_populate_record(NULL::task_manager.task, to_jsonb(p_task_id))
           );
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS task_manager.get_all_tasks();
CREATE OR REPLACE FUNCTION task_manager.get_all_tasks()
    RETURNS SETOF jsonb AS
$$
BEGIN
    RETURN QUERY
        WITH tasks AS (SELECT t_tasks, t_categories
                       FROM task_manager.task t_tasks
                                LEFT JOIN task_manager.category t_categories ON t_tasks.category_id = t_categories.id)
        SELECT to_jsonb(t.t_tasks) || jsonb_build_object(
                'category', to_jsonb(t.t_categories)
                                      )
        FROM tasks t;
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS task_manager.set_task_metadata(p_metadata_info jsonb);
CREATE OR REPLACE FUNCTION task_manager.set_task_metadata(p_metadata_info jsonb)
    RETURNS task_manager.task AS
$$
DECLARE
    v_task task_manager.task;
BEGIN
    -- Validate the metadata structure
    IF NOT p_metadata_info ? 'task_id' THEN
        PERFORM api.throw_invalid('Metadata must contain task_id');
    END IF;

    -- Update the task metadata
    v_task = api_persist.fetch_record(NULL::task_manager.task, p_metadata_info ->> 'task_id', TRUE);
    v_task.metadata = p_metadata_info -> 'metadata_info';
    RETURN api_persist.update_record(v_task);
END;
$$ LANGUAGE plpgsql;

SELECT *
FROM api.call('task_manager.set_task_metadata',
        '{
          "task_id": "1",
          "metadata_info": {
            "Note": "This is a note for the task",
            "Todo": [
              "Subtask 1",
              "Subtask 2"
            ],
            "Reminder": "2023-10-01T10:00:00Z"
          }
        }'::jsonb
     );