-- Create a clean schema with a table for the raw input and import the data
DROP SCHEMA IF EXISTS day15_part1 CASCADE;
CREATE SCHEMA day15_part1;
CREATE TABLE day15_part1.input (data TEXT);
COPY day15_part1.input FROM '/days/day_15/input.txt';

-- Split the input into a view with the grid, and a view with the moves
CREATE MATERIALIZED VIEW day15_part1.one_long_string AS SELECT string_agg(data, '\n') AS data FROM day15_part1.input;
CREATE MATERIALIZED VIEW day15_part1.grid_and_moves AS SELECT regexp_split_to_table(data, '\\n\\n') AS data FROM day15_part1.one_long_string;
CREATE SEQUENCE day15_part1.grid_row_seq;
CREATE MATERIALIZED VIEW day15_part1.initial_grid AS SELECT nextval('day15_part1.grid_row_seq') y, regexp_split_to_table(data, '\\n') AS data FROM (SELECT * FROM day15_part1.grid_and_moves LIMIT 1 OFFSET 0) AS grid_only;
CREATE MATERIALIZED VIEW day15_part1.moves AS SELECT regexp_replace(data, '\\n', '') data FROM day15_part1.grid_and_moves LIMIT 1 OFFSET 1;

-- Create a working copy of the grid, which we can manipulate
CREATE TABLE day15_part1.grid (y INT, data TEXT);
INSERT INTO day15_part1.grid SELECT * FROM day15_part1.initial_grid;

-- Keep in mind that in PostgreSQL, indices start at 1, not 0
CREATE TYPE day15_part1.coordinate AS (
    x INT,
    y INT
);

-- Figure out where the robot starts
CREATE OR REPLACE FUNCTION day15_part1.find_start_position() RETURNS day15_part1.coordinate AS $$
BEGIN
    RETURN (
        SELECT (
            position('@' IN data),
            y
        )::day15_part1.coordinate
        FROM day15_part1.initial_grid
        WHERE data ILIKE '%@%'
    );
END $$ LANGUAGE plpgsql;

-- Update a specific spot in the grid, which we need to do when a box moves
CREATE OR REPLACE FUNCTION day15_part1.update_grid(_coordinate day15_part1.coordinate, _new_data CHAR) RETURNS VOID AS $$
BEGIN
    UPDATE day15_part1.grid SET data = overlay(data placing _new_data from _coordinate.x for 1) WHERE y = _coordinate.y;
END $$ LANGUAGE plpgsql;

-- Get the character currently at a specific coordinate
CREATE OR REPLACE FUNCTION day15_part1.char_at(coordinate day15_part1.coordinate) RETURNS TEXT AS $$
BEGIN
    RETURN (
        SELECT substring(data FROM coordinate.x FOR 1)
        FROM day15_part1.grid
        WHERE y = coordinate.y
    )::CHAR;
END $$ LANGUAGE plpgsql;

-- Process the moves and update the grid accordingly
CREATE OR REPLACE FUNCTION day15_part1.perform_moves() RETURNS VOID AS $$
DECLARE
    _directions day15_part1.coordinate[] = ARRAY[(0, -1), (0, 1), (1, 0), (-1, 0)]; -- Up, down, right, left
    _current_coordinate day15_part1.coordinate;
    _move CHAR;
    _move_offset day15_part1.coordinate;
    _new_coordinate day15_part1.coordinate;
    _new_coordinate_char TEXT;
    _neighbour day15_part1.coordinate;
BEGIN
    _current_coordinate := day15_part1.find_start_position();
    PERFORM day15_part1.update_grid(_current_coordinate, '.');

    RAISE DEBUG 'Start position: %', _current_coordinate;

    FOREACH _move IN ARRAY (SELECT regexp_split_to_array(data, '') FROM day15_part1.moves) LOOP
        _move_offset := _directions[CASE
            WHEN _move = '^' THEN 1
            WHEN _move = 'v' THEN 2
            WHEN _move = '>' THEN 3
            WHEN _move = '<' THEN 4
        END];

        _new_coordinate := (_current_coordinate.x + _move_offset.x, _current_coordinate.y + _move_offset.y);
        _new_coordinate_char := day15_part1.char_at(_new_coordinate);
        IF _new_coordinate_char = '.' THEN
            -- Move to the empty space
            _current_coordinate := _new_coordinate;
        ELSE
            _neighbour := _new_coordinate;
            WHILE _new_coordinate_char = 'O' LOOP
                _neighbour := (_neighbour.x + _move_offset.x, _neighbour.y + _move_offset.y);
                _new_coordinate_char := day15_part1.char_at(_neighbour);
            END LOOP;
            RAISE DEBUG 'Loop done with char % at %', _new_coordinate_char, _neighbour;
            IF _new_coordinate_char = '.' THEN
                -- Bump the boxes over 1 spot (simply move the box currently our immediate neighbour to the end of the line)
                PERFORM day15_part1.update_grid(_new_coordinate, '.');
                PERFORM day15_part1.update_grid(_neighbour, 'O');
                _current_coordinate := _new_coordinate;
            ELSIF _new_coordinate_char <> '#' THEN
                RAISE EXCEPTION 'Unexpected character % at % (expected #)', _new_coordinate_char, _neighbour;
            END IF;
        END IF;
    END LOOP;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day15_part1.calculate_box_coordinate_sum() RETURNS BIGINT AS $$
DECLARE
    _result BIGINT = 0;
    _row day15_part1.grid;
    _x INT = 1;
BEGIN
    FOR _row IN (SELECT * FROM day15_part1.grid WHERE data ILIKE '%O%') LOOP
        FOR _x IN 1..length(_row.data) LOOP
            IF substring(_row.data FROM _x FOR 1) = 'O' THEN
                -- -1 for both as PostgreSQL indices start at 1, not 0
                _result := _result + ((_x - 1) + ((_row.y - 1) * 100));
            END IF;
        END LOOP;
    END LOOP;

    RETURN _result;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day15_part1.part1() RETURNS BIGINT AS $$
BEGIN
    PERFORM day15_part1.perform_moves();
    RETURN day15_part1.calculate_box_coordinate_sum();
END $$ LANGUAGE plpgsql;

SELECT day15_part1.part1() "The answer for part 1 of day 15 is";