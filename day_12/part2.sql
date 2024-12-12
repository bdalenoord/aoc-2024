-- Create a clean schema with a table for the raw input and import the data
DROP SCHEMA IF EXISTS day12_part2 CASCADE;
CREATE SCHEMA day12_part2;
CREATE TABLE day12_part2.input (data TEXT);
COPY day12_part2.input FROM '/days/day_12/input.txt';

-- Create a table that has a column indicating the `y`-coordinate of the row, so we can easily fetch those
CREATE SEQUENCE day12_part2.row_id_seq;
CREATE TABLE day12_part2.input_with_row_id AS SELECT nextval('day12_part2.row_id_seq') AS row_id, data FROM day12_part2.input;

CREATE MATERIALIZED VIEW day12_part2.dimensions AS (
    SELECT
        MAX(LENGTH(data)) AS width,
        COUNT(*) AS height
    FROM day12_part2.input
);

CREATE TYPE day12_part2.coordinate AS (
    x INT,
    y INT
);

CREATE OR REPLACE FUNCTION day12_part2.char_at(_coordinate day12_part2.coordinate) RETURNS CHAR AS $$
BEGIN
    IF
        _coordinate.x < 1 OR
        _coordinate.y < 1 OR
        _coordinate.x > (SELECT width FROM day12_part2.dimensions) OR
        _coordinate.y > (SELECT height FROM day12_part2.dimensions)
    THEN
        RETURN '#'; -- Return a char marking the outside. Important as to count the outside as a perimeter as well.
    END IF;

    RETURN (
        SELECT SUBSTRING(data FROM _coordinate.x FOR 1)
        FROM day12_part2.input_with_row_id
        WHERE row_id = _coordinate.y
    )::CHAR;
END $$ LANGUAGE plpgsql;

CREATE TYPE day12_part2.score AS (
    coordinate day12_part2.coordinate,
    area INT,
    perimeter INT
);

CREATE TABLE day12_part2.seen (
    coordinate day12_part2.coordinate
);
CREATE INDEX ON day12_part2.seen (coordinate);

CREATE OR REPLACE FUNCTION day12_part2.get_area_and_perimeter(
    _coordinate day12_part2.coordinate,
    _plant CHAR
) RETURNS day12_part2.score AS $$
DECLARE
    _directions day12_part2.coordinate[] = ARRAY[(0, 1), (0, -1), (1, 0), (-1, 0)]; -- Right, left, down, up
    _direction day12_part2.coordinate;
    _seen day12_part2.seen;
    _charOne CHAR;
    _charTwo CHAR;
    _area INT;
    _perimeter INT;
    _recursive_score day12_part2.score;
BEGIN
    IF
        _coordinate.x > (SELECT width FROM day12_part2.dimensions) OR
        _coordinate.y > (SELECT height FROM day12_part2.dimensions) OR
        _coordinate.x < 1 OR
        _coordinate.y < 1
        THEN -- Out of bounds, skip it
        RETURN (_coordinate, 0, 0);
    END IF;

    SELECT * INTO _seen FROM day12_part2.seen WHERE coordinate = _coordinate;
    IF _seen IS NOT NULL THEN -- Already seen it, so it applied to a score of a previous region, skip it
        RETURN (_coordinate, 0, 0);
    END IF;

    _charOne := day12_part2.char_at(_coordinate);
    IF _charOne <> _plant THEN -- Not a plant for this region, skip it
        RETURN (_coordinate, 0, 0);
    END IF;

    -- Mark the current spot as seen
    INSERT INTO day12_part2.seen VALUES (_coordinate);

    -- Area initializes to 1 for the current square. Perimeter initializes to 0 as that needs to be determined below
    _area := 1;
    _perimeter := 0;

    FOREACH _direction IN ARRAY _directions LOOP
        _charOne := day12_part2.char_at((_coordinate.x + _direction.x, _coordinate.y + _direction.y));
        IF _charOne <> _plant THEN -- Bounds found, so increment the perimeter
            _perimeter := _perimeter + 1;

            -- Check corners. If no corner is found, we should decrease the perimeter again as we are on a straight
            -- No need to check all directions, as we know we're moving from top left to bottom right

            _charOne := day12_part2.char_at((_coordinate.x + 1, _coordinate.y));
            _charTwo := day12_part2.char_at((_coordinate.x + 1, _coordinate.y + 1));
            IF _direction = (0, 1) AND _charOne = _plant AND _charTwo <> _plant THEN
                _perimeter := _perimeter - 1;
            END IF;

            _charOne := day12_part2.char_at((_coordinate.x + 1, _coordinate.y));
            _charTwo := day12_part2.char_at((_coordinate.x + 1, _coordinate.y - 1));
            IF _direction = (0, -1) AND _charOne = _plant AND _charTwo <> _plant THEN
                _perimeter := _perimeter - 1;
            END IF;

            _charOne := day12_part2.char_at((_coordinate.x, _coordinate.y + 1));
            _charTwo := day12_part2.char_at((_coordinate.x + 1, _coordinate.y + 1));
            IF _direction = (1, 0) AND _charOne = _plant AND _charTwo <> _plant THEN
                _perimeter := _perimeter - 1;
            END IF;

            _charOne := day12_part2.char_at((_coordinate.x, _coordinate.y + 1));
            _charTwo := day12_part2.char_at((_coordinate.x - 1, _coordinate.y + 1));
            IF _direction = (-1, 0) AND _charOne = _plant AND _charTwo <> _plant THEN
                _perimeter := _perimeter - 1;
            END IF;
        ELSE
            _recursive_score := day12_part2.get_area_and_perimeter((_coordinate.x + _direction.x, _coordinate.y + _direction.y), _plant);
            _area := _area + _recursive_score.area;
            _perimeter := _perimeter + _recursive_score.perimeter;
        END IF;
    END LOOP;

    RETURN (_coordinate, _area, _perimeter);
END $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION day12_part2.part2() RETURNS BIGINT AS $$
DECLARE
    _total BIGINT = 0;
    _x INT = 1;
    _y INT = 1;
    _char CHAR;
    _score day12_part2.score;
BEGIN
    TRUNCATE day12_part2.seen;

    FOR _y IN 1..(SELECT height FROM day12_part2.dimensions) LOOP
        FOR _x IN 1..(SELECT width FROM day12_part2.dimensions) LOOP
            _char := day12_part2.char_at((_x, _y));
            _score := day12_part2.get_area_and_perimeter((_x, _y), _char);
            _total := _total + (_score.area * _score.perimeter);
        END LOOP;
    END LOOP;

    RETURN _total;
END $$ LANGUAGE plpgsql;

SELECT day12_part2.part2() "The answer for part 2 of day 12 is";