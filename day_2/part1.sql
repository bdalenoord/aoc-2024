-- Create a clean schema with a table for the raw input and import the data
DROP SCHEMA IF EXISTS day2_part1 CASCADE;
CREATE SCHEMA day2_part1;
CREATE TABLE day2_part1.input (data TEXT);

COPY day2_part1.input FROM '/days/day_2/input.txt';

DROP TYPE IF EXISTS day2_part1.direction;
CREATE TYPE day2_part1.direction AS ENUM ('INCREASE', 'DECREASE');

CREATE OR REPLACE FUNCTION is_safe(report TEXT) RETURNS BOOLEAN AS $$
DECLARE
    _levels TEXT[];
    _level TEXT;
    _next_level TEXT;
    _index INT = 0;
    _diff INT;
    _direction day2_part1.direction;
    _min_increase INT = 1;
    _max_increase INT = 3;
BEGIN
    RAISE NOTICE 'Processing report %', report;

    _levels := string_to_array(report, ' ');

    FOR _index in 1..cardinality(_levels) LOOP
        _level := _levels[_index];
        _next_level := _levels[_index + 1];

        IF _next_level IS NULL THEN
            EXIT;
        END IF;

        _diff = _level::INT - _next_level::INT;

        IF _direction IS NULL THEN
            IF _diff < 0 THEN
                _direction := 'DECREASE';
            ELSEIF _diff > 0 THEN
                _direction := 'INCREASE';
            END IF;
        END IF;
        IF _direction = 'DECREASE' AND _diff > 0 THEN
            RAISE DEBUG 'Report % is not safe due to switching direction from decrease to increase', report;
            RETURN FALSE;
        END IF;
        IF _direction = 'INCREASE' AND _diff < 0 THEN
            RAISE DEBUG 'Report % is not safe due to switching direction from increase to decrease', report;
            RETURN FALSE;
        END IF;

        IF abs(_diff) < _min_increase OR abs(_diff) > _max_increase THEN
            RAISE DEBUG 'Report % is not safe due to exceeding the limits with diff of %', report, abs(_diff);
            RETURN FALSE;
        END IF;
    END LOOP;

    RAISE NOTICE 'Report % is safe', report;
    RETURN TRUE;
END $$ LANGUAGE plpgsql;

SELECT
    count(*) "The answer for part 1 of day 2 is"
FROM
    day2_part1.input
WHERE
    is_safe(data);
;