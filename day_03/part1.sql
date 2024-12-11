-- Create a clean schema with a table for the raw input and import the data
DROP SCHEMA IF EXISTS day3_part1 CASCADE;
CREATE SCHEMA day3_part1;
CREATE TABLE day3_part1.input (data TEXT);

COPY day3_part1.input FROM '/days/day_3/input.txt';

CREATE VIEW day3_part1.one_long_string AS SELECT string_agg(data, '') AS data FROM day3_part1.input;

WITH multiplications AS (
    SELECT match[1], match[2], match[1]::int * match[2]::int result
    FROM (
        SELECT regexp_matches(data, 'mul\((\d+),(\d+)\)', 'gm') match
        FROM day3_part1.one_long_string
    ) instructions
)
SELECT sum(multiplications.result) "The answer for part 1 of day 3 is" FROM multiplications;