CREATE TABLE IF NOT EXISTS members (
       id INTEGER PRIMARY KEY,
       off_username TEXT DEFAULT '',
       email TEXT NOT NULL,
       token TEXT DEFAULT ''
);
