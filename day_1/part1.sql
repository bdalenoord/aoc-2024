-- Create a clean schema with a table for the raw input and import the data
CREATE SCHEMA day1_part1;
CREATE TABLE day1_part1.input (data TEXT);
COPY day1_part1.input FROM '/days/day_1/input.txt';

-- Split the left and right columns into separate tables
CREATE TABLE day1_part1.left_input (data INT);
CREATE TABLE day1_part1.right_input (data INT);
DO $$
DECLARE
    row RECORD;
BEGIN
    FOR row IN SELECT * FROM day1_part1.input LOOP
        INSERT INTO day1_part1.left_input (data) VALUES (split_part(row.data, '  ', 1)::INT);
        INSERT INTO day1_part1.right_input (data) VALUES (split_part(row.data, '  ', 2)::INT);
    END LOOP;
END $$;

-- Create the sorted structures
CREATE VIEW day1_part1.left_input_sorted AS SELECT * FROM day1_part1.left_input ORDER BY data;
CREATE VIEW day1_part1.right_input_sorted AS SELECT * FROM day1_part1.right_input ORDER BY data;

-- Create a view to join the two tables and calculate the difference
CREATE VIEW day1_part1.differences AS WITH
    left_with_rownumber AS (
        SELECT *, ROW_NUMBER() OVER () AS rn
        FROM day1_part1.left_input_sorted
    ),
     right_with_rownumber AS (
         SELECT *, ROW_NUMBER() OVER () AS rn
         FROM day1_part1.right_input_sorted
     )
SELECT
    abs(l.data - r.data) AS diff
FROM left_with_rownumber l
JOIN right_with_rownumber r ON l.rn = r.rn;

-- Calculate the sum of the differences
SELECT sum(diff) "The answer for part 1 of day 1 is" FROM day1_part1.differences;