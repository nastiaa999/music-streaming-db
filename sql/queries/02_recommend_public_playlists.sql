WITH target_user AS (
    SELECT
        6 AS user_id,   
        EXTRACT(
            YEAR FROM age(CURRENT_DATE, u.birth_date)
        )::int AS age

    FROM users u
    WHERE u.user_id = 6
),
top_genres AS (
    SELECT
        s.genre,
        COUNT(*) AS genre_plays
    FROM listening_history lh
    JOIN songs s
        ON lh.song_id = s.song_id
    WHERE lh.user_id = (SELECT user_id FROM target_user)
      AND lh.listened_at >= CURRENT_DATE - INTERVAL '3 months'
    GROUP BY s.genre
    HAVING COUNT(*) >= 10
),
top_artists AS (
    SELECT
        a.artist_id,
        a.artist_nickname,
        COUNT(*) AS artist_plays
    FROM listening_history lh
    JOIN songs s
        ON lh.song_id = s.song_id
    JOIN albums al
        ON s.album_id = al.album_id
    JOIN artists a
        ON al.artist_id = a.artist_id
    WHERE lh.user_id = (SELECT user_id FROM target_user)
      AND lh.listened_at >= CURRENT_DATE - INTERVAL '3 months'
    GROUP BY a.artist_id, a.artist_nickname
    HAVING COUNT(*) >= 10  
),
user_profile AS (
    SELECT
        total_plays,

  top3_plays,

        ROUND(
            top3_plays::numeric
            /
            total_plays * 100,
            2
        ) AS top3_percent,

        ROUND(
            1 - (top3_plays::numeric / total_plays),
            2
        ) AS diversity_factor

    FROM (

        SELECT

            SUM(cnt) AS total_plays,

            SUM(cnt) FILTER (
                WHERE genre_rank <= 3
            ) AS top3_plays

        FROM (

            SELECT

                s.genre,

                COUNT(*) AS cnt,

                ROW_NUMBER() OVER (
                    ORDER BY COUNT(*) DESC
                ) AS genre_rank

            FROM listening_history lh

            JOIN songs s
                ON lh.song_id = s.song_id

            WHERE lh.user_id = (SELECT user_id FROM target_user)
              AND lh.listened_at >= CURRENT_DATE - INTERVAL '3 months'

            GROUP BY s.genre

        ) ranked_genres

    ) stats
),
same_age_users AS (

    SELECT u.user_id

    FROM users u
    CROSS JOIN target_user tu

    WHERE ABS(
        EXTRACT(
            YEAR FROM age(CURRENT_DATE, u.birth_date)
        ) - tu.age
    ) <= 5

    AND u.user_id != tu.user_id
),
age_popular_tracks AS (

    SELECT

        lh.song_id,

        COUNT(*) AS age_plays

    FROM listening_history lh

    JOIN same_age_users sau
        ON lh.user_id = sau.user_id

    WHERE lh.listened_at >= CURRENT_DATE - INTERVAL '3 months'

    GROUP BY lh.song_id
),

recommended_tracks AS (

    SELECT

        s.song_id,

        s.song_name,

        s.genre,

        a.artist_nickname,

        COALESCE(tg.genre_plays, 0)
            AS genre_popularity,

        COALESCE(ta.artist_plays, 0)
            AS artist_popularity,

        COALESCE(apt.age_plays, 0)
            AS age_popularity,

        up.diversity_factor,

        up.top3_percent

    FROM songs s

    LEFT JOIN albums al
        ON s.album_id = al.album_id

    LEFT JOIN artists a
        ON al.artist_id = a.artist_id

    LEFT JOIN top_genres tg
        ON s.genre = tg.genre

    LEFT JOIN top_artists ta
        ON a.artist_id = ta.artist_id

    LEFT JOIN age_popular_tracks apt
        ON s.song_id = apt.song_id

    CROSS JOIN user_profile up

    WHERE
        (tg.genre IS NOT NULL OR ta.artist_id IS NOT NULL)
        AND s.song_id NOT IN (

            SELECT song_id
            FROM listening_history
            WHERE user_id = (SELECT user_id FROM target_user)
        )
)

SELECT

    song_name,

    genre,

    artist_nickname,

    genre_popularity,

    artist_popularity,

    age_popularity,


    ROUND(
        (genre_popularity * 3 + artist_popularity * 4)
        * (1 - diversity_factor + 0.3)
        +
        LEAST(age_popularity, 20) * diversity_factor,
        0
    ) AS recommendation_score,

    CASE

        WHEN diversity_factor > 0.4
             AND age_popularity > 0
             AND (genre_popularity > 0 OR artist_popularity > 0)
        THEN 'Персональное + популярное у ровесников'

        WHEN diversity_factor > 0.4
             AND age_popularity > 0
        THEN 'Популярно у ровесников'

        WHEN artist_popularity > 0
             AND genre_popularity > 0
        THEN 'Любимый жанр и исполнитель'

        WHEN artist_popularity > 0
        THEN 'Любимый исполнитель'

        WHEN genre_popularity > 0
        THEN 'Любимый жанр'

        ELSE 'Дополнительная рекомендация'

    END AS recommendation_reason

FROM recommended_tracks

ORDER BY

    recommendation_score DESC,

    artist_popularity DESC,

    genre_popularity DESC,

    age_popularity DESC

