-- Create a clean schema with a table for the raw input and import the data
DROP SCHEMA IF EXISTS day12_part1 CASCADE;
CREATE SCHEMA day12_part1;
CREATE TABLE day12_part1.input (data TEXT);
COPY day12_part1.input FROM '/days/day_12/input.txt';

-- Create a table that has a column indicating the `y`-coordinate of the row, so we can easily fetch those
CREATE SEQUENCE day12_part1.row_id_seq;
CREATE TABLE day12_part1.input_with_row_id AS SELECT nextval('day12_part1.row_id_seq') AS row_id, data FROM day12_part1.input;

CREATE MATERIALIZED VIEW day12_part1.dimensions AS (
    SELECT
        MAX(LENGTH(data)) AS width,
        COUNT(*) AS height
    FROM day12_part1.input
);

CREATE TYPE day12_part1.coordinate AS (
    x INT,
    y INT
);

CREATE OR REPLACE FUNCTION day12_part1.char_at(_coordinate day12_part1.coordinate) RETURNS CHAR AS $$
BEGIN
    IF
        _coordinate.x < 1 OR
        _coordinate.y < 1 OR
        _coordinate.x > (SELECT width FROM day12_part1.dimensions) OR
        _coordinate.y > (SELECT height FROM day12_part1.dimensions)
    THEN
        RETURN '#'; -- Return a char marking the outside. Important as to count the outside as a perimeter as well.
    END IF;

    RETURN (
        SELECT SUBSTRING(data FROM _coordinate.x FOR 1)
        FROM day12_part1.input_with_row_id
        WHERE row_id = _coordinate.y
    )::CHAR;
END $$ LANGUAGE plpgsql;

CREATE TYPE day12_part1.score AS (
    coordinate day12_part1.coordinate,
    area INT,
    perimeter INT
);

CREATE TABLE day12_part1.seen (
    coordinate day12_part1.coordinate
);
CREATE INDEX ON day12_part1.seen (coordinate);

CREATE OR REPLACE FUNCTION day12_part1.get_area_and_perimeter(
    _coordinate day12_part1.coordinate,
    _plant CHAR
) RETURNS day12_part1.score AS $$
DECLARE
    _directions day12_part1.coordinate[] = ARRAY[(0, 1), (0, -1), (1, 0), (-1, 0)]; -- Down, Up, Right, Left
    _direction day12_part1.coordinate;
    _seen day12_part1.seen;
    _charOne CHAR;
    _area INT;
    _perimeter INT;
    _adjacent_score day12_part1.score;
BEGIN
    SELECT * INTO _seen FROM day12_part1.seen WHERE coordinate = _coordinate;
    IF _seen IS NOT NULL THEN -- Already seen it, so it applied to a score of a previous region, skip it
        RAISE DEBUG 'Already seen %', _coordinate;
        RETURN (_coordinate, 0, 0);
    END IF;

    RAISE DEBUG 'Checking %', _coordinate;

    -- Mark the current spot as seen
    INSERT INTO day12_part1.seen VALUES (_coordinate);

    _charOne := day12_part1.char_at(_coordinate);
    IF _charOne != _plant THEN -- Not a plant for this region, skip it
        RETURN (_coordinate, 0, 0);
    END IF;

    -- Area initializes to 1 for the current square. Perimeter initializes to 0 as that needs to be determined below
    _area := 1;
    _perimeter := 0;

    FOREACH _direction IN ARRAY _directions LOOP
        _charOne := day12_part1.char_at((_coordinate.x + _direction.x, _coordinate.y + _direction.y));
        IF _charOne != _plant THEN -- Bounds found, so increment the perimeter
            _perimeter := _perimeter + 1;
        ELSE
            _adjacent_score := day12_part1.get_area_and_perimeter((_coordinate.x + _direction.x, _coordinate.y + _direction.y), _plant);
            _area := _area + _adjacent_score.area;
            _perimeter := _perimeter + _adjacent_score.perimeter;
        END IF;
    END LOOP;

    RETURN (_coordinate, _area, _perimeter);
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day12_part1.part1() RETURNS BIGINT AS $$
DECLARE
    _total BIGINT = 0;
    _x INT = 1;
    _y INT = 1;
    _char CHAR;
    _score day12_part1.score;
BEGIN
    TRUNCATE day12_part1.seen;

    FOR _y IN 1..(SELECT height FROM day12_part1.dimensions) LOOP
        FOR _x IN 1..(SELECT width FROM day12_part1.dimensions) LOOP
            _char := day12_part1.char_at((_x, _y));
            _score := day12_part1.get_area_and_perimeter((_x, _y), _char);
            RAISE NOTICE '% has score %', _char, _score;
            _total := _total + (_score.area * _score.perimeter);
        END LOOP;
    END LOOP;

    RETURN _total;
END $$ LANGUAGE plpgsql;

SELECT day12_part1.part1() "The answer for part 1 of day 12 is";