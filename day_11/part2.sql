-- Create a clean schema with a table for the raw input and import the data
DROP SCHEMA IF EXISTS day11_part2 CASCADE;
CREATE SCHEMA day11_part2;
CREATE TABLE day11_part2.input (data TEXT);
COPY day11_part2.input FROM '/days/day_11/input.txt';

CREATE TABLE day11_part2.cache(
    stone BIGINT,
    iteration INT,
    result BIGINT
);

CREATE INDEX ON day11_part2.cache(stone, iteration);

CREATE OR REPLACE FUNCTION day11_part2.do_cache(_stone BIGINT, _iteration INT, _result BIGINT) RETURNS VOID AS $$
BEGIN
    INSERT INTO day11_part2.cache(stone, iteration, result) VALUES (_stone, _iteration, _result);
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day11_part2.blink(_stone BIGINT, _iterations INT) RETURNS BIGINT AS $$
DECLARE
    _cached day11_part2.cache;
    _result BIGINT;
    _split BIGINT[];
BEGIN
    SELECT * INTO _cached FROM day11_part2.cache WHERE stone = _stone AND iteration = _iterations;
    IF _cached IS NOT NULL THEN
        RETURN _cached.result;
    END IF;

    IF _iterations = 0 THEN
        PERFORM day11_part2.do_cache(_stone, _iterations, 1);
        RETURN 1;
    END IF;

    IF _stone = 0 THEN
        _result := day11_part2.blink(1, _iterations - 1);
        PERFORM day11_part2.do_cache(_stone, _iterations, _result);
        RETURN _result;
    ELSIF mod(LENGTH(''||_stone), 2) = 0 THEN
        _split := (SELECT ARRAY(SELECT (regexp_matches('' || _stone, '\d{'||(LENGTH(''||_stone)/2)||'}', 'g'))[1]))::BIGINT[];
        _result = day11_part2.blink(_split[1], _iterations - 1) + day11_part2.blink(_split[2], _iterations - 1);
        PERFORM day11_part2.do_cache(_stone, _iterations, _result);
        RETURN _result;
    END IF;

    _result := day11_part2.blink(_stone * 2024, _iterations - 1);
    PERFORM day11_part2.do_cache(_stone, _iterations, _result);
    RETURN _result;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day11_part2.part2() RETURNS BIGINT AS $$
DECLARE
    _stone BIGINT;
    _stones BIGINT[];
    _result BIGINT;
    _max_blinks INT = 75;
BEGIN
    SELECT regexp_split_to_array(data, ' ')::BIGINT[] INTO _stones FROM day11_part2.input;

    _result = 0;
    FOREACH _stone IN ARRAY _stones LOOP
        _result := _result + day11_part2.blink(_stone, _max_blinks);
    END LOOP;

    RETURN _result;
END $$ LANGUAGE plpgsql;

SELECT day11_part2.part2() "The answer for part 2 of day 11 is";

