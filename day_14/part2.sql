-- Create a clean schema with a table for the raw input and import the data
DROP SCHEMA IF EXISTS day14_part2 CASCADE;
CREATE SCHEMA day14_part2;
CREATE TABLE day14_part2.input (data TEXT);
COPY day14_part2.input FROM '/days/day_14/input.txt';

CREATE MATERIALIZED VIEW day14_part2.settings AS
    SELECT
        101 AS width,
        103 AS height
;

CREATE TYPE day14_part2.robot AS (
    position_x INT,
    position_y INT,
    velocity_x INT,
    velocity_y INT
);
CREATE OR REPLACE FUNCTION day14_part2.parse_robot(_data TEXT) RETURNS day14_part2.robot AS $$
DECLARE
    _matches TEXT[];
BEGIN
    _matches := (SELECT ARRAY(SELECT UNNEST(regexp_matches(_data, '(-?\d+)', 'g'))));
    RETURN (_matches[1]::INT, _matches[2]::INT, _matches[3]::INT, _matches[4]::INT)::day14_part2.robot;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day14_part2.calculate_position_of_robot(_robot day14_part2.robot, _duration_in_seconds INT) RETURNS day14_part2.robot AS $$
DECLARE
    _width INT;
    _height INT;
    _new_x INT;
    _new_y INT;
BEGIN
    SELECT width, height INTO _width, _height FROM day14_part2.settings;

    RAISE DEBUG 'Width: %, Height: %', _width, _height;

    _new_x := ((_robot.position_x + _robot.velocity_x * _duration_in_seconds) % _width + _width) % _width;
    _new_y := ((_robot.position_y + _robot.velocity_y * _duration_in_seconds) % _height + _height) % _height;

    RAISE DEBUG 'From %, % to %, % with velocity %,%', _robot.position_x, _robot.position_y, _new_x, _new_y, _robot.velocity_x, _robot.velocity_y;

    RETURN (_new_x, _new_y, _robot.velocity_x, _robot.velocity_y)::day14_part2.robot;
END $$ LANGUAGE plpgsql;

CREATE TABLE day14_part2.robot_positions (
    x INT,
    y INT,
    CONSTRAINT robot_positions_pkey PRIMARY KEY (x, y)
);

CREATE OR REPLACE FUNCTION day14_part2.find_overlap(_elapsed_time INT) RETURNS INT AS $$
DECLARE
    _robot_line TEXT;
    _robot day14_part2.robot;
    _updated_robot day14_part2.robot;
    _total INT;
    _distinct INT;
BEGIN
    TRUNCATE day14_part2.robot_positions;

    FOR _robot_line IN (SELECT data FROM day14_part2.input) LOOP
        _robot := day14_part2.parse_robot(_robot_line);
        RAISE DEBUG '% parsed to: %', _robot_line, _robot;
        _updated_robot := day14_part2.calculate_position_of_robot(_robot, _elapsed_time);

        INSERT INTO day14_part2.robot_positions VALUES (_updated_robot.position_x, _updated_robot.position_y) ON CONFLICT DO NOTHING;
    END LOOP;

    SELECT count(*) INTO _total FROM day14_part2.input;
    SELECT count(*) INTO _distinct FROM day14_part2.robot_positions;

    RAISE DEBUG 'Total: %, Distinct: % at time %', _total, _distinct, _elapsed_time;

    RETURN _total - _distinct;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day14_part2.part2() RETURNS INT AS $$
DECLARE
    _elapsed_time INT = 0;
BEGIN
    WHILE day14_part2.find_overlap(_elapsed_time) > 0 LOOP
        _elapsed_time := _elapsed_time + 1;
    END LOOP;
    RETURN _elapsed_time;
END $$ LANGUAGE plpgsql;

SELECT day14_part2.part2() AS "The answer to part 2 of day 14 is";