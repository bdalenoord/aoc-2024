-- Create a clean schema with a table for the raw input and import the data
DROP SCHEMA IF EXISTS day10_part2 CASCADE;
CREATE SCHEMA day10_part2;
CREATE TABLE day10_part2.input (data TEXT);
COPY day10_part2.input FROM '/days/day_10/input.txt';

-- Create a table that has a column indicating the `y`-coordinate of the row, so we can easily fetch those
CREATE SEQUENCE day10_part2.row_id_seq;
CREATE TABLE day10_part2.input_with_row_id AS SELECT nextval('day10_part2.row_id_seq') AS row_id, data FROM day10_part2.input;

CREATE MATERIALIZED VIEW day10_part2.dimensions AS (
    SELECT
        MAX(LENGTH(data)) AS width,
        COUNT(*) AS height
    FROM day10_part2.input
);

CREATE TYPE day10_part2.coordinate AS (
    x INT,
    y INT
);

CREATE OR REPLACE FUNCTION day10_part2.find_start_coordinates() RETURNS day10_part2.coordinate[] AS $$
DECLARE
    _line day10_part2.input_with_row_id;
    _char TEXT;
    _x INT = 1;
    _start_coords day10_part2.coordinate[] = ARRAY[]::day10_part2.coordinate[];
BEGIN
    FOR _line IN (SELECT * FROM day10_part2.input_with_row_id) LOOP
        FOR _x IN 1..LENGTH(_line.data) LOOP
            _char := SUBSTRING(_line.data FROM _x FOR 1);

            IF _char = '0' THEN
                _start_coords := _start_coords || ARRAY[(_x, _line.row_id)::day10_part2.coordinate];
            END IF;
        END LOOP;
    END LOOP;
    RETURN _start_coords;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day10_part2.char_at(_coordinate day10_part2.coordinate) RETURNS TEXT AS $$
BEGIN
    RETURN (
        SELECT SUBSTRING(data FROM _coordinate.x FOR 1)
        FROM day10_part2.input_with_row_id
        WHERE row_id = _coordinate.y
    );
END $$ LANGUAGE plpgsql;

CREATE TYPE day10_part2.route AS (
    start day10_part2.coordinate,
    steps day10_part2.coordinate[]
);

CREATE OR REPLACE FUNCTION day10_part2.find_next(_from day10_part2.coordinate, _sought CHAR) RETURNS day10_part2.coordinate[] AS $$
DECLARE
    _possible_nexts day10_part2.coordinate[];
    _next day10_part2.coordinate;
    _nexts day10_part2.coordinate[] = ARRAY[]::day10_part2.coordinate[];
BEGIN
    _possible_nexts := ARRAY[
        (_from.x, _from.y - 1)::day10_part2.coordinate, -- Above
        (_from.x, _from.y + 1)::day10_part2.coordinate, -- Below
        (_from.x - 1, _from.y)::day10_part2.coordinate, -- Left
        (_from.x + 1, _from.y)::day10_part2.coordinate  -- Right
    ];

    FOREACH _next IN ARRAY _possible_nexts LOOP
        IF
            _next.x < 1 OR
            _next.y < 1 OR
            _next.x > (SELECT width FROM day10_part2.dimensions) OR
            _next.y > (SELECT height FROM day10_part2.dimensions)
            THEN
            CONTINUE;
        END IF;

        IF day10_part2.char_at(_next) = _sought THEN
            _nexts := _nexts || ARRAY[_next];
        END IF;
    END LOOP;

    RETURN _nexts;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day10_part2.find_number_of_routes_for_coordinate(_start_coord day10_part2.coordinate) RETURNS INT AS $$
DECLARE
    _i INT = 1;
    _result INT = 0;
    _nexts day10_part2.coordinate[];
    _next day10_part2.coordinate;
    _new_nexts day10_part2.coordinate[];
BEGIN
    _nexts := ARRAY[_start_coord];
    FOR _i IN 1..9 LOOP
        FOREACH _next IN ARRAY _nexts LOOP
            _new_nexts := _new_nexts || day10_part2.find_next(_next, _i::CHAR);
        END LOOP;

        IF ARRAY_LENGTH(_nexts, 1) <= 0 THEN
            EXIT;
        END IF;

        IF _i = 9 THEN
            -- Count only distinct values
            _result := ARRAY_LENGTH(_new_nexts, 1);
            EXIT;
        END IF;

        _nexts := _new_nexts;
        _new_nexts := ARRAY[]::day10_part2.coordinate[];
    END LOOP;

    RETURN _result;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day10_part2.find_number_of_routes_for_coordinates(_start_coords day10_part2.coordinate[]) RETURNS INT AS $$
DECLARE
    _start_coord day10_part2.coordinate;
    _result INT = 0;
BEGIN
    FOREACH _start_coord IN ARRAY _start_coords LOOP
        _result := _result + day10_part2.find_number_of_routes_for_coordinate(_start_coord);
    END LOOP;

    RETURN _result;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day10_part2.part2() RETURNS BIGINT AS $$
DECLARE
    _start_coords day10_part2.coordinate[] = day10_part2.find_start_coordinates();
    _number_of_routes BIGINT = day10_part2.find_number_of_routes_for_coordinates(_start_coords);
BEGIN
--     RAISE NOTICE E'Start coordinates:\n%\n', ARRAY_TO_STRING(_start_coords, E'\n');
    RETURN _number_of_routes;
END $$ LANGUAGE plpgsql;

SELECT day10_part2.part2() "The answer for part 2 of day 10 is";