WITH target_albums AS (
    SELECT album_id, album_name, release_date
    FROM albums
    LIMIT 5 
),
daily_plays AS (
    SELECT 
        ta.album_id,
        ta.album_name,
        ta.release_date,
        lh.listened_at::date AS day,
        COUNT(*) AS daily_cnt
    FROM target_albums ta
    JOIN songs s ON ta.album_id = s.album_id
    JOIN listening_history lh ON s.song_id = lh.song_id
    WHERE lh.listened_at >= ta.release_date
    GROUP BY ta.album_id, ta.album_name, ta.release_date, lh.listened_at::date
),
growth_stats AS (
    SELECT 
        album_id, album_name, release_date, day, daily_cnt,
        SUM(daily_cnt) OVER (PARTITION BY album_id ORDER BY day ROWS UNBOUNDED PRECEDING) AS cumulative_plays,
        AVG(daily_cnt) OVER (PARTITION BY album_id ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS avg_7d
    FROM daily_plays
)
SELECT * FROM growth_stats
ORDER BY album_id, day;