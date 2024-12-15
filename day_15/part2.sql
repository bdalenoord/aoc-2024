-- Create a clean schema with a table for the raw input and import the data
DROP SCHEMA IF EXISTS day15_part2 CASCADE;
CREATE SCHEMA day15_part2;
CREATE TABLE day15_part2.input (data TEXT);
COPY day15_part2.input FROM '/days/day_15/input.txt';

-- Split the input into a view with the grid, and a view with the moves
CREATE MATERIALIZED VIEW day15_part2.one_long_string AS SELECT string_agg(data, '\n') AS data FROM day15_part2.input;
CREATE MATERIALIZED VIEW day15_part2.grid_and_moves AS SELECT regexp_split_to_table(data, '\\n\\n') AS data FROM day15_part2.one_long_string;
CREATE SEQUENCE day15_part2.grid_row_seq;
CREATE MATERIALIZED VIEW day15_part2.initial_grid AS SELECT nextval('day15_part2.grid_row_seq') y, regexp_split_to_table(data, '\\n') AS data FROM (SELECT * FROM day15_part2.grid_and_moves LIMIT 1 OFFSET 0) AS grid_only;
CREATE MATERIALIZED VIEW day15_part2.moves AS SELECT regexp_replace(data, '\\n', '') data FROM day15_part2.grid_and_moves LIMIT 1 OFFSET 1;

-- Create a working copy of the grid, which we can manipulate. The working copy is also expanded.
CREATE TABLE day15_part2.grid (y INT, data TEXT);
CREATE OR REPLACE FUNCTION day15_part2.expand_grid() RETURNS VOID AS $$
DECLARE
    _row day15_part2.grid;
    _idx INT;
    _spot TEXT;
    _expanded_spot TEXT;
    _expanded_row TEXT = '';
BEGIN
    FOR _row IN (SELECT * FROM day15_part2.initial_grid) LOOP
        _expanded_row := '';
        FOR _idx IN 1..(length(_row.data)) LOOP
            _spot = substring(_row.data FROM _idx FOR 1);
            _expanded_spot = CASE
                WHEN _spot = '.' THEN '..'
                WHEN _spot = '#' THEN '##'
                WHEN _spot = 'O' THEN '[]'
                WHEN _spot = '@' THEN '@.'
            END;
            _expanded_row := _expanded_row || _expanded_spot;
        END LOOP;
        INSERT INTO day15_part2.grid VALUES (_row.y, _expanded_row);
    END LOOP;
END $$ LANGUAGE plpgsql;
SELECT day15_part2.expand_grid();

-- Keep in mind that in PostgreSQL, indices start at 1, not 0
CREATE TYPE day15_part2.coordinate AS (
    x INT,
    y INT
);

-- Figure out where the robot starts
CREATE OR REPLACE FUNCTION day15_part2.find_start_position() RETURNS day15_part2.coordinate AS $$
BEGIN
    RETURN (
        SELECT (
            position('@' IN data),
            y
        )::day15_part2.coordinate
        FROM day15_part2.grid
        WHERE data ILIKE '%@%'
    );
END $$ LANGUAGE plpgsql;

-- Update a specific spot in the grid, which we need to do when a box moves
CREATE OR REPLACE FUNCTION day15_part2.update_grid(_coordinate day15_part2.coordinate, _new_data CHAR) RETURNS VOID AS $$
BEGIN
    UPDATE day15_part2.grid SET data = overlay(data placing _new_data from _coordinate.x for 1) WHERE y = _coordinate.y;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day15_part2.drop_character(_x INT, _from TEXT) RETURNS TEXT AS $$
BEGIN
    RETURN substr(_from, 1, _x - 1) || substr(_from, _x + 1);
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day15_part2.insert_character(_x INT, _into TEXT, _char CHAR) RETURNS TEXT AS $$
BEGIN
    RETURN substr(_into, 1, _x - 1) || _char || substr(_into, _x);
END $$ LANGUAGE plpgsql;

-- Get the character currently at a specific coordinate
CREATE OR REPLACE FUNCTION day15_part2.char_at(coordinate day15_part2.coordinate) RETURNS TEXT AS $$
BEGIN
    RETURN (
        SELECT substring(data FROM coordinate.x FOR 1)
        FROM day15_part2.grid
        WHERE y = coordinate.y
    )::CHAR;
END $$ LANGUAGE plpgsql;

-- Bump over boxes horizontally. Returns `true` if boxes were bumped, `false` otherwise (so if `true` is returned, a
-- new empty space has become available for the robot to move into).
CREATE OR REPLACE FUNCTION day15_part2.move_horizontal(
    _move_offset day15_part2.coordinate,
    _origin day15_part2.coordinate
) RETURNS BOOLEAN AS $$
DECLARE
    _new_x INT;
    _char TEXT;
    _row day15_part2.grid;
    _new_row TEXT;
BEGIN
    _char := day15_part2.char_at(_origin);
    _new_x := _origin.x;
    WHILE _char = '[' OR _char = ']' LOOP
        _new_x := _new_x + _move_offset.x;
        _char := day15_part2.char_at((_new_x, _origin.y));
    END LOOP;
    IF _char = '.' THEN
        SELECT * INTO _row FROM day15_part2.grid WHERE y = _origin.y;
        _new_row := day15_part2.drop_character(_new_x, _row.data);
        _new_row := day15_part2.insert_character(_origin.x, _new_row, '.');

        RAISE DEBUG E'Row \n%, new row \n%\n', _row.data, _new_row;
        UPDATE day15_part2.grid SET data = _new_row WHERE y = _origin.y;
        PERFORM day15_part2.update_grid(_origin, '.');
        RETURN TRUE;
    ELSIF _char <> '#' THEN
        RAISE EXCEPTION 'Unexpected character % at %, expected #', _char, (_new_x, _origin.y);
    END IF;

    RETURN FALSE;
END $$ LANGUAGE plpgsql;

CREATE TABLE day15_part2.seen_coords (x INT, y INT, PRIMARY KEY (x, y));

CREATE OR REPLACE FUNCTION day15_part2.calculate_updated_position_for_box(
    _box day15_part2.coordinate,
    _todos day15_part2.coordinate[]
) RETURNS day15_part2.coordinate[] AS $$
DECLARE
    _char TEXT;
    _seen_coord day15_part2.seen_coords;
    _new_todos day15_part2.coordinate[] = _todos;
BEGIN
    _char := day15_part2.char_at(_box);

    SELECT * INTO _seen_coord FROM day15_part2.seen_coords WHERE x = _box.x AND y = _box.y;
    IF _seen_coord IS NULL THEN
        INSERT INTO day15_part2.seen_coords VALUES (_box.x, _box.y);
        _new_todos := _new_todos || _box;

        IF _char = '[' THEN
            -- Move right half of the box
            _new_todos := day15_part2.calculate_updated_position_for_box((_box.x + 1, _box.y), _new_todos);
        ELSIF _char <> ']' THEN
            PERFORM day15_part2.debug_grid('Grid before failure');
            RAISE EXCEPTION 'Unexpected character % at %, expected ]', _char, _box;
        ELSE
            -- Move left half of the box
            _new_todos := day15_part2.calculate_updated_position_for_box((_box.x - 1, _box.y), _new_todos);
        END IF;
    ELSE
        RAISE DEBUG 'Already seen %', _box;
    END IF;

    RETURN _new_todos;
END $$ LANGUAGE plpgsql;

-- From https://wiki.postgresql.org/wiki/Array_reverse
CREATE OR REPLACE FUNCTION array_reverse(anyarray) RETURNS anyarray AS $$
SELECT ARRAY(
    SELECT $1[i]
    FROM generate_subscripts($1,1) AS s(i)
    ORDER BY i DESC
);
$$ LANGUAGE 'sql' STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION day15_part2.move_vertical(
    _move_offset day15_part2.coordinate,
    _origin day15_part2.coordinate
) RETURNS BOOLEAN AS $$
DECLARE
    _todos day15_part2.coordinate[] = ARRAY[]::day15_part2.coordinate[];
    _i INT = 1;
    _todo day15_part2.coordinate;
    _char TEXT;
BEGIN
    TRUNCATE day15_part2.seen_coords;

    _todos := day15_part2.calculate_updated_position_for_box(_origin, _todos);

    WHILE true LOOP
        IF _i > array_length(_todos, 1) THEN
            EXIT;
        END IF;

        _todo := _todos[_i];
        _char := day15_part2.char_at((_todo.x, _todo.y + _move_offset.y));
        IF _char = '#' THEN
            RETURN FALSE; -- Found the edge
        END IF;
        IF _char != '.' THEN
            _todos := day15_part2.calculate_updated_position_for_box((_todo.x, _todo.y + _move_offset.y), _todos);
        END IF;

        _i := _i + 1;
    END LOOP;

    FOREACH _todo IN ARRAY array_reverse(_todos) LOOP
        _char := day15_part2.char_at((_todo.x, _todo.y + _move_offset.y));
        IF _char = '#' THEN
            RETURN FALSE; -- Found the edge
        END IF;
    END LOOP;

    FOREACH _todo IN ARRAY array_reverse(_todos) LOOP
        _char := day15_part2.char_at((_todo.x, _todo.y + _move_offset.y));
        IF _char <> '.' THEN
            RAISE NOTICE 'Todos: %, reversed: %', _todos, array_reverse(_todos);
            RAISE EXCEPTION 'Expected empty spot at %, found % when moving % in direction %', (_todo.x, _todo.y + _move_offset.y), _char, _origin, _move_offset;
        END IF;

        _char := day15_part2.char_at(_todo);
        PERFORM day15_part2.update_grid((_todo.x, _todo.y + _move_offset.y), _char);
        PERFORM day15_part2.update_grid(_todo, '.');
    END LOOP;

    RETURN TRUE;
END $$ LANGUAGE plpgsql;

-- Process the moves and update the grid accordingly
CREATE OR REPLACE FUNCTION day15_part2.perform_moves() RETURNS VOID AS $$
DECLARE
    _directions day15_part2.coordinate[] = ARRAY[(0, -1), (0, 1), (1, 0), (-1, 0)]; -- Up, down, right, left
    _current_coordinate day15_part2.coordinate;
    _move CHAR;
    _move_offset day15_part2.coordinate;
    _new_coordinate day15_part2.coordinate;
    _new_coordinate_char TEXT;
    _did_bump BOOLEAN;
BEGIN
    _current_coordinate := day15_part2.find_start_position();
    PERFORM day15_part2.update_grid(_current_coordinate, '.');

    RAISE NOTICE 'Start position: %', _current_coordinate;

    FOREACH _move IN ARRAY (SELECT regexp_split_to_array(data, '') FROM day15_part2.moves) LOOP
        _move_offset := _directions[CASE
            WHEN _move = '^' THEN 1
            WHEN _move = 'v' THEN 2
            WHEN _move = '>' THEN 3
            WHEN _move = '<' THEN 4
        END];

        _new_coordinate := (_current_coordinate.x + _move_offset.x, _current_coordinate.y + _move_offset.y);
        _new_coordinate_char := day15_part2.char_at(_new_coordinate);
        IF _new_coordinate_char = '.' THEN
            -- Immediately move to the empty spot
            _current_coordinate := _new_coordinate;
        ELSIF _new_coordinate_char = '[' OR _new_coordinate_char = ']' THEN
            IF _move_offset.y = 0 THEN
                _did_bump := day15_part2.move_horizontal(_move_offset, _new_coordinate);
            ELSE
                _did_bump := day15_part2.move_vertical(_move_offset, _new_coordinate);
            END IF;

            IF _did_bump THEN
                _current_coordinate := _new_coordinate;
            END IF;
        END IF;
    END LOOP;


    PERFORM day15_part2.update_grid(_current_coordinate, '@');
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day15_part2.calculate_box_coordinate_sum() RETURNS BIGINT AS $$
DECLARE
    _result BIGINT = 0;
    _row day15_part2.grid;
    _x INT = 1;
BEGIN
    FOR _row IN (SELECT * FROM day15_part2.grid WHERE data ILIKE '%[%') LOOP
        FOR _x IN 1..length(_row.data) LOOP
            IF substring(_row.data FROM _x FOR 1) = '[' THEN
                -- -1 for both as PostgreSQL indices start at 1, not 0
                _result := _result + ((_x - 1) + ((_row.y - 1) * 100));
            END IF;
        END LOOP;
    END LOOP;

    RETURN _result;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day15_part2.debug_grid(_lead_in TEXT, _robot_coord day15_part2.coordinate = null) RETURNS VOID AS $$
BEGIN
    IF _robot_coord IS NOT NULL THEN
        PERFORM day15_part2.update_grid(_robot_coord, '@');
    END IF;

    RAISE DEBUG E'%: \n%',
        _lead_in,
        (SELECT string_agg(data, E'\n') FROM (SELECT data FROM day15_part2.grid ORDER BY y) AS grid)
    ;

    IF _robot_coord IS NOT NULL THEN
        PERFORM day15_part2.update_grid(_robot_coord, '.');
    END IF;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day15_part2.part2() RETURNS BIGINT AS $$
DECLARE
    _result BIGINT;
BEGIN
    PERFORM day15_part2.debug_grid('Initial Grid');

    PERFORM day15_part2.perform_moves();
    _result := day15_part2.calculate_box_coordinate_sum();

    PERFORM day15_part2.debug_grid('Final Grid');

    RETURN _result;
END $$ LANGUAGE plpgsql;

SELECT day15_part2.part2() "The answer for part 2 of day 15 is";