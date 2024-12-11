-- Create a clean schema with a table for the raw input and import the data
DROP SCHEMA IF EXISTS day9_part1 CASCADE;
CREATE SCHEMA day9_part1;
CREATE TABLE day9_part1.input (data TEXT);
COPY day9_part1.input FROM '/days/day_9/input.txt';

CREATE TYPE day9_part1.mode AS ENUM ('FILE', 'FREE');

CREATE OR REPLACE FUNCTION day9_part1.get_expanded_diskmap(_diskmap TEXT) RETURNS TEXT[] AS $$
DECLARE
    _expanded_diskmap TEXT[] = ARRAY[]::TEXT[];
    _char TEXT;
    _idx INT = 1;
    _file_idx INT = 0;
    _mode day9_part1.mode = 'FILE';
BEGIN
    RAISE NOTICE 'Expanding diskmap';

    WHILE _idx <= LENGTH(_diskmap) LOOP
        _char := SUBSTRING(_diskmap FROM _idx FOR 1);

        FOR _ IN 1..CAST(_char AS INT) LOOP
            IF _mode = 'FILE' THEN
                _expanded_diskmap := _expanded_diskmap || ARRAY['' || _file_idx];
            ELSE
                _expanded_diskmap := _expanded_diskmap || ARRAY['.'];
            END IF;
        END LOOP;

        IF _mode = 'FILE' THEN
            _file_idx := _file_idx + 1;
            _mode := 'FREE';
        ELSE
            _mode := 'FILE';
        END IF;
        _idx := _idx + 1;
    END LOOP;

    RETURN _expanded_diskmap;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day9_part1.defrag(_expanded_diskmap TEXT[]) RETURNS TEXT[] AS $$
DECLARE
    _length INT = ARRAY_LENGTH(_expanded_diskmap, 1);
    _front_idx INT = ARRAY_POSITION(_expanded_diskmap, '.');
    _rear_idx INT = _length;
    _char TEXT;
    _defragged_diskmap TEXT[] = _expanded_diskmap;
BEGIN
    RAISE NOTICE 'Defragging diskmap';

    WHILE _front_idx < _rear_idx LOOP
        _char = _defragged_diskmap[_rear_idx];

        IF _char = '.' THEN
            _rear_idx := _rear_idx - 1;
            CONTINUE;
        END IF;

        _defragged_diskmap[_front_idx] := _char;
        _defragged_diskmap[_rear_idx] := '.';
        _front_idx := ARRAY_POSITION(_expanded_diskmap, '.', _front_idx + 1);
        _rear_idx := _rear_idx - 1;
    END LOOP;

    RETURN _defragged_diskmap;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day9_part1.calculate_checksum(_defragged_diskmap TEXT[]) RETURNS BIGINT AS $$
DECLARE
    _idx INT = 1;
    _char TEXT;
    _result BIGINT = 0;
BEGIN
    WHILE _idx <= ARRAY_LENGTH(_defragged_diskmap, 1) LOOP
        _char := _defragged_diskmap[_idx];

        IF _char = '.' THEN
            EXIT;
        END IF;

        _result := _result + (CAST(_char AS INT) * (_idx - 1));

        _idx := _idx + 1;
    END LOOP;

    RETURN _result;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day9_part1.part1() RETURNS BIGINT AS $$
DECLARE
    _line TEXT;
    _expanded_line TEXT[] = ARRAY[]::TEXT[];
    _defragged_line TEXT[] = ARRAY[]::TEXT[];
    _checksum BIGINT = 0;
BEGIN
    SELECT * INTO _line FROM day9_part1.input LIMIT 1;
    _expanded_line := day9_part1.get_expanded_diskmap(_line);
    _defragged_line := day9_part1.defrag(_expanded_line);
    _checksum := day9_part1.calculate_checksum(_defragged_line);

    RAISE DEBUG E'Original diskmap:\t%', _line;
    RAISE DEBUG E'Expanded diskmap:\t%', ARRAY_TO_STRING(_expanded_line, '');
    RAISE DEBUG E'Defragged diskmap:\t%', ARRAY_TO_STRING(_defragged_line, '');
    RAISE DEBUG E'Resulting checksum:\t%', _checksum;

    RETURN _checksum;
END $$ LANGUAGE plpgsql;

SELECT day9_part1.part1() "The answer for part 1 of day 9 is";