-- Create a clean schema with a table for the raw input and import the data
DROP SCHEMA IF EXISTS day14_part1 CASCADE;
CREATE SCHEMA day14_part1;
CREATE TABLE day14_part1.input (data TEXT);
COPY day14_part1.input FROM '/days/day_14/input.txt';

CREATE MATERIALIZED VIEW day14_part1.settings AS
    SELECT
        101 AS width,
        103 AS height,
        100 AS duration_in_seconds;
;

CREATE TYPE day14_part1.robot AS (
    position_x INT,
    position_y INT,
    velocity_x INT,
    velocity_y INT
);
CREATE OR REPLACE FUNCTION day14_part1.parse_robot(_data TEXT) RETURNS day14_part1.robot AS $$
DECLARE
    _matches TEXT[];
BEGIN
    _matches := (SELECT ARRAY(SELECT UNNEST(regexp_matches(_data, '(-?\d+)', 'g'))));
    RETURN (_matches[1]::INT, _matches[2]::INT, _matches[3]::INT, _matches[4]::INT)::day14_part1.robot;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day14_part1.calculate_position_of_robot(_robot day14_part1.robot, _duration_in_seconds INT) RETURNS day14_part1.robot AS $$
DECLARE
    _width INT;
    _height INT;
    _new_x INT;
    _new_y INT;
BEGIN
    SELECT width, height INTO _width, _height FROM day14_part1.settings;

    RAISE DEBUG 'Width: %, Height: %', _width, _height;

    _new_x := ((_robot.position_x + _robot.velocity_x * _duration_in_seconds) % _width + _width) % _width;
    _new_y := ((_robot.position_y + _robot.velocity_y * _duration_in_seconds) % _height + _height) % _height;

    RAISE DEBUG 'From %, % to %, % with velocity %,%', _robot.position_x, _robot.position_y, _new_x, _new_y, _robot.velocity_x, _robot.velocity_y;

    RETURN (_new_x, _new_y, _robot.velocity_x, _robot.velocity_y)::day14_part1.robot;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day14_part1.part1() RETURNS BIGINT AS $$
DECLARE
    _width INT;
    _height INT;
    _duration_in_seconds INT;
    _robot_line TEXT;
    _robot day14_part1.robot;
    _updated_robot day14_part1.robot;
    _quadrant_a INT = 0;
    _quadrant_b INT = 0;
    _quadrant_c INT = 0;
    _quadrant_d INT = 0;
BEGIN
    SELECT width, height, duration_in_seconds INTO _width, _height, _duration_in_seconds FROM day14_part1.settings;

    FOR _robot_line IN (SELECT data FROM day14_part1.input) LOOP
        _robot := day14_part1.parse_robot(_robot_line);
        RAISE DEBUG '% parsed to: %', _robot_line, _robot;

        _updated_robot := day14_part1.calculate_position_of_robot(_robot, _duration_in_seconds);

        RAISE DEBUG 'Robot % updated to: %', _robot, _updated_robot;

        IF _updated_robot.position_x < floor(_width / 2) AND _updated_robot.position_y < floor(_height / 2) THEN
            _quadrant_a := _quadrant_a + 1;
        ELSIF _updated_robot.position_x > floor(_width / 2) AND _updated_robot.position_y < floor(_height / 2) THEN
            _quadrant_b := _quadrant_b + 1;
        ELSIF _updated_robot.position_x < floor(_width / 2) AND _updated_robot.position_y > floor(_height / 2) THEN
            _quadrant_c := _quadrant_c + 1;
        ELSIF _updated_robot.position_x > floor(_width / 2) AND _updated_robot.position_y > floor(_height / 2) THEN
            _quadrant_d := _quadrant_d + 1;
        END IF;
    END LOOP;

    RAISE NOTICE 'Quadrant A: %, Quadrant B: %, Quadrant C: %, Quadrant D: %', _quadrant_a, _quadrant_b, _quadrant_c, _quadrant_d;

    RETURN _quadrant_a * _quadrant_b * _quadrant_c * _quadrant_d;
END $$ LANGUAGE plpgsql;

SELECT day14_part1.part1() AS "The answer to part 1 of day 14 is";