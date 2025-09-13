-- =====================================================
-- INDIZES FÜR PERFORMANCE-OPTIMIERUNG
-- =====================================================

-- ====================
-- 1. USERS Tabelle - Häufige Suchkriterien
-- ====================
CREATE INDEX idx_users_username ON USERS(Username);
CREATE INDEX idx_users_email ON USERS(Email);
CREATE INDEX idx_users_registry_date ON USERS(Registry_date);
CREATE INDEX idx_users_avatar_id ON USERS(Avatar_id);

-- ====================
-- 2. QUESTIONS Tabelle - Wichtigste Abfragen
-- ====================
CREATE INDEX idx_questions_course_id ON QUESTIONS(Course_id);
CREATE INDEX idx_questions_made_by_userid ON QUESTIONS(Made_by_UserID);
CREATE INDEX idx_questions_checked_by_adminid ON QUESTIONS(Checked_by_AdminID);
CREATE INDEX idx_questions_status ON QUESTIONS(Status);
CREATE INDEX idx_questions_creation_date ON QUESTIONS(Creation_date);
-- Zusammengesetzter Index für häufige Kombinationen
CREATE INDEX idx_questions_course_status ON QUESTIONS(Course_id, Status);

-- ====================
-- 3. ANSWERS Tabelle
-- ====================
CREATE INDEX idx_answers_question_id ON ANSWERS(Question_id);
CREATE INDEX idx_answers_right_wrong ON ANSWERS(Right_wrong);

-- ====================
-- 4. GAMES Tabelle - Game-Management
-- ====================
CREATE INDEX idx_games_course_id ON GAMES(Course_id);
CREATE INDEX idx_games_user_id ON GAMES(User_id);
CREATE INDEX idx_games_status ON GAMES(Status);
CREATE INDEX idx_games_start_date ON GAMES(Start_date);
CREATE INDEX idx_games_finish_date ON GAMES(Finish_date);
-- Zusammengesetzter Index für aktive Spiele
CREATE INDEX idx_games_user_status ON GAMES(User_id, Status);

-- ====================
-- 5. GAME_ROUNDS Tabelle
-- ====================
CREATE INDEX idx_game_rounds_game_id ON GAME_ROUNDS(Game_id);
CREATE INDEX idx_game_rounds_question_id ON GAME_ROUNDS(Question_id);

-- ====================
-- 6. GAME_ANSWERS Tabelle - Performance-kritisch
-- ====================
CREATE INDEX idx_game_answers_game_id ON GAME_ANSWERS(Game_id);
CREATE INDEX idx_game_answers_user_id ON GAME_ANSWERS(User_id);
CREATE INDEX idx_game_answers_answer_id ON GAME_ANSWERS(Answer_id);
CREATE INDEX idx_game_answers_round_no ON GAME_ANSWERS(Round_no);
CREATE INDEX idx_game_answers_answered_at ON GAME_ANSWERS(Answered_at);
-- Zusammengesetzter Index für Statistiken
CREATE INDEX idx_game_answers_user_game ON GAME_ANSWERS(User_id, Game_id);

-- ====================
-- 7. GAME_GROUPS Tabelle
-- ====================
CREATE INDEX idx_game_groups_user_id ON GAME_GROUPS(User_id);
CREATE INDEX idx_game_groups_score ON GAME_GROUPS(Score);
CREATE INDEX idx_game_groups_joined_date ON GAME_GROUPS(Joined_date);

-- ====================
-- 8. CHATS Tabelle - Chat-Performance
-- ====================
CREATE INDEX idx_chats_user_id ON CHATS(User_id);
CREATE INDEX idx_chats_game_id ON CHATS(Game_id);
CREATE INDEX idx_chats_time ON CHATS(Time);
-- Zusammengesetzter Index für Game-Chats
CREATE INDEX idx_chats_game_time ON CHATS(Game_id, Time);

-- ====================
-- 9. COURSES Tabelle
-- ====================
CREATE INDEX idx_courses_creation_date ON COURSES(Creation_date);

-- ====================
-- 10. ADMINS Tabelle
-- ====================
CREATE INDEX idx_admins_username ON ADMINS(Username);
CREATE INDEX idx_admins_email ON ADMINS(Email);
