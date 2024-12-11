-- Create a clean schema with a table for the raw input and import the data
DROP SCHEMA IF EXISTS day4_part2 CASCADE;
CREATE SCHEMA day4_part2;
CREATE TABLE day4_part2.input (data TEXT);

COPY day4_part2.input FROM '/days/day_4/input.txt';

CREATE OR REPLACE FUNCTION read_char_at(
    _prev_rows TEXT[],
    _current_row TEXT,
    _next_rows TEXT[],
    _x INT,
    _offset_x INT,
    _offset_y INT
) RETURNS TEXT AS $$
DECLARE
    _rows TEXT[] = _prev_rows || ARRAY[_current_row] || _next_rows;
    _y INT = COALESCE(ARRAY_LENGTH(_prev_rows, 1), 0) + 1;
    _index INT = 0;
    _next_x INT;
    _next_y INT;
BEGIN
    RAISE DEBUG E'Rows in view whilst reading from %,% with offset %,%:\n%', _x, _y, _offset_x, _offset_y, ARRAY_TO_STRING(_rows, E'\n');

    _next_x := _x + ((_index - 1) * _offset_x);
    _next_y := _y + ((_index - 1) * _offset_y);

    RETURN COALESCE(substring(_rows[_next_y] FROM _next_x FOR 1), '');
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION part2() RETURNS INT AS $$
DECLARE
    _result INT = 0;
    _row_count INT;
    _row_index INT = 0;
    _prev_rows TEXT[];
    _current_row TEXT;
    _next_rows TEXT[];
    _char_index INT;
    _current_char CHAR;
    _left_top_to_right_bottom TEXT;
    _right_top_to_left_bottom TEXT;
BEGIN
    SELECT count(*) INTO _row_count FROM day4_part2.input;

    FOR _row_index IN 0.._row_count - 1 LOOP
        -- Get the previous, current, and next rows
        SELECT ARRAY(SELECT data FROM day4_part2.input LIMIT LEAST(3, _row_index) OFFSET GREATEST(_row_index - 3, 0)) into _prev_rows;
        SELECT data INTO _current_row FROM day4_part2.input LIMIT 1 OFFSET _row_index;
        SELECT ARRAY(SELECT data FROM day4_part2.input LIMIT 3 OFFSET _row_index + 1) INTO _next_rows;

        RAISE DEBUG E'Rows in view: \n|%\n>%\n|%', ARRAY_TO_STRING(_prev_rows, E'\n|'), _current_row, ARRAY_TO_STRING(_next_rows, E'\n|');

        -- Loop through each character in the current row
        FOR _char_index IN 1..length(_current_row) LOOP
            _current_char := substring(_current_row FROM _char_index FOR 1);
            IF _current_char != 'A' THEN
                CONTINUE;
            END IF;

            _left_top_to_right_bottom = read_char_at(_prev_rows, _current_row, _next_rows, _char_index, -1,  -1) || _current_char || read_char_at(_prev_rows, _current_row, _next_rows, _char_index, 1, 1);
            _right_top_to_left_bottom = read_char_at(_prev_rows, _current_row, _next_rows, _char_index, 1, -1) || _current_char || read_char_at(_prev_rows, _current_row, _next_rows, _char_index, -1, 1);

            IF (_left_top_to_right_bottom = 'MAS' OR _left_top_to_right_bottom = 'SAM') AND (_right_top_to_left_bottom = 'MAS' OR _right_top_to_left_bottom = 'SAM') THEN
                _result := _result + 1;
            END IF;
        END LOOP;
    END LOOP;

    RETURN _result;
END
$$ LANGUAGE plpgsql;

SELECT part2() "The answer for part 2 of day 4 is";