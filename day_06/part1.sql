-- Create a clean schema with a table for the raw input and import the data
DROP SCHEMA IF EXISTS day6_part1 CASCADE;
CREATE SCHEMA day6_part1;
CREATE TABLE day6_part1.input (data TEXT);
COPY day6_part1.input FROM '/days/day_6/input.txt';

CREATE SEQUENCE day6_part1.row_id_seq;
CREATE TABLE day6_part1.input_with_row_id AS SELECT nextval('day6_part1.row_id_seq') AS row_id, data FROM day6_part1.input;

CREATE TYPE day6_part1.coordinate AS (
    x INT,
    y INT
);

CREATE TYPE day6_part1.direction AS ENUM ('^', 'v', '<', '>');
CREATE TYPE day6_part1.new_position AS (
    position day6_part1.coordinate,
    direction day6_part1.direction
);

CREATE TABLE day6_part1.visited_coordinates (
    coordinate day6_part1.coordinate
);

CREATE OR REPLACE FUNCTION day6_part1.find_start_position() RETURNS day6_part1.coordinate AS $$
BEGIN
    RETURN (
        SELECT (
            CASE
                WHEN position('^' IN data) > 0 THEN position('^' IN data)
                WHEN position('<' IN data) > 0 THEN position('<' IN data)
                WHEN position('v' IN data) > 0 THEN position('v' IN data)
                WHEN position('> ' IN data) > 0 THEN position('>' IN data)
            END,
            row_id
        )::day6_part1.coordinate
        FROM day6_part1.input_with_row_id
        WHERE data ILIKE '%^%'
           OR data ILIKE '%v%'
           OR data ILIKE '%<%'
           OR data ILIKE '%>'
    );
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day6_part1.char_at(coordinate day6_part1.coordinate) RETURNS TEXT AS $$
BEGIN
    RETURN (
        SELECT substring(data FROM coordinate.x FOR 1)
        FROM day6_part1.input_with_row_id
        WHERE row_id = coordinate.y
    );
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day6_part1.move(_from_coordinate day6_part1.coordinate, _current_direction day6_part1.direction)
RETURNS day6_part1.coordinate AS $$
DECLARE
    _new_coordinate day6_part1.coordinate;
BEGIN
    IF _current_direction = '^' THEN
        _new_coordinate = (_from_coordinate.x, _from_coordinate.y - 1);
    ELSEIF _current_direction = 'v' THEN
        _new_coordinate = (_from_coordinate.x, _from_coordinate.y + 1);
    ELSEIF _current_direction = '<' THEN
        _new_coordinate = (_from_coordinate.x - 1, _from_coordinate.y);
    ELSEIF _current_direction = '>' THEN
        _new_coordinate = (_from_coordinate.x + 1, _from_coordinate.y);
    END IF;

    RETURN _new_coordinate;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day6_part1.move_with_walldetect(_from_coordinate day6_part1.coordinate, _current_direction day6_part1.direction)
RETURNS day6_part1.new_position AS $$
DECLARE
    _current_char TEXT;
    _new_coordinate day6_part1.coordinate;
BEGIN
    _new_coordinate := day6_part1.move(_from_coordinate, _current_direction);

    _current_char = day6_part1.char_at(_new_coordinate);
    IF _current_char = '#' THEN
        RAISE DEBUG 'Wall detected at % whilst moving %', _new_coordinate, _current_direction;

        IF _current_direction = '^' THEN
            _current_direction = '>';
        ELSEIF _current_direction = '>' THEN
            _current_direction = 'v';
        ELSEIF _current_direction = 'v' THEN
            _current_direction = '<';
        ELSEIF _current_direction = '<' THEN
            _current_direction = '^';
        END IF;

        -- Start again from the initial _from_coordinate, after rotating the direction
        _new_coordinate := day6_part1.move(_from_coordinate, _current_direction);
    END IF;

    return (_new_coordinate, _current_direction);
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day6_part1.part1() RETURNS INT AS $$
DECLARE
    _current_position day6_part1.coordinate;
    _new_position_with_direction day6_part1.new_position;
    _current_char TEXT;
    _current_direction day6_part1.direction;
    _num_rows INT = currval('day6_part1.row_id_seq')::TEXT;
    _num_cols INT = length((SELECT data FROM day6_part1.input_with_row_id WHERE row_id = 1));
    _steps INT = 0;
BEGIN
    _current_position = day6_part1.find_start_position();
    _current_char = day6_part1.char_at(_current_position);
    _current_direction = _current_char::day6_part1.direction;

    RAISE NOTICE 'Num rows: %', _num_rows;
    RAISE NOTICE 'Num cols: %', _num_cols;

    RAISE NOTICE 'Start position % with direction %', _current_position, _current_direction;

    WHILE true LOOP
        RAISE DEBUG 'Step % at %', _steps, _current_position;

        IF _current_position.x > _num_cols OR _current_position.x < 0 OR _current_position.y > _num_rows OR _current_position.y < 0 THEN
            RAISE NOTICE 'Done after % steps at %', _steps, _current_position;
            EXIT;
        END IF;

        _steps := _steps + 1;

        RAISE DEBUG 'Step % at % with direction %', _steps, _current_position, _current_direction;

        _new_position_with_direction := day6_part1.move_with_walldetect(_current_position, _current_direction);
        _current_position := _new_position_with_direction.position;
        _current_direction := _new_position_with_direction.direction;

        INSERT INTO day6_part1.visited_coordinates VALUES (_current_position);
    END LOOP;

    -- -1 to drop the last coordinate as that is actually the one that moved us out of the grid
    RETURN (SELECT count(DISTINCT coordinate) FROM day6_part1.visited_coordinates);
END $$ LANGUAGE plpgsql;

SELECT day6_part1.part1() "The answer for part 1 of day 6 is";