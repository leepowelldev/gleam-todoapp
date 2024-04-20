CREATE TABLE IF NOT EXISTS "schema_migrations" (version varchar(128) primary key);
CREATE TABLE items (
  id INTEGER
  PRIMARY KEY
  AUTOINCREMENT
  NOT NULL,

  created_at TEXT
  NOT NULL
  DEFAULT CURRENT_TIMESTAMP,

  updated_at TEXT
  NOT NULL
  DEFAULT CURRENT_TIMESTAMP,

  completed_at TEXT
  DEFAULT NULL,

  content TEXT
  NOT NULL
  CONSTRAINT empty_content CHECK (content != ''),

  completed INTEGER
  NOT NULL
  DEFAULT 0
) strict;
CREATE TRIGGER update_updated_at
AFTER UPDATE ON items
FOR EACH ROW
BEGIN
  UPDATE items SET updated_at = CURRENT_TIMESTAMP WHERE id = old.id;
END;
CREATE TRIGGER update_completed_at
BEFORE UPDATE ON items
FOR EACH ROW
WHEN NEW.completed != OLD.completed
BEGIN
  UPDATE items SET completed_at = CASE WHEN NEW.completed = 1 THEN CURRENT_TIMESTAMP ELSE NULL END WHERE id = old.id;
END;
-- Dbmate schema migrations
INSERT INTO "schema_migrations" (version) VALUES
  ('20240409171815'),
  ('20240410063944');
