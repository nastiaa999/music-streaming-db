CREATE OR REPLACE FUNCTION update_album_stats()
RETURNS TRIGGER AS $$
BEGIN
    -- Обновляем альбомы, у которых есть треки
    UPDATE albums a
    SET 
        num_songs = sub.cnt,
        duration = sub.dur
    FROM (
        SELECT album_id,
               COUNT(*) AS cnt,
               COALESCE(SUM(duration), 0) AS dur
        FROM songs
        WHERE album_id IS NOT NULL
        GROUP BY album_id
    ) sub
    WHERE a.album_id = sub.album_id;

    -- Сбрасываем счетчики для альбомов, у которых больше нет треков
    UPDATE albums 
    SET num_songs = 0, duration = 0
    WHERE album_id IS NOT NULL 
      AND album_id NOT IN (SELECT album_id FROM songs WHERE album_id IS NOT NULL);

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_album_stats ON songs;
CREATE TRIGGER trg_update_album_stats
AFTER INSERT OR DELETE OR UPDATE ON songs
FOR EACH STATEMENT
EXECUTE FUNCTION update_album_stats();
-- ARTIST: обновление через albums
CREATE OR REPLACE FUNCTION update_artist_stats()
RETURNS TRIGGER AS $$
DECLARE
    artist_id_to_update INTEGER;
BEGIN
    IF TG_OP = 'INSERT' THEN
        artist_id_to_update := NEW.artist_id;

    ELSIF TG_OP = 'DELETE' THEN
        artist_id_to_update := OLD.artist_id;

    ELSIF TG_OP = 'UPDATE' THEN

        IF OLD.artist_id IS DISTINCT FROM NEW.artist_id THEN
            PERFORM update_single_artist(OLD.artist_id);
            PERFORM update_single_artist(NEW.artist_id);
            RETURN NEW;
        ELSE
            artist_id_to_update := NEW.artist_id;
        END IF;

    END IF;

    PERFORM update_single_artist(artist_id_to_update);

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_update_artist_stats
AFTER INSERT OR DELETE OR UPDATE OF artist_id ON albums
FOR EACH ROW
EXECUTE FUNCTION update_artist_stats();

CREATE OR REPLACE FUNCTION update_single_artist(p_artist_id INTEGER)
RETURNS VOID AS $$
BEGIN
    IF p_artist_id IS NULL THEN
        RETURN;
    END IF;

    UPDATE artists
    SET
        num_albums = (
            SELECT COUNT(*) 
            FROM albums 
            WHERE artist_id = p_artist_id
        ),
        num_songs = (
            SELECT COUNT(*)
            FROM song_artist
            WHERE artist_id = p_artist_id
        )
    WHERE artist_id = p_artist_id;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION trg_update_artist_from_song_artist()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        PERFORM update_single_artist(NEW.artist_id);

    ELSIF TG_OP = 'DELETE' THEN
        PERFORM update_single_artist(OLD.artist_id);

    ELSIF TG_OP = 'UPDATE' THEN
        PERFORM update_single_artist(OLD.artist_id);
        PERFORM update_single_artist(NEW.artist_id);
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_song_artist_update
AFTER INSERT OR DELETE OR UPDATE ON song_artist
FOR EACH ROW
EXECUTE FUNCTION trg_update_artist_from_song_artist();



-- PLAYLIST: обновление статистики
CREATE OR REPLACE FUNCTION update_playlist_stats()
RETURNS TRIGGER AS $$
DECLARE
    pl_id INTEGER;
BEGIN
    IF TG_OP = 'INSERT' THEN
        pl_id := NEW.playlist_id;

    ELSIF TG_OP = 'DELETE' THEN
        pl_id := OLD.playlist_id;

    ELSIF TG_OP = 'UPDATE' THEN
        pl_id := NEW.playlist_id;
    END IF;

    IF pl_id IS NOT NULL THEN
        UPDATE playlists
        SET
            num_songs = (
                SELECT COUNT(*) FROM playlist_song WHERE playlist_id = pl_id
            ),
            duration = (
                SELECT COALESCE(SUM(s.duration),0)
                FROM playlist_song ps
                JOIN songs s ON ps.song_id = s.song_id
                WHERE ps.playlist_id = pl_id
            )
        WHERE playlist_id = pl_id;
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE TRIGGER trg_update_playlist_stats
AFTER INSERT OR DELETE OR UPDATE OF song_id, playlist_id ON playlist_song
FOR EACH ROW
EXECUTE FUNCTION update_playlist_stats();



-- DEFAULT PLAYLIST
CREATE OR REPLACE FUNCTION create_default_playlist()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO playlists (user_id, playlist_name, is_public, is_default)
    VALUES (NEW.user_id, 'Избранное', FALSE, TRUE)
    ON CONFLICT (user_id, playlist_name) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE TRIGGER trg_create_default_playlist
AFTER INSERT ON users
FOR EACH ROW
EXECUTE FUNCTION create_default_playlist();