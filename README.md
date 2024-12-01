# Advent of Code 2024

This repository contains my solutions for the Advent of Code 2024 challenge. I will be using PostgreSQL with SQL and pl/pgsql for all the solutions.

A `docker-compose.yml`-config is provided to start a clean PostgreSQL instance, listening on port 25432.

To run a solution, you should `cd` to the directory containing the solution and run the following command:

```bash
time PGPASSWORD=postgres psql -h 127.0.0.1 -p 25432 -U postgres -f <part.sql>
```

So if you want to run the solution for day 1, part 1, you should run:

```bash
time PGPASSWORD=postgres psql -h 127.0.0.1 -p 25432 -U postgres -f part1.sql
```
within the `day_1`-directory.