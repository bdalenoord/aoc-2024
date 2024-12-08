-- Create a clean schema with a table for the raw input and import the data
DROP SCHEMA IF EXISTS day8_part2 CASCADE;
CREATE SCHEMA day8_part2;
CREATE TABLE day8_part2.input (data TEXT);
COPY day8_part2.input FROM '/days/day_8/input.txt';

CREATE MATERIALIZED VIEW day8_part2.dimensions AS (
    SELECT
        MAX(LENGTH(data)) AS width,
        COUNT(*) AS height
    FROM day8_part2.input
);

-- Antenna discovery
CREATE TABLE day8_part2.antennas (
    id BIGSERIAL PRIMARY KEY,
    x INT,
    y INT,
    type TEXT
);
CREATE INDEX ON day8_part2.antennas(id);
CREATE OR REPLACE FUNCTION day8_part2.find_antennas() RETURNS VOID AS $$
DECLARE
    _line TEXT;
    _char TEXT;
    _x INT = 1;
    _y INT = 0;
BEGIN
    FOR _line IN (SELECT * FROM day8_part2.input) LOOP
        _y := _y + 1;

        FOR _x IN 1..LENGTH(_line) LOOP
            _char := SUBSTRING(_line FROM _x FOR 1);

            IF _char = '.' THEN
                CONTINUE;
            END IF;

            INSERT INTO day8_part2.antennas (x, y, type) VALUES (
                _x, _y, _char
            );
        END LOOP;
    END LOOP;
END $$ LANGUAGE plpgsql;

-- Antinode discovery
CREATE TYPE day8_part2.coordinate AS(
    _x INT,
    _y INT
);
CREATE OR REPLACE FUNCTION day8_part2.find_antinodes(_antenna_id BIGINT, _other_antenna_ids BIGINT[]) RETURNS day8_part2.coordinate[] AS $$
DECLARE
    _num_other_antennas INT;
    _antenna day8_part2.coordinate;
    _other_antenna_id BIGINT;
    _other_antenna day8_part2.coordinate;
    _x_distance INT;
    _y_distance INT;
    _antinode day8_part2.coordinate;
    _antinodes day8_part2.coordinate[] = ARRAY[]::day8_part2.coordinate[];
BEGIN
    _num_other_antennas := array_length(_other_antenna_ids, 1);
    IF _num_other_antennas IS NULL THEN
        RETURN ARRAY[]::day8_part2.coordinate[];
    END IF;

    _antenna := (SELECT (x, y)::day8_part2.coordinate FROM day8_part2.antennas WHERE id = _antenna_id);

    FOREACH _other_antenna_id IN ARRAY _other_antenna_ids LOOP
        _other_antenna := (SELECT (x, y)::day8_part2.coordinate FROM day8_part2.antennas WHERE id = _other_antenna_id);

        _x_distance := _other_antenna._x - _antenna._x;
        _y_distance := _other_antenna._y - _antenna._y;

        -- Finish each line indefinitely in both directions, whilst still in bounds
        _antinode := (_antenna._x, _antenna._y)::day8_part2.coordinate;
        WHILE (day8_part2.is_within_bounds(_antinode)) LOOP
            _antinodes := _antinodes || _antinode;
            _antinode := (_antinode._x + _x_distance, _antinode._y + _y_distance)::day8_part2.coordinate;
        END LOOP;
        _antinode := (_antenna._x, _antenna._y)::day8_part2.coordinate;
        WHILE (day8_part2.is_within_bounds(_antinode)) LOOP
            _antinodes := _antinodes || _antinode;
            _antinode := (_antinode._x - _x_distance, _antinode._y - _y_distance)::day8_part2.coordinate;
        END LOOP;
    END LOOP;

    RETURN _antinodes || day8_part2.find_antinodes(_other_antenna_ids[1], _other_antenna_ids[2:]);
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day8_part2.is_within_bounds(_coordinate day8_part2.coordinate) RETURNS BOOLEAN AS $$
BEGIN
    RETURN _coordinate._x > 0 AND _coordinate._x <= (SELECT width FROM day8_part2.dimensions)
        AND _coordinate._y > 0 AND _coordinate._y <= (SELECT height FROM day8_part2.dimensions);
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day8_part2.find_antinodes_for_antennas(_antenna_ids BIGINT[]) RETURNS day8_part2.coordinate[] AS $$
DECLARE
    _antinodes day8_part2.coordinate[];
    _antinode day8_part2.coordinate;
    _result day8_part2.coordinate[] = ARRAY[]::day8_part2.coordinate[];
BEGIN
    _antinodes := day8_part2.find_antinodes(_antenna_ids[1], _antenna_ids[2:]);

    FOREACH _antinode IN ARRAY _antinodes LOOP
        IF day8_part2.is_within_bounds(_antinode) THEN
            RAISE DEBUG 'Antinode % is within bounds', _antinode;
            _result := _result || _antinode;
        ELSE
            RAISE DEBUG 'Antinode % is out of bounds', _antinode;
        END IF;
    END LOOP;

    RETURN _result;
END $$ LANGUAGE plpgsql;

-- Perform the solution
CREATE TABLE day8_part2.discovered_antinodes (
    coordinate day8_part2.coordinate PRIMARY KEY
);
CREATE OR REPLACE FUNCTION day8_part2.part1() RETURNS BIGINT AS $$
DECLARE
    _grouped_antennas BIGINT[];
    _valid_antinode day8_part2.coordinate;
BEGIN
    PERFORM day8_part2.find_antennas();

    FOR _grouped_antennas IN SELECT array_agg(id) FROM day8_part2.antennas GROUP BY type LOOP
        FOREACH _valid_antinode IN ARRAY day8_part2.find_antinodes_for_antennas(_grouped_antennas) LOOP
            INSERT INTO day8_part2.discovered_antinodes (coordinate) VALUES (_valid_antinode) ON CONFLICT DO NOTHING;
        END LOOP;
    END LOOP;

    RETURN (SELECT count(*) FROM day8_part2.discovered_antinodes);
END $$ LANGUAGE plpgsql;

SELECT day8_part2.part1() "The solution for part 1 of day 8 is";