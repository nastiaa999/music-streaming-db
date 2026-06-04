WITH recent_songs AS (
    SELECT DISTINCT song_id
    FROM listening_history
    WHERE listened_at >= CURRENT_DATE - INTERVAL '90 days'
),
active_playlists AS (
    SELECT ps.playlist_id
    FROM playlist_song ps
    JOIN recent_songs rs ON ps.song_id = rs.song_id
    GROUP BY ps.playlist_id
    HAVING COUNT(*) > 10
)
SELECT 
    ps.playlist_id, 
    s.song_name, 
    s.genre,
    ARRAY_AGG(s.song_name) OVER (PARTITION BY ps.playlist_id ORDER BY s.song_name) AS low_rotation_pool
FROM playlist_song ps
JOIN songs s ON ps.song_id = s.song_id
JOIN active_playlists ap ON ps.playlist_id = ap.playlist_id
WHERE NOT EXISTS (
    SELECT 1 FROM recent_songs rs WHERE rs.song_id = ps.song_id
)
ORDER BY ps.playlist_id, s.song_name;