WITH recent_plays AS (
    SELECT lh.song_id, s.genre
    FROM listening_history lh
    JOIN songs s ON lh.song_id = s.song_id
    WHERE lh.listened_at >= CURRENT_DATE - INTERVAL '30 days'
),
genre_ranking AS (
    SELECT 
        genre, 
        song_id, 
        COUNT(*) AS plays,
        ROW_NUMBER() OVER (PARTITION BY genre ORDER BY COUNT(*) DESC, song_id) AS rn
    FROM recent_plays
    GROUP BY genre, song_id
)
SELECT genre, song_id, plays
FROM genre_ranking
WHERE rn <= 5
ORDER BY genre, plays DESC;