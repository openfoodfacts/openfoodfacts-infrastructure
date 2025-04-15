-- sqlite3 dq-issues.db < dq-issues-schema.sql
CREATE TABLE IF NOT EXISTS distrib (
       id INTEGER PRIMARY KEY,
       code TEXT NOT NULL,        -- the same product can enter the table, be fixed and entered it again, leading to several entries
       data_quality_errors TEXT DEFAULT '',
       entry_date TEXT DEFAULT '',
       sent_date TEXT DEFAULT '',
       sent_to_user TEXT DEFAULT '',
       fixed_date TEXT DEFAULT ''
);
CREATE INDEX ["distrib_code"] ON [distrib]("code");
CREATE INDEX ["distrib_data_quality_errors"] ON [distrib]("data_quality_errors");
CREATE INDEX ["distrib_entry_date"] ON [distrib]("entry_date");
CREATE INDEX ["distrib_sent_date"] ON [distrib]("sent_date");
CREATE INDEX ["distrib_sent_to_user"] ON [distrib]("sent_to_user");
CREATE INDEX ["distrib_fixed_date"] ON [distrib]("fixed_date");
