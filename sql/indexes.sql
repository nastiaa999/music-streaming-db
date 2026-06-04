CREATE INDEX idx_lh_date_song ON listening_history (listened_at DESC, song_id);
CREATE INDEX idx_lh_user_date ON listening_history (user_id, listened_at DESC);
CREATE INDEX idx_pl_public_partial ON playlists (user_id) WHERE is_public = TRUE;
CREATE INDEX idx_sa_artist_id ON song_artist (artist_id);
CREATE INDEX idx_songs_album_id ON songs (album_id);
