-- Create a clean schema with a table for the raw input and import the data
DROP SCHEMA IF EXISTS day4_part1 CASCADE;
CREATE SCHEMA day4_part1;
CREATE TABLE day4_part1.input (data TEXT);

COPY day4_part1.input FROM '/days/day_4/input.txt';

CREATE TYPE day4_part1.coordinate AS (x INT, y INT);

CREATE OR REPLACE FUNCTION read_in_direction(
    _direction day4_part1.coordinate,
    _prev_rows TEXT[],
    _current_row TEXT,
    _next_rows TEXT[],
    _x INT
) RETURNS TEXT AS $$
DECLARE
    _result TEXT = '';
    _rows TEXT[] = _prev_rows || ARRAY[_current_row] || _next_rows;
    _y INT = COALESCE(ARRAY_LENGTH(_prev_rows, 1), 0) + 1;
    _index INT = 0;
    _next_x INT;
    _next_y INT;
    _char CHAR;
BEGIN
    RAISE DEBUG E'Rows in view whilst reading from %,% with direction %:\n%', _x, _y, _direction, ARRAY_TO_STRING(_rows, E'\n');

    FOR _index IN 1..4 LOOP
        _next_x := _x + ((_index - 1) * _direction.x);
        _next_y := _y + ((_index - 1) * _direction.y);

        _char := COALESCE(substring(_rows[_next_y] FROM _next_x FOR 1), '');

        RAISE DEBUG E'% Read % from %,% after starting from %,%', _index, _char, _next_x, _next_y, _x, _y;
        _result := _result || COALESCE(substring(_rows[_next_y] FROM _next_x FOR 1), '');
    END LOOP;

    RAISE DEBUG 'Result: %', _result;

    RETURN _result;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION part1() RETURNS INT AS $$
DECLARE
    _result INT = 0;
    _row_count INT;
    _row_index INT = 0;
    _prev_rows TEXT[];
    _current_row TEXT;
    _next_rows TEXT[];
    _char_index INT;
    _current_char CHAR;
    _directions day4_part1.coordinate[] = ARRAY[(0, 1), (0, -1), (-1, 0), (1, 0), (1, 1), (-1, -1), (1, -1), (-1, 1)];
    _direction day4_part1.coordinate;
BEGIN
    SELECT count(*) INTO _row_count FROM day4_part1.input;

    FOR _row_index IN 0.._row_count - 1 LOOP
        -- Get the previous, current, and next rows
        SELECT ARRAY(SELECT data FROM day4_part1.input LIMIT LEAST(3, _row_index) OFFSET GREATEST(_row_index - 3, 0)) into _prev_rows;
        SELECT data INTO _current_row FROM day4_part1.input LIMIT 1 OFFSET _row_index;
        SELECT ARRAY(SELECT data FROM day4_part1.input LIMIT 3 OFFSET _row_index + 1) INTO _next_rows;

        RAISE DEBUG E'Rows in view: \n|%\n>%\n|%', ARRAY_TO_STRING(_prev_rows, E'\n|'), _current_row, ARRAY_TO_STRING(_next_rows, E'\n|');

        -- Loop through each character in the current row
        FOR _char_index IN 1..length(_current_row) LOOP
            _current_char := substring(_current_row FROM _char_index FOR 1);
            IF _current_char != 'X' THEN
                CONTINUE;
            END IF;

            FOREACH _direction IN ARRAY _directions LOOP
                IF read_in_direction(_direction, _prev_rows, _current_row, _next_rows, _char_index) = 'XMAS' THEN
                    _result := _result + 1;
                END IF;
            END LOOP;
        END LOOP;
    END LOOP;

    RETURN _result;
END
$$ LANGUAGE plpgsql;

SELECT part1() "The answer for part 1 of day 4 is";