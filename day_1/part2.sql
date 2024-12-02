-- Create a clean schema with a table for the raw input and import the data
DROP SCHEMA IF EXISTS day1_part2 CASCADE;
CREATE SCHEMA day1_part2;
CREATE TABLE day1_part2.input (data TEXT);
COPY day1_part2.input FROM '/days/day_1/input.txt';

-- Split the left and right columns into separate tables
CREATE TABLE day1_part2.left_input (data INT);
CREATE TABLE day1_part2.right_input (data INT);
DO $$
DECLARE
    row RECORD;
BEGIN
    FOR row IN SELECT * FROM day1_part2.input LOOP
        INSERT INTO day1_part2.left_input (data) VALUES (split_part(row.data, '  ', 1)::INT);
        INSERT INTO day1_part2.right_input (data) VALUES (split_part(row.data, '  ', 2)::INT);
    END LOOP;
END $$;

-- Multiply the data in the left table by the count of the same number in the right table
CREATE VIEW day1_part2.multiplied AS
SELECT
    l.data * count(r.data) AS product
FROM
    day1_part2.left_input l
JOIN
    day1_part2.right_input r
    ON l.data = r.data
GROUP BY l.data
;

-- Sum the products for a single total "Similarity score"
SELECT sum(product) "The answer for part 2 of day 1 is" FROM day1_part2.multiplied;