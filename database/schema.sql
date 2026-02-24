CREATE DATABASE IF NOT EXISTS quran
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE quran;

CREATE TABLE IF NOT EXISTS quran_ayahs (
    id INT UNSIGNED PRIMARY KEY,

    jozz TINYINT UNSIGNED NOT NULL,
    sura_no TINYINT UNSIGNED NOT NULL,
    aya_no SMALLINT UNSIGNED NOT NULL,

    sura_name_en VARCHAR(60) NOT NULL,
    sura_name_ar VARCHAR(60) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,

    page SMALLINT UNSIGNED NOT NULL,
    line_start SMALLINT UNSIGNED NOT NULL,
    line_end SMALLINT UNSIGNED NOT NULL,

    -- the mushaf glyph encoded text
    aya_text MEDIUMTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,

    -- searchable Arabic text
    aya_text_emlaey MEDIUMTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,

    INDEX idx_surah (sura_no),
    INDEX idx_surah_ayah (sura_no, aya_no),
    INDEX idx_page (page),
    FULLTEXT INDEX idx_search (aya_text_emlaey)
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_unicode_ci;
