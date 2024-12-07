-- Create a clean schema with a table for the raw input and import the data
DROP SCHEMA IF EXISTS day7_part2 CASCADE;
CREATE SCHEMA day7_part2;
CREATE TABLE day7_part2.input (data TEXT);
COPY day7_part2.input FROM '/days/day_7/input.txt';

CREATE VIEW day7_part2.split AS SELECT regexp_split_to_array(REPLACE(data, ':', ''), ' ') FROM day7_part2.input;

CREATE OR REPLACE FUNCTION day7_part2.check(
    _expected_result BIGINT,
    _values BIGINT[],
    _current_value BIGINT,
    _position BIGINT
) RETURNS BOOLEAN AS $$
DECLARE
    _new_number BIGINT;
BEGIN
    RAISE DEBUG 'Position % for length %', _position, array_length(_values, 1);

    RAISE DEBUG 'Expected result % from values % has % with position %', _expected_result, _values, _current_value, _position;

    IF _current_value = _expected_result AND (_position - 1) = array_length(_values, 1) THEN
        RAISE DEBUG 'Found a valid equation for result % from values % has % with position %', _expected_result, _values, _current_value, _position;
        RETURN TRUE;
    END IF;
    IF _current_value > _expected_result OR _position > array_length(_values, 1) THEN
        RETURN FALSE;
    END IF;

    _new_number = _values[_position];

    IF day7_part2.check(_expected_result, _values, _current_value + _new_number, _position + 1) THEN
        RETURN TRUE;
    ELSEIF day7_part2.check(_expected_result, _values, _current_value * _new_number, _position + 1) THEN
        RETURN TRUE;
    ELSEIF day7_part2.check(_expected_result, _values, (_current_value::text || _new_number::text)::BIGINT, _position + 1) THEN
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day7_part2.is_valid(_equation TEXT[]) RETURNS BOOLEAN AS $$
DECLARE
    _result BIGINT;
    _inputs BIGINT[];
BEGIN
    _result := _equation[1]::BIGINT;
    _inputs := _equation[2:array_length(_equation, 1)]::BIGINT[];

    RAISE DEBUG 'Result: %', _result;
    RAISE DEBUG 'Inputs: %', _inputs;

    RETURN day7_part2.check(_result, _inputs, _inputs[1], 2);
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day7_part2.part1() RETURNS BIGINT AS $$
DECLARE
    _equation TEXT[];
    _result BIGINT = 0;
    _valid_equation_count BIGINT = 0;
BEGIN
    FOR _equation IN SELECT * FROM day7_part2.split LOOP
        IF day7_part2.is_valid(_equation) THEN
            _result := _result + _equation[1]::BIGINT;
            _valid_equation_count = _valid_equation_count + 1;
        END IF;
    END LOOP;

    RETURN _result;
END $$ LANGUAGE plpgsql;

SELECT day7_part2.part1() "The answer for part 1 of day 7 is";