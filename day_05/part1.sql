-- Create a clean schema with a table for the raw input and import the data
DROP SCHEMA IF EXISTS day5_part1 CASCADE;
CREATE SCHEMA day5_part1;
CREATE TABLE day5_part1.input (data TEXT);
COPY day5_part1.input FROM '/days/day_5/input.txt';

-- Split the input into the two parts
CREATE VIEW day5_part1.rules AS SELECT split_part(data, '|', 1) AS first, split_part(data, '|', 2) AS second, data FROM day5_part1.input WHERE data LIKE '%|%';
CREATE VIEW day5_part1.updates AS SELECT * FROM day5_part1.input WHERE data LIKE '%,%';

CREATE OR REPLACE FUNCTION day5_part1.is_in_correct_order(_update TEXT) RETURNS BOOLEAN AS $$
DECLARE
    _parts TEXT[];
    _applicable_rules day5_part1.rules[];
    _applicable_rule day5_part1.rules;
BEGIN
    _parts := regexp_split_to_array(_update, ',');

    FOR _applicable_rule IN (SELECT * FROM day5_part1.rules WHERE _update LIKE '%' || first || '%' AND _update LIKE '%' || second || '%') LOOP
        _applicable_rules := array_append(_applicable_rules, _applicable_rule);
    END LOOP;

    RAISE DEBUG 'Applicable rules for %: %', _parts, _applicable_rules;

    FOREACH _applicable_rule IN ARRAY _applicable_rules LOOP
        RAISE DEBUG 'Checking rule %', _applicable_rule;
        IF array_position(_parts, _applicable_rule.first) > array_position(_parts, _applicable_rule.second) THEN
            RETURN FALSE;
        END IF;
    END LOOP;

    RETURN TRUE;
END $$ LANGUAGE plpgsql;

-- Helper to parse the middle o given update
CREATE OR REPLACE FUNCTION day5_part1.middle_update(_update TEXT) RETURNS TEXT AS $$
DECLARE
    _parts TEXT[];
BEGIN
    _parts := regexp_split_to_array(_update, ',');
    return _parts[(array_length(_parts, 1) / 2) + 1];
END $$ LANGUAGE plpgsql;

SELECT
    SUM(day5_part1.middle_update(data)::INT) "The answer for part 1 of day 5 is"
FROM
    day5_part1.updates
WHERE
    day5_part1.is_in_correct_order(data)
;
