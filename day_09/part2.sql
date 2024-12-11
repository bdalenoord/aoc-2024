-- Create a clean schema with a table for the raw input and import the data
DROP SCHEMA IF EXISTS day9_part2 CASCADE;
CREATE SCHEMA day9_part2;
CREATE TABLE day9_part2.input (data TEXT);
COPY day9_part2.input FROM '/days/day_9/input.txt';

CREATE TYPE day9_part2.mode AS ENUM ('FILE', 'FREE');

CREATE SEQUENCE day9_part2.file_id_seq START 1;

CREATE SEQUENCE day9_part2.block_order_seq START 1;
CREATE TABLE day9_part2.blocks (
    id BIGSERIAL PRIMARY KEY,
    initial_order BIGINT NOT NULL DEFAULT nextval('day9_part2.block_order_seq'),
    sub_order INT NOT NULL DEFAULT 999999999,
    length INT,
    value TEXT
);

CREATE OR REPLACE FUNCTION day9_part2.get_expanded_diskmap(_diskmap TEXT) RETURNS VOID AS $$
DECLARE
    _char TEXT;
    _idx INT = 1;
    _file_idx INT = 0;
    _mode day9_part2.mode = 'FILE';
BEGIN
    RAISE NOTICE 'Expanding diskmap';

    WHILE _idx <= LENGTH(_diskmap) LOOP
        _char := SUBSTRING(_diskmap FROM _idx FOR 1);

        INSERT INTO day9_part2.blocks (length, value)
        VALUES (
                CAST(_char AS INT),
                CASE WHEN _mode = 'FILE' THEN (nextval('day9_part2.file_id_seq') - 1)::TEXT ELSE '.' END
        );

        IF _mode = 'FILE' THEN
            _file_idx := _file_idx + 1;
            _mode := 'FREE';
        ELSE
            _mode := 'FILE';
        END IF;
        _idx := _idx + 1;
    END LOOP;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day9_part2.defrag() RETURNS VOID AS $$
DECLARE
    _block_value INT = currval('day9_part2.file_id_seq') - 1;
    _sub_order INT = 1;
    _current_block day9_part2.blocks;
    _freespace day9_part2.blocks;
BEGIN
    RAISE NOTICE 'Defragging diskmap';

    WHILE _block_value > 0 LOOP
        SELECT * INTO _current_block FROM day9_part2.blocks WHERE value = ''||_block_value;

        RAISE DEBUG 'Current block being defragged: %', _current_block;

        -- Find the first free space that fits the current block
        SELECT * INTO _freespace FROM day9_part2.blocks WHERE value = '.' AND length >= _current_block.length ORDER BY initial_order LIMIT 1;
        IF _freespace IS NULL THEN
            RAISE DEBUG 'Block % does not fit anywhere', _current_block;
            _block_value := _block_value - 1;
            CONTINUE;
        END IF;

        -- Check whether the found free-space is before the block, as blocks don't need to be pushed backwards
        IF _freespace.initial_order >= _current_block.initial_order THEN
            RAISE DEBUG 'Block % is before free space, no moving needed', _current_block;
            _block_value := _block_value - 1;
            CONTINUE;
        END IF;

        RAISE DEBUG 'Current block % would fit in %', _current_block, _freespace;
        -- Remove or reduce the free space
        IF _freespace.length - _current_block.length = 0 THEN
            DELETE FROM day9_part2.blocks WHERE id = _freespace.id;
        ELSE
            UPDATE day9_part2.blocks SET length = length - _current_block.length WHERE id = _freespace.id;
        END IF;

        -- Store the moved block
        INSERT INTO day9_part2.blocks (initial_order, sub_order, length, value)
        VALUES (_freespace.initial_order, _sub_order, _current_block.length, ''||_block_value);

        -- Determine whether the block that was moved had free space before it, and if so, merge the new free space with
        -- the previous block. If not, make the block that was moved free space now
        SELECT * INTO _freespace FROM day9_part2.blocks WHERE value = '.' AND initial_order = _current_block.initial_order - 1;
        IF _freespace IS NOT NULL THEN
            -- Merge the new free space with the previous block, as it now allows for a larger block
            UPDATE day9_part2.blocks SET length = length + _current_block.length WHERE id = _freespace.id;
            DELETE FROM day9_part2.blocks WHERE id = _current_block.id;
        ELSE
            -- Make the block that was moved free space now
            UPDATE day9_part2.blocks SET value = '.' WHERE id = _current_block.id;
        end if;

        RAISE DEBUG E'Diskmap whilst defragging:\t%', ARRAY_TO_STRING(ARRAY(SELECT repeat(value, length) FROM day9_part2.blocks ORDER BY initial_order, sub_order), '');

        _sub_order := _sub_order + 1;
        _block_value := _block_value - 1;
    END LOOP;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day9_part2.calculate_checksum() RETURNS BIGINT AS $$
DECLARE
    _block day9_part2.blocks;
    _defragged_diskmap TEXT[];
    _idx INT = 1;
    _char TEXT;
    _result BIGINT = 0;
BEGIN
    -- Reconstruct the entire diskmap from the table before looping over it to calculate the checksum
    FOR _block IN (SELECT * FROM day9_part2.blocks ORDER BY initial_order, sub_order) LOOP
        FOR _ IN 1.._block.length LOOP
            _defragged_diskmap := _defragged_diskmap || ARRAY[_block.value];
        END LOOP;
    END LOOP;

    WHILE _idx <= ARRAY_LENGTH(_defragged_diskmap, 1) LOOP
        _char := _defragged_diskmap[_idx];

        IF _char = '.' THEN
            _idx := _idx + 1;
            CONTINUE;
        END IF;

        _result := _result + (CAST(_char AS INT) * (_idx - 1));

        _idx := _idx + 1;
    END LOOP;

    RETURN _result;
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day9_part2.part2() RETURNS BIGINT AS $$
DECLARE
    _line TEXT;
    _checksum BIGINT = 0;
BEGIN
    SELECT * INTO _line FROM day9_part2.input LIMIT 1;
    RAISE NOTICE E'Original diskmap:\t%', _line;

    PERFORM day9_part2.get_expanded_diskmap(_line);
    RAISE DEBUG E'Expanded diskmap:\t%', ARRAY_TO_STRING(ARRAY(SELECT repeat(value, length) FROM day9_part2.blocks ORDER BY initial_order, sub_order), '');

    PERFORM day9_part2.defrag();
    RAISE DEBUG E'Defragged diskmap:\t%', ARRAY_TO_STRING(ARRAY(SELECT repeat(value, length) FROM day9_part2.blocks ORDER BY initial_order, sub_order), '');

    _checksum := day9_part2.calculate_checksum();

    RETURN _checksum;
END $$ LANGUAGE plpgsql;

SELECT day9_part2.part2() "The answer for part 2 of day 9 is";