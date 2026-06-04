import pandas as pd
import random
from faker import Faker
import psycopg2
from psycopg2.extras import execute_values
from datetime import date

fake = Faker()

conn = psycopg2.connect("dbname=music_service user=admin password=1234 host=localhost port=5432")
cur = conn.cursor()

print("Подключено!")

df = pd.read_csv(
    "Popular_Spotify_Songs.csv",
    encoding="utf-8",
    engine="python",
    on_bad_lines="skip"
)

df = df.dropna(subset=["artist(s)_name", "track_name"])
df = df.reset_index(drop=True)
def generate_lyrics(song_name):
    """Генерирует осмысленный текст песни на основе названия"""
    
    love_words = ["love", "heart", "feel", "touch", "kiss", "hold", "warm", "close", "together", "forever"]
    dark_words = ["shadow", "dark", "night", "fear", "cold", "alone", "silence", "empty", "lost", "pain"]
    hope_words = ["light", "rise", "fly", "dream", "hope", "shine", "break", "free", "sky", "tomorrow"]
    party_words = ["dance", "night", "fire", "burn", "move", "beat", "loud", "wild", "energy", "alive"]
    
    name_lower = song_name.lower()
    
    if any(word in name_lower for word in ["love", "heart", "dream", "golden", "eternal"]):
        theme_words = love_words + hope_words
    elif any(word in name_lower for word in ["dark", "lonely", "silent", "empty", "broken", "fading"]):
        theme_words = dark_words
    elif any(word in name_lower for word in ["burning", "fire", "neon", "lights", "energy"]):
        theme_words = party_words + hope_words
    else:
        theme_words = love_words + dark_words + hope_words
    
    verse_templates = [
        f"Walking through the {random.choice(['night', 'streets', 'shadows', 'city'])} alone",
        f"Searching for a {random.choice(['light', 'sign', 'answer', 'home'])}",
        f"Can you {random.choice(['hear', 'feel', 'see', 'remember'])} me calling out",
        f"Everything we had is {random.choice(['gone', 'fading', 'changing', 'slipping'])} now",
        f"Holding on to {random.choice(['memories', 'promises', 'moments', 'dreams'])} we made",
        f"The {random.choice(['rain', 'wind', 'time', 'world'])} keeps moving on",
        f"Lost inside this {random.choice(['maze', 'silence', 'rhythm', 'feeling'])}",
        f"Waiting for the {random.choice(['morning', 'moment', 'chance', 'day'])} to break"
    ]
    
    chorus_templates = [
        f"Oh, {random.choice(theme_words).capitalize()}, take me higher",
        f"We're {random.choice(['burning', 'rising', 'falling', 'dancing'])} like {random.choice(['fire', 'stars', 'waves', 'light'])}",
        f"Don't let go, hold on {random.choice(['tight', 'strong', 'forever', 'tonight'])}",
        f"In the end, we'll find our {random.choice(['way', 'place', 'time', 'peace'])}",
        f"This is our {random.choice(['moment', 'song', 'life', 'story'])}, we're {random.choice(['alive', 'free', 'one', 'here'])}"
    ]
    
    lyrics = []
    lyrics.append("[Verse 1]")
    lyrics.extend(random.sample(verse_templates, 4))
    lyrics.append("")
    lyrics.append("[Chorus]")
    lyrics.extend(random.sample(chorus_templates, 4))
    lyrics.append("")
    lyrics.append("[Verse 2]")
    lyrics.extend(random.sample(verse_templates, 4))
    lyrics.append("")
    lyrics.append("[Chorus]")
    lyrics.extend(random.sample(chorus_templates, 4))
    
    if random.random() > 0.5:
        lyrics.append("")
        lyrics.append("[Bridge]")
        lyrics.append(f"Everything will be {random.choice(['alright', 'okay', 'fine', 'clear'])}")
        lyrics.append(f"We'll make it through the {random.choice(['night', 'storm', 'pain', 'fear'])}")
    
    lyrics.append("")
    lyrics.append("[Chorus]")
    lyrics.extend(random.sample(chorus_templates, 4))
    
    return "\n".join(lyrics)

print("Generating artists...")

artist_set = set()
for artists in df["artist(s)_name"]:
    if not isinstance(artists, str):
        continue
    for name in artists.split(","):
        clean_name = name.strip()
        if clean_name:
            artist_set.add(clean_name)

print(f"Found {len(artist_set)} unique artists in dataset")

artists_list = [
    (
        name,
        name,
        fake.date_between(start_date='-40y', end_date='-18y'),
        fake.country()
    )
    for name in artist_set
]

execute_values(cur, """
    INSERT INTO artists (artist_nickname, artist_name, birth_date, country)
    VALUES %s
    ON CONFLICT (artist_nickname) DO UPDATE 
    SET artist_name = EXCLUDED.artist_name
""", artists_list)
conn.commit()

cur.execute("SELECT artist_id, artist_nickname FROM artists")
artist_map = {name: id for id, name in cur.fetchall()}
print(f"Loaded {len(artist_map)} artists into map")

print("Generating albums...")

genres = ["Pop", "Rock", "Hip-Hop", "R&B", "Indie", "Electronic", "Jazz", "Classical"]
album_words = ["Midnight", "Echoes", "Horizons", "Velvet", "Neon", "Dreams", "Waves", "Silence", "Thunder", "Crystal"]

albums = []
for artist_name, artist_id in artist_map.items():
    # 1-3 альбома на артиста для разнообразия
    for _ in range(random.randint(1, 3)):
        albums.append((
            artist_id,
            f"{random.choice(album_words)} {fake.word().capitalize()}",
            fake.date_between(start_date='-15y', end_date='today'),
            random.choice(genres),
            fake.image_url()
        ))

execute_values(cur, """
    INSERT INTO albums (artist_id, album_name, release_date, genre, cover_image)
    VALUES %s
    ON CONFLICT DO NOTHING
""", albums)
conn.commit()

cur.execute("SELECT album_id, artist_id FROM albums")
albums_data = cur.fetchall()
print(f"Generated {len(albums_data)} albums")

print("Generating songs...")

genres = ["Pop", "Rock", "Hip-Hop", "R&B", "Indie", "Electronic", "Jazz"]
songs_to_insert = []
song_artist_map = {}  # Словарь: song_name -> [artist_names]

processed = 0
for _, row in df.iterrows():
    track_name = row["track_name"]
    if not isinstance(track_name, str) or not track_name.strip():
        continue
    
    artists_raw = row["artist(s)_name"]
    if not isinstance(artists_raw, str):
        continue
    
    artist_list = [a.strip() for a in artists_raw.split(",") if a.strip()]
    if not artist_list:
        continue
    
    # Дата релиза
    try:
        release_date = date(int(row["released_year"]), int(row["released_month"]), int(row["released_day"]))
    except:
        release_date = fake.date_between(start_date='-10y', end_date='today')
    
    main_artist = artist_list[0]
    artist_id = artist_map.get(main_artist)
    if not artist_id:
        continue
    
    # Выбираем альбом артиста
    possible_albums = [a for a in albums_data if a[1] == artist_id]
    album_id = random.choice(possible_albums)[0] if possible_albums else None
    
    # Нормализуем имя для поиска (убираем лишние пробелы)
    clean_name = track_name.strip()
    
    songs_to_insert.append((
        album_id,
        clean_name,
        random.randint(1, 20),
        random.randint(90, 420),
        random.choice(genres),
        release_date,
        generate_lyrics(clean_name)
    ))
    
    # Сохраняем мапу: Название песни -> Список артистов
    song_artist_map[clean_name] = artist_list
    
    processed += 1
    if processed % 500 == 0:
        print(f"  Prepared {processed} songs...")

print(f"Inserting {len(songs_to_insert)} songs...")

# Вставка песен
if songs_to_insert:
    execute_values(cur, """
        INSERT INTO songs (album_id, song_name, track_number, duration, genre, release_date, lyrics)
        VALUES %s
    """, songs_to_insert)
    conn.commit()

# ВАЖНО: Загружаем ВСЕ песни из БД, а не только новые
print("Loading all songs from database...")
cur.execute("SELECT song_id, song_name FROM songs")
all_songs = cur.fetchall()
song_ids = [row[0] for row in all_songs]
song_name_to_id = {row[1]: row[0] for row in all_songs}  # Мапа для быстрого поиска

print(f"Total songs in database: {len(song_ids)}")

print("Linking artists to songs...")

song_artist_links = []
linked_count = 0
missing_songs = 0

# Получаем список всех ID артистов для случайного выбора
all_artist_ids = list(artist_map.values())

for song_name, artist_list in song_artist_map.items():
    song_id = song_name_to_id.get(song_name)
    
    if not song_id:
        missing_songs += 1
        continue
    
    # 1. Добавляем основных артистов из датасета
    for i, name in enumerate(artist_list):
        artist_id = artist_map.get(name.strip())
        if artist_id:
            song_artist_links.append((song_id, artist_id, i != 0))
            linked_count += 1
    
    if random.random() < 0.2:  # 20% шанс
        # Выбираем случайного артиста, которого нет в основном списке
        current_ids = [artist_map.get(n.strip()) for n in artist_list if artist_map.get(n.strip())]
        other_artists = [a for a in all_artist_ids if a not in current_ids]
        
        if other_artists:
            featured_artist = random.choice(other_artists)
            song_artist_links.append((song_id, featured_artist, True))
            linked_count += 1

print(f"Missing songs in DB: {missing_songs}")
print(f"Creating {len(song_artist_links)} song_artist links...")

# Вставка батчами
batch_size = 5000
for i in range(0, len(song_artist_links), batch_size):
    batch = song_artist_links[i:i+batch_size]
    execute_values(cur, """
        INSERT INTO song_artist (song_id, artist_id, is_featured)
        VALUES %s
        ON CONFLICT DO NOTHING
    """, batch)
    conn.commit()

print(f"✅ Created {len(song_artist_links)} song_artist links")

print("Generating users...")

users = []
generated_emails = set()

# Генерируем уникальные email'ы
while len(users) < 3000:
    email = fake.unique.email()
    if email not in generated_emails:
        generated_emails.add(email)
        users.append((
            fake.user_name(),
            email,
            fake.password()
        ))

# Добавляем ON CONFLICT для подстраховки
execute_values(cur, """
    INSERT INTO users (username, email, password_hash)
    VALUES %s
    ON CONFLICT (email) DO NOTHING
""", users)
conn.commit()

# ВАЖНО: Получаем user_ids ПОСЛЕ вставки
cur.execute("SELECT user_id FROM users")
user_ids = [row[0] for row in cur.fetchall()]
print(f"Generated {len(user_ids)} users")

print("Generating playlists...")

playlist_base_names = ["Утренний плейлист", "Для тренировки", "Вечерняя меланхолия", "Дорога", 
                       "Настроение", "Любимое", "Ретро", "Новинки", "Спокойствие", "Энергия",
                       "Фокус", "Парти", "Грусть", "Мотивация", "Чилл"]

playlists_data = []
playlist_ids = []

for user_id in user_ids:
    playlists_data.append((user_id, "Избранное", False, True))

for user_id in user_ids:
    num_extra = random.randint(2, 4)
    for i in range(num_extra):
        base_name = random.choice(playlist_base_names)
        # Добавляем суффикс для уникальности: "Утренний плейлист #1", "Утренний плейлист #2"
        unique_name = f"{base_name} #{user_id % 100 + i}"
        is_public = random.choice([True, False])
        playlists_data.append((user_id, unique_name, is_public, False))

# Вставка батчами
for i in range(0, len(playlists_data), 5000):
    batch = playlists_data[i:i+5000]
    execute_values(cur, """
        INSERT INTO playlists (user_id, playlist_name, is_public, is_default)
        VALUES %s
        ON CONFLICT (user_id, playlist_name) DO NOTHING
    """, batch)
    conn.commit()

cur.execute("SELECT playlist_id, user_id FROM playlists")
playlists = cur.fetchall()
playlist_ids = [p[0] for p in playlists]
print(f"Generated {len(playlist_ids)} playlists")


print("Linking playlists to songs...")

if len(song_ids) < 10:
    print("WARNING: Too few songs! Loading more from database...")
    cur.execute("SELECT song_id FROM songs ORDER BY RANDOM() LIMIT 1000")
    song_ids = [row[0] for row in cur.fetchall()]

playlist_song_data = []

for playlist_id, user_id in playlists:
    # 5-25 треков в плейлисте
    num_tracks = random.randint(5, 25)
    
    # ВАЖНО: random.sample из ВСЕГО списка song_ids
    if len(song_ids) >= num_tracks:
        selected_songs = random.sample(song_ids, num_tracks)
    else:
        selected_songs = random.choices(song_ids, k=num_tracks)  # с повторами, если песен мало
    
    for order, song_id in enumerate(selected_songs, 1):
        playlist_song_data.append((playlist_id, song_id, order))

# Вставка батчами
for i in range(0, len(playlist_song_data), 10000):
    batch = playlist_song_data[i:i+10000]
    execute_values(cur, """
        INSERT INTO playlist_song (playlist_id, song_id, order_number)
        VALUES %s
        ON CONFLICT DO NOTHING
    """, batch)
    conn.commit()

print(f"Generated {len(playlist_song_data)} playlist_song records")

print("Generating 1,000,000 history records...")

if not user_ids or not song_ids:
    print("ERROR: No users or songs to generate history!")
else:
    batch_size = 50000
    history = []
    
    for i in range(1000000):
        history.append((
            random.choice(user_ids),
            random.choice(song_ids),  # теперь берем из полного списка
            fake.date_time_between(start_date='-1y', end_date='now')
        ))
        
        if len(history) >= batch_size:
            execute_values(cur, """
                INSERT INTO listening_history (user_id, song_id, listened_at)
                VALUES %s
            """, history)
            conn.commit()
            history = []
            if (i + 1) % 200000 == 0:
                print(f"  Inserted {i+1}/1000000...")
    
    if history:
        execute_values(cur, """
            INSERT INTO listening_history (user_id, song_id, listened_at)
            VALUES %s
        """, history)
        conn.commit()

print("History generation complete")

print("\n" + "="*50)
print("📊 FINAL STATISTICS:")
print("="*50)

cur.execute("SELECT COUNT(*) FROM artists")
print(f"Artists: {cur.fetchone()[0]}")

cur.execute("SELECT COUNT(*) FROM albums")
print(f"Albums: {cur.fetchone()[0]}")

cur.execute("SELECT COUNT(*) FROM songs")
print(f"Songs: {cur.fetchone()[0]}")

cur.execute("SELECT COUNT(*) FROM song_artist")
print(f"Song-Artist links: {cur.fetchone()[0]}")

cur.execute("SELECT COUNT(*) FROM users")
print(f"Users: {cur.fetchone()[0]}")

cur.execute("SELECT COUNT(*) FROM playlists")
print(f"Playlists: {cur.fetchone()[0]}")

cur.execute("SELECT COUNT(*) FROM playlist_song")
print(f"Playlist-Song links: {cur.fetchone()[0]}")

cur.execute("SELECT COUNT(*) FROM listening_history")
print(f"History records: {cur.fetchone()[0]}")

# Проверка вариативности
cur.execute("""
    SELECT u.user_id, COUNT(p.playlist_id) as playlist_count 
    FROM users u 
    LEFT JOIN playlists p ON u.user_id = p.user_id 
    GROUP BY u.user_id 
    ORDER BY playlist_count DESC 
    LIMIT 5
""")
print("\n🎵 Top users by playlist count:")
for row in cur.fetchall():
    print(f"  User {row[0]}: {row[1]} playlists")

print("\n✅ DONE!")

cur.close()
conn.close()