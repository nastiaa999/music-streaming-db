# Relational Model

## Переход от ER-модели к реляционной

В ER-модели сущности идентифицировались **естественными ключами**:

* исполнитель — по `artist_nickname`
* альбом — по `(artist, album_name)`
* трек — по `(artist, song_name)`

В реляционной модели для всех сущностей введены **суррогатные первичные ключи**:

* `artist_id`
* `album_id`
* `song_id`
* `user_id`
* `playlist_id`
* `history_id`

Это сделано для:

* упрощения связей между таблицами
* повышения производительности
* независимости схемы от изменений естественных атрибутов.

![Relational Diagram](diagrems/relational-diagram.png)

Связи между сущностями реализованы **через внешние ключи**.

Связи **многие-ко-многим (M:N)** преобразованы в отдельные таблицы:

| Связь           | Промежуточная таблица |
| --------------- | --------------------- |
| Song — Artist   | `song_artist`         |
| Playlist — Song | `playlist_song`       |

---

# Tables

## Artists

Хранит информацию об исполнителях.

| Column          | Type         | Key    | NULL     | Default | Description           |
| --------------- | ------------ | ------ | -------- | ------- | --------------------- |
| artist_id       | SERIAL       | PK     | NOT NULL |         | Суррогатный ключ      |
| artist_nickname | VARCHAR(100) | UNIQUE | NOT NULL |         | Сценический псевдоним |
| artist_name     | VARCHAR(100) |        | NULL     |         | Настоящее имя         |
| birth_date      | DATE         |        | NULL     |         | Дата рождения         |
| country         | VARCHAR(65)  |        | NULL     |         | Страна                |
| num_albums      | INTEGER      |        | NOT NULL | 0       | Количество альбомов   |
| num_songs       | INTEGER      |        | NOT NULL | 0       | Количество треков     |

Поля `num_albums` и `num_songs` используются для быстрого отображения статистики.

---

## Albums

Хранит информацию об альбомах.

| Column       | Type         | Key | NULL     | Default | Description         |
| ------------ | ------------ | --- | -------- | ------- | ------------------- |
| album_id     | SERIAL       | PK  | NOT NULL |         | Суррогатный ключ    |
| artist_id    | INTEGER      | FK  | NOT NULL |         | → artists.artist_id |
| album_name   | VARCHAR(200) |     | NOT NULL |         | Название альбома    |
| release_date | DATE         |     | NULL     |         | Дата выхода         |
| duration     | INTEGER      |     | NULL     |         | Длительность (сек)  |
| genre        | VARCHAR(50)  |     | NULL     |         | Жанр                |
| num_songs    | INTEGER      |     | NOT NULL | 0       | Количество треков   |

---

## Songs

Хранит информацию о музыкальных треках.

| Column       | Type         | Key | NULL     | Default | Description        |
| ------------ | ------------ | --- | -------- | ------- | ------------------ |
| song_id      | SERIAL       | PK  | NOT NULL |         | Суррогатный ключ   |
| album_id     | INTEGER      | FK  | NULL     |         | → albums.album_id  |
| song_name    | VARCHAR(200) |     | NOT NULL |         | Название трека     |
| track_number | INTEGER      |     | NULL     |         | Номер в альбоме    |
| duration     | INTEGER      |     | NOT NULL |         | Длительность (сек) |
| release_date | DATE         |     | NULL     |         | Дата выхода        |
| lyrics       | TEXT         |     | NULL     |         | Текст песни        |
| genre        | VARCHAR(50)  |     | NULL     |         | Жанр               |

`album_id` может быть `NULL`, так как трек может быть выпущен **как сингл**.

---

## Song Artist

Промежуточная таблица для связи **трека и исполнителя (M:N)**.

| Column      | Type    | Key    | NULL     | Default | Description         |
| ----------- | ------- | ------ | -------- | ------- | ------------------- |
| song_id     | INTEGER | PK, FK | NOT NULL |         | → songs.song_id     |
| artist_id   | INTEGER | PK, FK | NOT NULL |         | → artists.artist_id |
| is_featured | BOOLEAN |        | NOT NULL | FALSE   | Приглашенный артист |

Составной первичный ключ:

```
(song_id, artist_id)
```

Поле `is_featured` позволяет отличить **основного исполнителя** от **фита**.

---

## Users

Хранит информацию о пользователях сервиса.

| Column            | Type         | Key    | NULL     | Default | Description      |
| ----------------- | ------------ | ------ | -------- | ------- | ---------------- |
| user_id           | SERIAL       | PK     | NOT NULL |         | Суррогатный ключ |
| username          | VARCHAR(50)  | UNIQUE | NOT NULL |         | Имя пользователя |
| email             | VARCHAR(255) | UNIQUE | NOT NULL |         | Email            |
| password_hash     | VARCHAR(200) |        | NOT NULL |         | Хеш пароля       |
| registration_date | TIMESTAMP    |        | NOT NULL | NOW()   | Дата регистрации |
| is_premium        | BOOLEAN      |        | NOT NULL | FALSE   | Премиум подписка |

---

## Playlists

Плейлисты пользователей.

| Column        | Type         | Key | NULL     | Default | Description          |
| ------------- | ------------ | --- | -------- | ------- | -------------------- |
| playlist_id   | SERIAL       | PK  | NOT NULL |         | Суррогатный ключ     |
| user_id       | INTEGER      | FK  | NOT NULL |         | → users.user_id      |
| playlist_name | VARCHAR(200) |     | NOT NULL |         | Название             |
| duration      | INTEGER      |     | NOT NULL | 0       | Общая длительность   |
| num_songs     | INTEGER      |     | NOT NULL | 0       | Количество треков    |
| is_public     | BOOLEAN      |     | NOT NULL | TRUE    | Публичность          |
| is_default    | BOOLEAN      |     | NOT NULL | FALSE   | Плейлист «Избранное» |

Плейлист **«Избранное»** автоматически создаётся при регистрации пользователя.

---

## Playlist Song

Связь **плейлист — трек (M:N)**.

| Column       | Type    | Key    | NULL     | Default | Description             |
| ------------ | ------- | ------ | -------- | ------- | ----------------------- |
| playlist_id  | INTEGER | PK, FK | NOT NULL |         | → playlists.playlist_id |
| song_id      | INTEGER | PK, FK | NOT NULL |         | → songs.song_id         |
| order_number | INTEGER |        | NOT NULL |         | Порядок трека           |

Составной первичный ключ:

```
(playlist_id, song_id)
```

`order_number` определяет позицию трека в плейлисте.

---

## Listening History

История прослушивания треков пользователями.

| Column      | Type      | Key | NULL     | Default | Description         |
| ----------- | --------- | --- | -------- | ------- | ------------------- |
| history_id  | BIGSERIAL | PK  | NOT NULL |         | Суррогатный ключ    |
| user_id     | INTEGER   | FK  | NOT NULL |         | → users.user_id     |
| song_id     | INTEGER   | FK  | NOT NULL |         | → songs.song_id     |
| listened_at | TIMESTAMP |     | NOT NULL | NOW()   | Время прослушивания |

Таблица фиксирует **каждый факт прослушивания**.
Использование `BIGSERIAL` позволяет хранить **миллионы записей** без переполнения.
