-- Create a clean schema with a table for the raw input and import the data
DROP SCHEMA IF EXISTS day5_part2 CASCADE;
CREATE SCHEMA day5_part2;
CREATE TABLE day5_part2.input (data TEXT);
COPY day5_part2.input FROM '/days/day_5/input.txt';

-- Split the input into the two parts
CREATE VIEW day5_part2.rules AS SELECT split_part(data, '|', 1) AS first, split_part(data, '|', 2) AS second, data FROM day5_part2.input WHERE data LIKE '%|%';
CREATE VIEW day5_part2.updates AS SELECT * FROM day5_part2.input WHERE data LIKE '%,%';

CREATE OR REPLACE FUNCTION day5_part2.is_in_correct_order(_update TEXT) RETURNS BOOLEAN AS $$
DECLARE
    _parts TEXT[];
    _applicable_rules day5_part2.rules[];
    _applicable_rule day5_part2.rules;
BEGIN
    _parts := regexp_split_to_array(_update, ',');

    FOR _applicable_rule IN SELECT * FROM day5_part2.rules WHERE _update LIKE '%' || first || '%' AND _update LIKE '%' || second || '%' LOOP
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

CREATE OR REPLACE FUNCTION day5_part2.fix_order(_update TEXT) RETURNS TEXT AS $$
DECLARE
    _parts TEXT[];
    _applicable_rules day5_part2.rules[];
    _applicable_rule day5_part2.rules;
BEGIN
    _parts := regexp_split_to_array(_update, ',');

    FOR _applicable_rule IN SELECT * FROM day5_part2.rules WHERE _update LIKE '%' || first || '%' AND _update LIKE '%' || second || '%' LOOP
        _applicable_rules := array_append(_applicable_rules, _applicable_rule);
    END LOOP;

    RAISE DEBUG 'Applicable rules for %: %', _parts, _applicable_rules;

    FOREACH _applicable_rule IN ARRAY _applicable_rules LOOP
        IF array_position(_parts, _applicable_rule.first) < array_position(_parts, _applicable_rule.second) THEN
            CONTINUE; -- If a rule is not broken, no action needs to be performed
        END IF;

        _parts := array_replace(_parts, _applicable_rule.first, 'SWAPPED');
        _parts := array_replace(_parts, _applicable_rule.second, _applicable_rule.first);
        _parts := array_replace(_parts, 'SWAPPED', _applicable_rule.second);

        RETURN day5_part2.fix_order(array_to_string(_parts, ','));
    END LOOP;

    RETURN array_to_string(_parts, ',');
END $$ LANGUAGE plpgsql;

-- Helper to parse the middle o given update
CREATE OR REPLACE FUNCTION day5_part2.middle_update(_update TEXT) RETURNS TEXT AS $$
DECLARE
    _parts TEXT[];
BEGIN
    _parts := regexp_split_to_array(_update, ',');
    return _parts[(array_length(_parts, 1) / 2) + 1];
END $$ LANGUAGE plpgsql;

SELECT
    sum(
            day5_part2.middle_update(
                    day5_part2.fix_order(data)
            )::INT
    ) "The answer for part 2 of day 5 is"
FROM
    day5_part2.updates
WHERE
    day5_part2.is_in_correct_order(data) = false
;
