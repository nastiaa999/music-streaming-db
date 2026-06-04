# Реляционная модель базы данных

Документ описывает реляционную схему базы данных музыкального стримингового сервиса. Модель спроектирована с учетом требований нормализации, бизнес-правил предметной области и оптимизации для выполнения аналитических запросов на больших объемах данных.

## Ключевые проектные решения

* **Суррогатные первичные ключи.** Для всех сущностей введены суррогатные ключи (`artist_id`, `song_id`, `user_id` и т.д.) вместо естественных. Это упрощает связи между таблицами, повышает производительность JOIN-операций и защищает схему от изменений бизнес-атрибутов (например, смены псевдонима артиста).
* **Разрешение связей M:N.** Связи «многие-ко-многим» вынесены в отдельные ассоциативные таблицы (`song_artist`, `playlist_song`) с добавлением собственных атрибутов связи.
* **Контролируемая денормализация.** Агрегированные метрики (`num_albums`, `num_songs`, `duration`) физически хранятся в таблицах. Это исключает необходимость выполнения ресурсоемких операций `COUNT()` и `SUM()` при чтении. Актуальность данных поддерживается автоматически на уровне СУБД.

---

## Схема таблиц

### Artists (Исполнители)
Хранит информацию об артистах и музыкальных группах.

| Column | Type | Key | Null | Default | Description |
|---|---|---|---|---|---|
| artist_id | SERIAL | PK | NOT NULL | | Суррогатный ключ |
| artist_nickname | VARCHAR(100) | Unique | NOT NULL | | Сценический псевдоним |
| artist_name | VARCHAR(100) | | NULL | NULL | Настоящее имя / название группы |
| birth_date | DATE | | NULL | NULL | Дата рождения или основания |
| country | VARCHAR(65) | | NULL | NULL | Страна происхождения |
| num_albums | INTEGER | | NOT NULL | 0 | Количество альбомов (вычисляемое) |
| num_songs | INTEGER | | NOT NULL | 0 | Количество треков (вычисляемое) |

### Albums (Альбомы)
Информация о музыкальных релизах.

| Column | Type | Key | Null | Default | Description |
|---|---|---|---|---|---|
| album_id | SERIAL | PK | NOT NULL | | Суррогатный ключ |
| artist_id | INTEGER | FK | NOT NULL | | Ссылка на artists (CASCADE) |
| album_name | VARCHAR(200) | | NOT NULL | | Название альбома |
| release_date | DATE | | NULL | NULL | Дата выпуска |
| duration | INTEGER | | NULL | NULL | Общая длительность в секундах |
| genre | VARCHAR(50) | | NULL | NULL | Основной жанр |
| num_songs | INTEGER | | NOT NULL | 0 | Количество треков (вычисляемое) |
| cover_image | VARCHAR(500) | | NULL | NULL | URL обложки |

### Songs (Треки)
Хранит данные о музыкальных композициях. Связь с альбомом опциональна для поддержки синглов.

| Column | Type | Key | Null | Default | Description |
|---|---|---|---|---|---|
| song_id | SERIAL | PK | NOT NULL | | Суррогатный ключ |
| album_id | INTEGER | FK | NULL | NULL | Ссылка на albums (SET NULL) |
| song_name | VARCHAR(200) | | NOT NULL | | Название трека |
| track_number | INTEGER | | NULL | NULL | Порядковый номер в альбоме |
| duration | INTEGER | | NOT NULL | | Длительность в секундах |
| release_date | DATE | | NULL | NULL | Дата выхода |
| lyrics | TEXT | | NULL | NULL | Текст песни |
| genre | VARCHAR(50) | | NULL | NULL | Жанр |

### Song Artist (Связь трека и исполнителя)
Ассоциативная таблица для реализации связи M:N. Позволяет указывать несколько исполнителей для одного трека.

| Column | Type | Key | Null | Default | Description |
|---|---|---|---|---|---|
| song_id | INTEGER | PK, FK | NOT NULL | | Ссылка на songs (CASCADE) |
| artist_id | INTEGER | PK, FK | NOT NULL | | Ссылка на artists (CASCADE) |
| is_featured | BOOLEAN | | NOT NULL | FALSE | Флаг приглашенного артиста (фит) |

### Users (Пользователи)
Данные зарегистрированных пользователей сервиса.

| Column | Type | Key | Null | Default | Description |
|---|---|---|---|---|---|
| user_id | SERIAL | PK | NOT NULL | | Суррогатный ключ |
| username | VARCHAR(50) | | NOT NULL | | Имя пользователя |
| email | VARCHAR(255) | Unique | NOT NULL | | Уникальный email |
| password_hash | VARCHAR(200) | | NOT NULL | | Хеш пароля |
| registration_date | TIMESTAMP | | NOT NULL | NOW() | Дата регистрации |
| is_premium | BOOLEAN | | NOT NULL | FALSE | Флаг премиум-подписки |
| birth_date | DATE | | NULL | NULL | Дата рождения |

### Playlists (Плейлисты)
Пользовательские подборки треков.

| Column | Type | Key | Null | Default | Description |
|---|---|---|---|---|---|
| playlist_id | SERIAL | PK | NOT NULL | | Суррогатный ключ |
| user_id | INTEGER | FK | NOT NULL | | Ссылка на users (CASCADE) |
| playlist_name | VARCHAR(200) | | NOT NULL | | Название плейлиста |
| duration | INTEGER | | NOT NULL | 0 | Общая длительность (вычисляемое) |
| num_songs | INTEGER | | NOT NULL | 0 | Количество треков (вычисляемое) |
| is_public | BOOLEAN | | NOT NULL | TRUE | Флаг публичного доступа |
| is_default | BOOLEAN | | NOT NULL | FALSE | Системный плейлист «Избранное» |

### Playlist Song (Связь плейлиста и трека)
Ассоциативная таблица для связи M:N с сохранением порядка воспроизведения.

| Column | Type | Key | Null | Default | Description |
|---|---|---|---|---|---|
| playlist_id | INTEGER | PK, FK | NOT NULL | | Ссылка на playlists (CASCADE) |
| song_id | INTEGER | PK, FK | NOT NULL | | Ссылка на songs (CASCADE) |
| order_number | INTEGER | | NOT NULL | | Позиция трека в плейлисте |

### Listening History (История прослушиваний)
Основная таблица для сбора аналитики. Фиксирует каждый факт прослушивания.

| Column | Type | Key | Null | Default | Description |
|---|---|---|---|---|---|
| history_id | SERIAL | PK | NOT NULL | | Суррогатный ключ |
| user_id | INTEGER | FK | NOT NULL | | Ссылка на users (CASCADE) |
| song_id | INTEGER | FK | NOT NULL | | Ссылка на songs (CASCADE) |
| listened_at | TIMESTAMP | | NOT NULL | NOW() | Временная метка прослушивания |

---

## Нормализация

Схема базы данных приведена к **четвертой нормальной форме (4НФ)**.
* **1НФ - 3НФ и БКНФ:** Все атрибуты атомарны, отсутствуют частичные и транзитивные зависимости. Все детерминанты нетривиальных функциональных зависимостей являются ключами-кандидатами.
* **4НФ:** Многозначные зависимости исключены путем вынесения связей M:N в ассоциативные таблицы (`song_artist`, `playlist_song`).

---

## Целостность данных и бизнес-логика

### Ограничения (Constraints)
* **Уникальность (UNIQUE):** Псевдонимы исполнителей, email пользователей, комбинация `(user_id, playlist_name)`, комбинация `(album_id, track_number)`.
* **Проверочные (CHECK):** Длительность треков и альбомов строго положительна. Даты релизов и рождения не могут находиться в будущем. Номер трека обязателен, если указана ссылка на альбом.
* **Ссылочная целостность:** Настроены каскадные удаления (`ON DELETE CASCADE`) для зависимых сущностей. При удалении альбома у треков `album_id` устанавливается в `NULL` (сохранение синглов).

### Триггеры (Triggers)
Для автоматизации бизнес-логики и поддержания денормализованных метрик на уровне СУБД реализованы следующие триггеры:
* **update_album_stats:** Пересчет `num_songs` и `duration` в таблице `albums` при INSERT/UPDATE/DELETE в `songs`.
* **update_artist_stats:** Обновление `num_albums` и `num_songs` в таблице `artists` при изменении `albums` и `song_artist`.
* **update_playlist_stats:** Пересчет `num_songs` и `duration` в таблице `playlists` при изменении состава `playlist_song`.
* **create_default_playlist:** Автоматическое создание системного плейлиста «Избранное» (`is_default = TRUE`) при регистрации нового пользователя (INSERT в `users`).