WITH user_genres AS (
    SELECT 
        lh.user_id,
        s.genre,
        COUNT(*) AS cnt,
        COUNT(*) OVER (PARTITION BY lh.user_id) AS genre_count, 
        RANK() OVER (PARTITION BY lh.user_id ORDER BY COUNT(*) DESC) AS rnk
    FROM listening_history lh
    JOIN songs s ON lh.song_id = s.song_id
    GROUP BY lh.user_id, s.genre
),
top_diverse AS (
    SELECT 
        user_id,
        genre AS main_genre,
        cnt AS main_plays,
        genre_count
    FROM user_genres
    WHERE rnk = 1 AND genre_count >= 5
)
SELECT 
    u.user_id,
    u.username,
    td.main_genre,
    td.main_plays,
    td.genre_count,
    ARRAY_AGG(ug.genre ORDER BY ug.genre) FILTER (WHERE ug.genre != td.main_genre) AS other_genres
FROM top_diverse td
JOIN users u USING (user_id)
JOIN user_genres ug USING (user_id)
GROUP BY u.user_id, u.username, td.main_genre, td.main_plays, td.genre_count
ORDER BY td.genre_count DESC, td.main_plays DESC
