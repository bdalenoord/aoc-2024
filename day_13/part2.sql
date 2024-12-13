-- Create a clean schema with a table for the raw input and import the data
DROP SCHEMA IF EXISTS day13_part2 CASCADE;
CREATE SCHEMA day13_part2;
CREATE TABLE day13_part2.input (data TEXT);
COPY day13_part2.input FROM '/days/day_13/input.txt';

CREATE MATERIALIZED VIEW day13_part2.one_long_string AS SELECT string_agg(data, '\n') AS data FROM day13_part2.input;

CREATE TYPE day13_part2.button AS (
    x BIGINT,
    y BIGINT
);

CREATE TYPE day13_part2.paragraph AS (
    button_a day13_part2.button,
    button_b day13_part2.button,
    x BIGINT,
    y BIGINT
);

CREATE OR REPLACE FUNCTION day13_part2.part1() RETURNS BIGINT AS $$
DECLARE
    _paragraph_lines TEXT;
    _matches TEXT[];
    _paragraphs day13_part2.paragraph[];
    _paragraph day13_part2.paragraph;
    _button_a day13_part2.button;
    _button_b day13_part2.button;
    _a BIGINT;
    _b BIGINT;
    _result BIGINT = 0;
BEGIN
    FOR _paragraph_lines IN (SELECT regexp_split_to_table(data, '\\n\\n') paragraphs FROM day13_part2.one_long_string) LOOP
        _matches := (SELECT ARRAY(SELECT regexp_matches(_paragraph_lines, '(\d+)', 'g')));

        _paragraphs := _paragraphs || ARRAY[(
            (_matches[1][1]::BIGINT, _matches[2][1]::BIGINT)::day13_part2.button,
            (_matches[3][1]::BIGINT, _matches[4][1]::BIGINT)::day13_part2.button,
            _matches[5][1]::BIGINT + 10000000000000::BIGINT,
            _matches[6][1]::BIGINT + 10000000000000::BIGINT
        )::day13_part2.paragraph];
    END LOOP;

    FOREACH _paragraph IN ARRAY _paragraphs LOOP
        _button_a := _paragraph.button_a;
        _button_b := _paragraph.button_b;
        _b := ((_paragraph.y * _button_a.x) - (_paragraph.x * _button_a.y)) / ((0 - _button_a.y)*_button_b.x + _button_b.y*_button_a.x);
        _a = (_paragraph.x - _button_b.x * _b) / _button_a.x;
--         IF _a > 100 OR _b > 100 THEN
--             RAISE NOTICE 'Skipping %', _paragraph;
--             CONTINUE;
--         END IF;

        IF _a * _button_a.x + _b * _button_b.x = _paragraph.x AND _a * _button_a.y + _b * _button_b.y = _paragraph.y THEN
            _result := _result + (_a * 3) + _b;
        END IF;
    END LOOP;

    RETURN _result;
END $$ LANGUAGE plpgsql;

SELECT day13_part2.part1() "The answer for part 1 of day 13 is";