-- Create a clean schema with a table for the raw input and import the data
DROP SCHEMA IF EXISTS day2_part2 CASCADE;
CREATE SCHEMA day2_part2;
CREATE TABLE day2_part2.input (data TEXT);

COPY day2_part2.input FROM '/days/day_2/input.txt';

DROP TYPE IF EXISTS day2_part2.direction;
CREATE TYPE day2_part2.direction AS ENUM ('INCREASE', 'DECREASE');

-- Trivially check whether a report is safe
CREATE OR REPLACE FUNCTION is_safe(report TEXT) RETURNS BOOLEAN AS $$
DECLARE
    _levels TEXT[];
    _level TEXT;
    _next_level TEXT;
    _index INT = 0;
    _diff INT;
    _direction day2_part2.direction;
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

-- For a given report, loop over the levels and check whether it is safe with the dampener applied, which drops a
-- single level at a time
CREATE OR REPLACE FUNCTION is_safe_with_dampener(report TEXT) RETURNS BOOLEAN AS $$
DECLARE
    _levels TEXT[];
    _index INT;
    _current_permutation TEXT[];
BEGIN
    RAISE NOTICE 'Processing report % with dampening', report;

    _levels := string_to_array(report, ' ');

    -- Create a permutation of the levels, dropping a single element a time and checking whether that permutation is safe. if so, return `true`
    FOR _index IN array_lower(_levels, 1)..array_upper(_levels, 1) LOOP
        _current_permutation := _levels[1:_index-1] || _levels[_index+1:array_upper(_levels, 1)];
        IF is_safe(array_to_string(_current_permutation, ' ')) THEN
            RAISE NOTICE 'Report % is safe with dampening, resulting in %', report, array_to_string(_current_permutation, ' ');
            RETURN TRUE;
        END IF;
    END LOOP;

    RETURN FALSE;
END $$ LANGUAGE plpgsql;

SELECT
    count(*) "The answer for part 2 of day 2 is"
FROM
    day2_part2.input
WHERE
    is_safe(data) OR is_safe_with_dampener(data);
;