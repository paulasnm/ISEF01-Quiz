-- =====================================================
-- SCHATZINSEL LERN-QUIZ - PostgreSQL Datenbank
-- =====================================================

-- Datenbank erstellen (optional)
-- CREATE DATABASE Schatzinsel;

-- ====================
-- 1. AVATARS Tabelle
-- ====================
CREATE TABLE AVATARS (
    Avatar_id SERIAL PRIMARY KEY,
    Avatar_name VARCHAR(50) NOT NULL,
    Avatar_image_url VARCHAR(255) NOT NULL
);


-- ====================
-- 2. USERS Tabelle
-- ====================
CREATE TABLE USERS (
    User_ID SERIAL PRIMARY KEY,
    Firstname VARCHAR(50) NOT NULL,
    Surname VARCHAR(50) NOT NULL,
    Username VARCHAR(30) UNIQUE NOT NULL,
    Email VARCHAR(100) UNIQUE NOT NULL,
    Password VARCHAR(255) NOT NULL,
    Avatar_id INTEGER REFERENCES AVATARS(Avatar_id),
    Registry_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ====================
-- 3. ADMINS Tabelle
-- ====================
CREATE TABLE ADMINS (
    Admin_id SERIAL PRIMARY KEY,
    Username VARCHAR(30) UNIQUE NOT NULL,
    Email VARCHAR(100) UNIQUE NOT NULL,
    Password VARCHAR(255) NOT NULL
);

-- ====================
-- 4. COURSES Tabelle
-- ====================
CREATE TABLE COURSES (
    Course_id SERIAL PRIMARY KEY,
    Course_name VARCHAR(100) NOT NULL,
    Creation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ====================
-- 5. QUESTIONS Tabelle
-- ====================
CREATE TABLE QUESTIONS (
    Question_id SERIAL PRIMARY KEY,
    Course_id INTEGER REFERENCES COURSES(Course_id),
    Made_by_UserID INTEGER REFERENCES USERS(User_ID),
    Checked_by_AdminID INTEGER REFERENCES ADMINS(Admin_id),
    Creation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    Check_date TIMESTAMP,
    Text TEXT NOT NULL,
    Explanation TEXT,
    Status VARCHAR(20) DEFAULT 'pending' CHECK (Status IN ('pending', 'approved', 'rejected'))
);

-- ====================
-- 6. ANSWERS Tabelle
-- ====================
CREATE TABLE ANSWERS (
    Answer_id SERIAL PRIMARY KEY,
    Question_id INTEGER REFERENCES QUESTIONS(Question_id),
    Text VARCHAR(255) NOT NULL,
    Right_wrong BOOLEAN NOT NULL
);

-- ====================
-- 7. GAME_GROUPS Tabelle
-- ====================
CREATE TABLE GAME_GROUPS (
    Game_id SERIAL PRIMARY KEY,
    User_id INTEGER REFERENCES USERS(User_ID),
    Score INTEGER DEFAULT 0,
    Joined_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ====================
-- 8. GAMES Tabelle
-- ====================
CREATE TABLE GAMES (
    Game_id SERIAL PRIMARY KEY,
    Course_id INTEGER REFERENCES COURSES(Course_id),
    User_id INTEGER REFERENCES USERS(User_ID),
    Status VARCHAR(20) DEFAULT 'waiting' CHECK (Status IN ('waiting', 'active', 'finished')),
    Start_date TIMESTAMP,
    Finish_date TIMESTAMP
);

-- ====================
-- 9. GAME_ROUNDS Tabelle
-- ====================
CREATE TABLE GAME_ROUNDS (
    Round_no SERIAL PRIMARY KEY,
    Game_id INTEGER REFERENCES GAMES(Game_id),
    Question_id INTEGER REFERENCES QUESTIONS(Question_id)
);

-- ====================
-- 10. GAME_ANSWERS Tabelle
-- ====================
CREATE TABLE GAME_ANSWERS (
    Game_answer_id SERIAL PRIMARY KEY,
    Game_id INTEGER REFERENCES GAMES(Game_id),
    User_id INTEGER REFERENCES USERS(User_ID),
    Answer_id INTEGER REFERENCES ANSWERS(Answer_id),
    Round_no INTEGER,
    Right_wrong BOOLEAN NOT NULL,
    Answered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ====================
-- 11. CHATS Tabelle
-- ====================
CREATE TABLE CHATS (
    Chat_id SERIAL PRIMARY KEY,
    User_id INTEGER REFERENCES USERS(User_ID),
    Game_id INTEGER REFERENCES GAMES(Game_id),
    Text TEXT NOT NULL,
    Time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- =====================================================
-- ENDE DER DATENBANKSTRUKTUR
-- =====================================================