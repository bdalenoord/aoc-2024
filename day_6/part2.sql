-- Create a clean schema with a table for the raw input and import the data
DROP SCHEMA IF EXISTS day6_part2 CASCADE;
CREATE SCHEMA day6_part2;
CREATE TABLE day6_part2.input (data TEXT);
COPY day6_part2.input FROM '/days/day_6/input.txt';

CREATE SEQUENCE day6_part2.row_id_seq;
CREATE TABLE day6_part2.input_with_row_id AS SELECT nextval('day6_part2.row_id_seq') AS row_id, data FROM day6_part2.input;
CREATE INDEX ON day6_part2.input_with_row_id (row_id);

CREATE TYPE day6_part2.coordinate AS (
    x INT,
    y INT
);

CREATE TYPE day6_part2.direction AS ENUM ('^', 'v', '<', '>');
CREATE TYPE day6_part2.new_position AS (
    position day6_part2.coordinate,
    direction day6_part2.direction
);

CREATE TABLE day6_part2.visited_coordinates (
    id BIGSERIAL,
    coordinate day6_part2.coordinate,

    PRIMARY KEY (coordinate)
);
CREATE TABLE day6_part2.revisited_coordinates (
    coordinate day6_part2.coordinate,
    direction day6_part2.direction,

    PRIMARY KEY (coordinate, direction)
);
CREATE INDEX ON day6_part2.revisited_coordinates (coordinate, direction);

CREATE OR REPLACE FUNCTION day6_part2.find_start_position() RETURNS day6_part2.coordinate AS $$
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
        )::day6_part2.coordinate
        FROM day6_part2.input_with_row_id
        WHERE data ILIKE '%^%'
           OR data ILIKE '%v%'
           OR data ILIKE '%<%'
           OR data ILIKE '%>'
    );
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day6_part2.char_at(coordinate day6_part2.coordinate) RETURNS TEXT AS $$
BEGIN
    RETURN (
        SELECT substring(data FROM coordinate.x FOR 1)
        FROM day6_part2.input_with_row_id
        WHERE row_id = coordinate.y
    );
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day6_part2.move(_from_coordinate day6_part2.coordinate, _current_direction day6_part2.direction)
RETURNS day6_part2.coordinate AS $$
DECLARE
    _new_coordinate day6_part2.coordinate;
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

CREATE OR REPLACE FUNCTION day6_part2.rotate_direction(_current_direction day6_part2.direction) RETURNS day6_part2.direction AS $$
BEGIN
    IF _current_direction = '^' THEN
        RETURN '>';
    ELSEIF _current_direction = '>' THEN
        RETURN 'v';
    ELSEIF _current_direction = 'v' THEN
        RETURN '<';
    ELSEIF _current_direction = '<' THEN
        RETURN '^';
    END IF;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day6_part2.move_with_walldetect(
    _from_coordinate day6_part2.coordinate,
    _current_direction day6_part2.direction,
    _new_obstacle day6_part2.coordinate
)
RETURNS day6_part2.new_position AS $$
DECLARE
    _current_char TEXT;
    _new_coordinate day6_part2.coordinate;
BEGIN
    _new_coordinate := day6_part2.move(_from_coordinate, _current_direction);

    _current_char = day6_part2.char_at(_new_coordinate);
    IF _current_char = '#' THEN
        RAISE DEBUG 'Wall detected at % whilst moving %', _new_coordinate, _current_direction;

        _current_direction := day6_part2.rotate_direction(_current_direction);

        -- Start again from the initial _from_coordinate, after rotating the direction
        _new_coordinate := day6_part2.move(_from_coordinate, _current_direction);
    ELSEIF _new_coordinate = _new_obstacle THEN
        RAISE DEBUG 'New obstacle at % whilst moving %', _new_coordinate, _current_direction;

        _current_direction := day6_part2.rotate_direction(_current_direction);

        -- Start again from the initial _from_coordinate, after rotating the direction
        _new_coordinate := day6_part2.move(_from_coordinate, _current_direction);
    END IF;

    return (_new_coordinate, _current_direction);
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day6_part2.solve(
    _new_obstacle day6_part2.coordinate = null
) RETURNS INT AS $$
DECLARE
    _current_position day6_part2.coordinate;
    _new_position_with_direction day6_part2.new_position;
    _current_char TEXT;
    _current_direction day6_part2.direction;
    _num_rows INT = currval('day6_part2.row_id_seq')::TEXT;
    _num_cols INT = length((SELECT data FROM day6_part2.input_with_row_id WHERE row_id = 1));
    _steps INT = 0;
    _loop_detect INT = 0;
BEGIN
    _current_position = day6_part2.find_start_position();
    _current_char = day6_part2.char_at(_current_position);
    _current_direction = _current_char::day6_part2.direction;

    RAISE DEBUG 'Start position % with direction %', _current_position, _current_direction;

    WHILE true LOOP
        -- Once we walk out of the grid, we're done. Return 0, indicating no loop found
        IF _current_position.x >= _num_cols OR _current_position.x < 0 OR _current_position.y >= _num_rows OR _current_position.y < 0 THEN
            RAISE DEBUG 'Done after % steps at % (new obstacle at %)', _steps, _current_position, _new_obstacle;
            RETURN 0;
        END IF;

        _steps := _steps + 1;
        RAISE DEBUG 'Step % at % with direction %', _steps, _current_position, _current_direction;

        -- Move into the new position and direction
        _new_position_with_direction := day6_part2.move_with_walldetect(
                _current_position,
                _current_direction,
                _new_obstacle
        );
        _current_position := _new_position_with_direction.position;
        _current_direction := _new_position_with_direction.direction;

        IF _new_obstacle IS NOT NULL THEN
            _loop_detect := (
                SELECT
                    1
                FROM
                    day6_part2.revisited_coordinates
                WHERE
                    coordinate = _new_position_with_direction.position
                AND
                    direction = _new_position_with_direction.direction
            );
            IF _loop_detect > 0 THEN
                RAISE NOTICE 'Loop detected at % with direction % with new obstacle at %', _current_position, _current_direction, _new_obstacle;
                RETURN 1;
            END IF;
        END IF;

        IF _new_obstacle IS NULL THEN -- Store the initial path only when not placing extra obstacles
            INSERT INTO day6_part2.visited_coordinates (coordinate)
            VALUES (_current_position)
            ON CONFLICT DO NOTHING;
        END IF;

        -- Keep track of revisits to coordinates, so we can cycle-detect
        INSERT INTO day6_part2.revisited_coordinates
        VALUES (_current_position, _current_direction)
        ON CONFLICT DO NOTHING;
    END LOOP;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day6_part2.part2() RETURNS INT AS $$
DECLARE
    _previously_visited day6_part2.visited_coordinates;
    _to_check INT;
    _index INT = 1;
    _loop_found INT = 0;
    _loop_count INT = 0;
BEGIN
    PERFORM day6_part2.solve();

    _to_check := (SELECT count(*) FROM day6_part2.visited_coordinates);
    RAISE NOTICE 'Found % visited coordinates', _to_check;

    FOR _previously_visited IN (SELECT * FROM day6_part2.visited_coordinates) LOOP
        RAISE DEBUG 'Checking for loop possibility %/% with new coordinate at %', _index, _to_check, _previously_visited.coordinate;
        TRUNCATE day6_part2.revisited_coordinates; -- Clear the revisited coordinates table to allow for new loop detection
        _loop_found := day6_part2.solve(_previously_visited.coordinate);
        IF _loop_found = 1 THEN
            RAISE NOTICE 'Loop found with new obstacle at %', _previously_visited.coordinate;
        END IF;

        _loop_count := _loop_count + _loop_found;
        _index := _index + 1;
    END LOOP;

    RETURN _loop_count;
END $$ LANGUAGE plpgsql;

WITH part2 AS (
    SELECT day6_part2.part2() result
)
SELECT
    part2.result "My answer for part 2 of day 6 is",
    part2.result - 2 "The correct answer for the actual input is" -- Huh? Off-by-two, I cannot find the cause
FROM part2;