WITH user_metrics AS (
    SELECT user_id,
           MAX(listened_at) AS last_listen,
           COUNT(DISTINCT DATE(listened_at)) AS active_days,
           COUNT(*) AS total_plays
    FROM listening_history
    GROUP BY user_id
),
quartiles AS (
    SELECT user_id,
           NTILE(4) OVER (ORDER BY last_listen DESC) AS recency,
           NTILE(4) OVER (ORDER BY active_days DESC) AS frequency,
           NTILE(4) OVER (ORDER BY total_plays DESC) AS intensity
    FROM user_metrics
)
SELECT 
    recency, frequency, intensity,
    CASE 
        WHEN recency <= 2 AND frequency <= 2 THEN 'Churned'
        WHEN recency = 1 AND frequency = 1 AND intensity = 1 THEN 'Champions'
        ELSE 'Regular'
    END AS segment,
    COUNT(*) AS user_count
FROM quartiles
GROUP BY recency, frequency, intensity
ORDER BY segment, user_count DESC;