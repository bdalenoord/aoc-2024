-- Create a clean schema with a table for the raw input and import the data
DROP SCHEMA IF EXISTS day3_part2 CASCADE;
CREATE SCHEMA day3_part2;
CREATE TABLE day3_part2.input (data TEXT);

COPY day3_part2.input FROM '/days/day_3/input.txt';

CREATE VIEW day3_part2.one_long_string AS SELECT string_agg(data, '') AS data FROM day3_part2.input;

CREATE OR REPLACE FUNCTION part2() RETURNS INT AS $$
DECLARE
    _enabled BOOLEAN = true;
    _result INT = 0;
    _match TEXT[];
BEGIN
    FOR _match IN (SELECT regexp_matches(data, '(do)\(\)|(don''t)\(\)|mul\((\d+),(\d+)\)', 'gm') match FROM day3_part2.one_long_string) LOOP
        IF _match[1] IS NOT NULL THEN
            _enabled = true;
            continue;
        END IF;

        IF _match[2] IS NOT NULL THEN
            _enabled = false;
            continue;
        END IF;

        IF _enabled THEN
            _result = _result + _match[3]::INT * _match[4]::INT;
        END IF;
    END LOOP;

    RETURN _result;
END $$ LANGUAGE plpgsql;

SELECT part2() "The answer for part 2 of day 3 is";