CREATE TABLE chapter_state_temp (
    source_id TEXT NOT NULL,
    manga_id TEXT NOT NULL,
    chapter_id TEXT NOT NULL,
    read INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (source_id, manga_id, chapter_id)
) STRICT;

INSERT INTO chapter_state_temp (source_id, manga_id, chapter_id, read)
SELECT
    source_id,
    manga_id,
    chapter_id,
    MAX(read) as read  -- Consolidate duplicates by preferring read=1
FROM chapter_state
GROUP BY source_id, manga_id, chapter_id;

DROP TABLE chapter_state;
ALTER TABLE chapter_state_temp RENAME TO chapter_state;