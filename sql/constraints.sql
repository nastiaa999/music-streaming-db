
-- Уникальность имени плейлиста в рамках пользователя
ALTER TABLE playlists 
ADD CONSTRAINT unique_user_playlist UNIQUE (user_id, playlist_name);

-- Уникальность номера трека в альбоме
ALTER TABLE songs 
ADD CONSTRAINT check_track_number 
CHECK (
    (album_id IS NULL AND track_number IS NULL) OR
    (album_id IS NOT NULL AND track_number IS NOT NULL)
);

ALTER TABLE songs 
ADD CONSTRAINT unique_album_track UNIQUE (album_id, track_number);

-- уникальность названия плейлиста
ALTER TABLE playlists 
ADD CONSTRAINT unique_user_playlist UNIQUE (user_id, playlist_name);

-- Уникальность порядка треков в плейлисте
ALTER TABLE playlist_song 
ADD CONSTRAINT unique_playlist_order UNIQUE (playlist_id, order_number);


-- Длительность трека должна быть положительной
ALTER TABLE songs 
ADD CONSTRAINT check_song_duration CHECK (duration > 0);

-- Длительность альбома неотрицательная
ALTER TABLE albums DROP CONSTRAINT IF EXISTS check_album_duration;
ALTER TABLE albums ADD CONSTRAINT check_album_duration CHECK (duration >= 0 OR duration IS NULL);

-- Количество треков не может быть отрицательным
ALTER TABLE albums 
ADD CONSTRAINT check_album_num_songs CHECK (num_songs >= 0);

ALTER TABLE playlists 
ADD CONSTRAINT check_playlist_num_songs CHECK (num_songs >= 0);

-- Количество альбомов и треков у исполнителя
ALTER TABLE artists 
ADD CONSTRAINT check_artist_counts CHECK (num_albums >= 0 AND num_songs >= 0);

-- Дата рождения не в будущем
ALTER TABLE artists 
ADD CONSTRAINT check_birth_date CHECK (birth_date <= CURRENT_DATE);

-- Дата релиза альбома не в будущем
ALTER TABLE albums 
ADD CONSTRAINT check_album_release CHECK (release_date <= CURRENT_DATE);

-- Дата релиза трека не в будущем
ALTER TABLE songs 
ADD CONSTRAINT check_song_release CHECK (release_date <= CURRENT_DATE);

-- Порядок треков в плейлисте должен быть положительным
ALTER TABLE playlist_song 
ADD CONSTRAINT check_order_number CHECK (order_number > 0);


--Один трек — один основной исполнитель
ALTER TABLE song_artist 
ADD CONSTRAINT unique_main_artist 
UNIQUE (song_id) 
WHERE is_featured = FALSE;
