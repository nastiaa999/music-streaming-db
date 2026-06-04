CREATE DATABASE music_service
    WITH 
    ENCODING = 'UTF8'
    OWNER = postgres;

-- 1. Исполнители
CREATE TABLE artists (
    artist_id SERIAL PRIMARY KEY,
    artist_nickname VARCHAR(100) UNIQUE NOT NULL,
    artist_name VARCHAR(100),
    birth_date DATE,
    country VARCHAR(65),
    num_albums INTEGER DEFAULT 0,
    num_songs INTEGER DEFAULT 0
);

-- 2. Альбомы
CREATE TABLE albums (
    album_id SERIAL PRIMARY KEY,
    artist_id INTEGER REFERENCES artists(artist_id) ON DELETE CASCADE,
    album_name VARCHAR(200) NOT NULL,
    release_date DATE,
    duration INTEGER,
    genre VARCHAR(50),
    num_songs INTEGER DEFAULT 0,
    cover_image VARCHAR(500)
);

-- 3. Треки
CREATE TABLE songs (
    song_id SERIAL PRIMARY KEY,
    album_id INTEGER REFERENCES albums(album_id) ON DELETE SET NULL,
    song_name VARCHAR(200) NOT NULL,
    track_number INTEGER,
    duration INTEGER NOT NULL,
    release_date DATE,
    lyrics TEXT,
    genre VARCHAR(50)
);

-- 4. Связь треков с исполнителями (фиты)
CREATE TABLE song_artist (
    song_id INTEGER REFERENCES songs(song_id) ON DELETE CASCADE,
    artist_id INTEGER REFERENCES artists(artist_id) ON DELETE CASCADE,
    is_featured BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (song_id, artist_id)
);

-- 5. Пользователи
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(200) NOT NULL,
    registration_date TIMESTAMP DEFAULT NOW(),
    is_premium BOOLEAN DEFAULT FALSE
    birth_date DATE
);

-- 6. Плейлисты
CREATE TABLE playlists (
    playlist_id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(user_id) ON DELETE CASCADE,
    playlist_name VARCHAR(200) NOT NULL,
    duration INTEGER DEFAULT 0,
    num_songs INTEGER DEFAULT 0,
    is_public BOOLEAN DEFAULT TRUE,
    is_default BOOLEAN DEFAULT FALSE
);

-- 7. Связь плейлистов с треками
CREATE TABLE playlist_song (
    playlist_id INTEGER REFERENCES playlists(playlist_id) ON DELETE CASCADE,
    song_id INTEGER REFERENCES songs(song_id) ON DELETE CASCADE,
    order_number INTEGER NOT NULL,
    PRIMARY KEY (playlist_id, song_id)
);

-- 8. История прослушиваний
CREATE TABLE listening_history (
    history_id BIGSERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(user_id) ON DELETE CASCADE,
    song_id INTEGER REFERENCES songs(song_id) ON DELETE CASCADE,
    listened_at TIMESTAMP DEFAULT NOW()
);

