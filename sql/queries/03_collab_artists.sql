WITH collab_pairs AS (
    SELECT sa1.artist_id AS a1, sa2.artist_id AS a2, COUNT(DISTINCT sa1.song_id) AS tracks
    FROM song_artist sa1
    JOIN song_artist sa2 ON sa1.song_id = sa2.song_id AND sa1.artist_id < sa2.artist_id
    GROUP BY sa1.artist_id, sa2.artist_id
    HAVING COUNT(DISTINCT sa1.song_id) >= 2
),
ranked_collabs AS (
    SELECT 
        art1.artist_nickname AS artist_1,
        art2.artist_nickname AS artist_2,
        cp.tracks,
        DENSE_RANK() OVER (ORDER BY cp.tracks DESC) AS collab_rank
    FROM collab_pairs cp
    JOIN artists art1 ON cp.a1 = art1.artist_id
    JOIN artists art2 ON cp.a2 = art2.artist_id
)
SELECT * FROM ranked_collabs WHERE collab_rank <= 10;