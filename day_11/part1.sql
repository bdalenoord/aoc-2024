-- Create a clean schema with a table for the raw input and import the data
DROP SCHEMA IF EXISTS day11_part1 CASCADE;
CREATE SCHEMA day11_part1;
CREATE TABLE day11_part1.input (data TEXT);
COPY day11_part1.input FROM '/days/day_11/input.txt';

CREATE OR REPLACE FUNCTION day11_part1.part1() RETURNS BIGINT AS $$
DECLARE
    _stone BIGINT;
    _stones BIGINT[];
    _new_stones BIGINT[];
    _blink BIGINT;
    _max_blinks BIGINT = 25;
BEGIN
    SELECT regexp_split_to_array(data, ' ')::BIGINT[] INTO _stones FROM day11_part1.input;

    RAISE DEBUG E'Initial arrangement:\n%\n', ARRAY_TO_STRING(_stones, ' ');

    FOR _blink IN 1.._max_blinks LOOP
        FOREACH _stone IN ARRAY _stones LOOP
            IF _stone = 0 THEN
                _new_stones = _new_stones || 1;
            ELSEIF mod(LENGTH(''||_stone), 2) = 0 THEN
                _new_stones = _new_stones || (SELECT ARRAY(SELECT (regexp_matches('' || _stone, '\d{'||(LENGTH(''||_stone)/2)||'}', 'g'))[1]))::BIGINT[];
            ELSE
                _new_stones = _new_stones || _stone * 2024;
            END IF;
        END LOOP;

        RAISE DEBUG E'After % blink:\n%\n', _blink, ARRAY_TO_STRING(_new_stones, ' ');

        _stones = _new_stones;
        _new_stones = ARRAY[]::BIGINT[];
    END LOOP;

    RETURN ARRAY_LENGTH(_stones, 1);
END $$ LANGUAGE plpgsql;

SELECT day11_part1.part1() "The answer for part 1 of day 11 is";

