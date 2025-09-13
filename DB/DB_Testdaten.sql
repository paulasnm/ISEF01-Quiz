-- ==================================
-- Testdaten für alle Tabellen
-- ==================================

INSERT INTO AVATARS (Avatar_name, Avatar_image_url) VALUES
('Pirat Pete', '/images/avatars/pirate_pete.png'),
('Kapitän Hook', '/images/avatars/captain_hook.png'),
('Schatzjäger Sam', '/images/avatars/treasure_hunter_sam.png'),
('Meerjungfrau Marina', '/images/avatars/mermaid_marina.png'),
('Papagei Polly', '/images/avatars/parrot_polly.png'),
('Navigator Nick', '/images/avatars/navigator_nick.png'),
('Piratin Ruby', '/images/avatars/pirate_ruby.png'),
('Matrose Max', '/images/avatars/sailor_max.png'),
('Inselkönig Leo', '/images/avatars/island_king_leo.png'),
('Schatzhüterin Luna', '/images/avatars/treasure_keeper_luna.png'),
('Avatar 1', '/avatar1.jpeg'),
('Avatar 2', '/avatar2.jpeg'),
('Avatar 3', '/avatar3.jpeg');


-- ========================================================
INSERT INTO USERS (Firstname, Surname, Username, Email, Password, Avatar_id,registry_date) VALUES
('Max', 'Mustermann', 'pirate_max', 'max@example.com', '$2b$12$hashedpassword1', 31, '2025-01-15 10:00:00'),
('Anna', 'Schmidt', 'treasure_anna', 'anna@example.com', '$2b$12$hashedpassword2', 32, '2025-01-10 10:00:00'),
('Tim', 'Weber', 'sailor_tim', 'tim@example.com', '$2b$12$hashedpassword3', 33, '2025-01-11 10:00:00'),
('Lisa', 'Müller', 'captain_lisa', 'lisa@example.com', '$2b$12$hashedpassword4', 34, '2025-03-15 10:00:00'),
('Ben', 'Fischer', 'navigator_ben', 'ben@example.com', '$2b$12$hashedpassword5',35, '2025-02-15 10:00:00'),
('Emma', 'Wagner', 'mermaid_emma', 'emma@example.com', '$2b$12$hashedpassword6', 36, '2025-02-19 10:00:00'),
('Paul', 'Becker', 'pirate_paul', 'paul@example.com', '$2b$12$hashedpassword7', 37, '2025-03-25 10:00:00'),
('Sarah', 'Schulz', 'treasure_sarah', 'sarah@example.com', '$2b$12$hashedpassword8', 38, '2025-04-15 10:00:00'),
('Tom', 'Hoffmann', 'sailor_tom', 'tom@example.com', '$2b$12$hashedpassword9', 39, '2025-05-25 10:00:00'),
('Nina', 'Klein', 'captain_nina', 'nina@example.com', '$2b$12$hashedpassword10', 40, '2025-02-09 10:00:00');


-- ========================================================
INSERT INTO ADMINS (Username, Email, Password) VALUES
('admin_captain', 'captain@treasure-island.com', '$2b$12$adminhashedpassword1'),
('admin_navigator', 'navigator@treasure-island.com', '$2b$12$adminhashedpassword2'),
('admin_treasure', 'treasure@treasure-island.com', '$2b$12$adminhashedpassword3'),
('admin_island', 'island@treasure-island.com', '$2b$12$adminhashedpassword4'),
('admin_pirate', 'pirate@treasure-island.com', '$2b$12$adminhashedpassword5'),
('admin_ocean', 'ocean@treasure-island.com', '$2b$12$adminhashedpassword6'),
('admin_ship', 'ship@treasure-island.com', '$2b$12$adminhashedpassword7'),
('admin_map', 'map@treasure-island.com', '$2b$12$adminhashedpassword8'),
('admin_compass', 'compass@treasure-island.com', '$2b$12$adminhashedpassword9'),
('admin_gold', 'gold@treasure-island.com', '$2b$12$adminhashedpassword10');


-- ========================================================
INSERT INTO COURSES (Course_name, Creation_date) VALUES
('Die Haifischbucht: Mathematik', '2024-01-15 10:00:00'),
('Piratenalgebra', '2024-01-20 11:30:00'),
('Schatzgeometrie', '2024-02-01 14:15:00'),
('Navigationsrechnung', '2024-02-10 09:45:00'),
('Münzzählerei', '2024-03-01 16:20:00'),
('Seefahrer-Statistik','2024-03-05 12:10:00'),
('Kanonen-Physik','2024-03-10 15:30:00'),
('Insel-Geografie', '2024-03-15 08:45:00'),
('Piratenkunde', '2024-03-20 13:25:00'),
('Schiffbau-Mathematik','2024-03-25 10:55:00');


-- ========================================================
INSERT INTO QUESTIONS (Course_id, Made_by_UserID, Checked_by_AdminID, Text, Explanation, Status, Check_date) VALUES
(1, 31, 11, 'Was ist 7 × 8?', 'Multiplikation: 7 mal 8 ergibt 56', 'approved', '2024-01-16 11:00:00'),
(1, 32, 11, 'Wie viel ist 15 + 23?', 'Addition: 15 plus 23 ergibt 38', 'approved', '2024-01-17 12:00:00'),
(2, 33, 12, 'Was ist x, wenn 2x + 5 = 15?', 'Lösung: 2x = 10, also x = 5', 'approved', '2024-01-22 14:30:00'),
(3, 34, 12, 'Wie viele Ecken hat ein Oktagon?', 'Ein Oktagon (Achteck) hat 8 Ecken', 'approved', '2024-02-02 10:15:00'),
(4, 35, 13, 'Was ist der Umfang eines Kreises mit Radius 5?', 'Umfang = 2πr = 2π × 5 = 10π ≈ 31,4', 'approved', '2024-02-12 15:45:00'),
(1, 36, 11, 'Was ist 144 ÷ 12?', 'Division: 144 geteilt durch 12 ergibt 12', 'pending', NULL),
(5, 37, NULL, 'Wie viele Goldmünzen sind 3 Säckchen à 25 Münzen?', 'Multiplikation: 3 × 25 = 75 Münzen', 'pending', NULL),
(6, 38, 14, 'Was ist der Mittelwert von 10, 20, 30?', 'Mittelwert = (10+20+30)/3 = 20', 'approved', '2024-03-07 09:30:00'),
(8, 39, 14, 'Welcher Ozean ist der größte?', 'Der Pazifische Ozean ist der größte Ozean der Erde', 'approved', '2024-03-17 11:20:00'),
(9, 40, 15, 'Wie hieß der berühmte Pirat Blackbeard richtig?', 'Edward Teach war der richtige Name von Blackbeard', 'approved', '2024-03-22 16:10:00');


-- ========================================================
INSERT INTO ANSWERS (Question_id, Text, Right_wrong) VALUES
-- Frage 1: Was ist 7 × 8?
(31, '56', true),
(31, '54', false),
(31, '58', false),
(31, '52', false),
-- Frage 2: Wie viel ist 15 + 23?
(32, '38', true),
(32, '35', false),
(32, '40', false),
(32, '33', false),
-- Frage 3: Was ist x, wenn 2x + 5 = 15?
(33, '5', true),
(33, '7', false),
(33, '10', false),
(33, '3', false),
-- Frage 4: Wie viele Ecken hat ein Oktagon?
(34, '8', true),
(34, '6', false),
(34, '10', false),
(34, '12', false),
-- Frage 5: Umfang eines Kreises mit Radius 5?
(35, '10π', true),
(35, '5π', false),
(35, '25π', false),
(35, '15π', false),
-- Frage 6: Was ist 144 ÷ 12?
(36, '12', true),
(36, '10', false),
(36, '14', false),
(36, '16', false),
-- Frage 7: 3 Säckchen à 25 Münzen?
(37, '75', true),
(37, '70', false),
(37, '80', false),
(37, '65', false),
-- Frage 8: Mittelwert von 10, 20, 30?
(38, '20', true),
(38, '15', false),
(38, '25', false),
(38, '18', false),
-- Frage 9: Welcher Ozean ist der größte?
(39, 'Pazifik', true),
(39, 'Atlantik', false),
(39, 'Indischer Ozean', false),
(39, 'Arktischer Ozean', false),
-- Frage 10: Blackbeards richtiger Name?
(40, 'Edward Teach', true),
(40, 'Henry Morgan', false),
(40, 'William Kidd', false),
(40, 'Bartholomew Roberts', false);


-- ========================================================
INSERT INTO GAME_GROUPS (User_id, Score, Joined_date) VALUES
(31, 85, '2024-03-01 14:30:00'),
(32, 92, '2024-03-01 14:32:00'),
(33, 78, '2024-03-01 14:35:00'),
(34, 88, '2024-03-02 15:20:00'),
(35, 95, '2024-03-02 15:22:00'),
(36, 82, '2024-03-02 15:25:00'),
(37, 91, '2024-03-03 16:10:00'),
(38, 76, '2024-03-03 16:12:00'),
(39, 89, '2024-03-03 16:15:00'),
(40, 93, '2024-03-04 10:45:00');


-- ========================================================
INSERT INTO GAMES (Course_id, User_id, Status, Start_date, Finish_date) VALUES
(1, 31, 'finished', '2024-03-01 14:30:00', '2024-03-01 14:45:00'),
(1, 32, 'finished', '2024-03-01 14:32:00', '2024-03-01 14:47:00'),
(2, 33, 'finished', '2024-03-02 15:20:00', '2024-03-02 15:35:00'),
(2, 34, 'active', '2024-03-04 10:30:00', NULL),
(3, 35, 'waiting', NULL, NULL),
(1, 36, 'finished', '2024-03-03 16:10:00', '2024-03-03 16:25:00'),
(4, 37, 'finished', '2024-03-03 11:20:00', '2024-03-03 11:35:00'),
(6, 38, 'active', '2024-03-04 09:15:00', NULL),
(8, 39, 'finished', '2024-03-02 13:45:00', '2024-03-02 14:00:00'),
(9, 40, 'waiting', NULL, NULL);

-- ========================================================
INSERT INTO GAME_ROUNDS (Game_id, Question_id) VALUES
-- Game 1 - 5 Runden
(1, 31), (1, 32), (1, 33), (1, 34), (1, 35),
-- Game 2 - 5 Runden  
(2, 31), (2, 32), (2, 36), (2, 38), (2, 39),
-- Game 3 - 5 Runden
(3, 33), (3, 34), (3, 35), (3, 31), (3, 32),
-- Game 6 - 5 Runden
(6, 31), (6, 32), (6, 36), (6, 38), (6, 40),
-- Game 7 - 5 Runden
(7, 35), (7, 38), (7, 39), (7, 40), (7, 31),
-- Game 9 - 5 Runden
(9, 39), (9, 40), (9, 38), (9, 31), (9, 32);


-- ========================================================
INSERT INTO GAME_ANSWERS (Game_id, User_id, Answer_id, Round_no, Right_wrong, Answered_at) VALUES
-- Game 1, User 1 Antworten
(1, 31, 41, 1, true, '2024-03-01 14:31:00'),   -- Richtige Antwort auf Frage 1
(1, 31, 45, 2, true, '2024-03-01 14:33:00'),   -- Richtige Antwort auf Frage 2
(1, 31, 50, 3, false, '2024-03-01 14:35:00'), -- Falsche Antwort auf Frage 3
(1, 31, 53, 4, true, '2024-03-01 14:37:00'),  -- Richtige Antwort auf Frage 4
(1, 31, 57, 5, true, '2024-03-01 14:39:00'),  -- Richtige Antwort auf Frage 5

-- Game 2, User 2 Antworten
(2, 32, 41, 1, true, '2024-03-01 14:33:00'),   -- Richtige Antwort
(2, 32, 45, 2, true, '2024-03-01 14:35:00'),   -- Richtige Antwort
(2, 32, 61, 3, true, '2024-03-01 14:37:00'),  -- Richtige Antwort
(2, 32, 69, 4, true, '2024-03-01 14:39:00'),  -- Richtige Antwort
(2, 32, 73, 5, true, '2024-03-01 14:41:00'),  -- Richtige Antwort

-- Game 3, User 3 Antworten
(3, 33, 49, 1, true, '2024-03-02 15:22:00'),
(3, 33, 54, 2, false, '2024-03-02 15:24:00'),
(3, 33, 57, 3, true, '2024-03-02 15:26:00'),
(3, 33, 42, 4, false, '2024-03-02 15:28:00'),
(3, 33, 46, 5, false, '2024-03-02 15:30:00'),

-- Game 6, User 6 Antworten
(6, 36, 41, 1, true, '2024-03-03 16:12:00'),
(6, 36, 46, 2, false, '2024-03-03 16:14:00'),
(6, 36, 61, 3, true, '2024-03-03 16:16:00'),
(6, 36, 69, 4, true, '2024-03-03 16:18:00'),
(6, 36, 77, 5, true, '2024-03-03 16:20:00'),

-- Game 7, User 7 Antworten
(7, 37, 57, 1, true, '2024-03-03 11:22:00'),
(7, 37, 69, 2, true, '2024-03-03 11:24:00'),
(7, 37, 73, 3, true, '2024-03-03 11:26:00'),
(7, 37, 77, 4, true, '2024-03-03 11:28:00'),
(7, 37, 42, 5, false, '2024-03-03 11:30:00'),

-- Game 9, User 9 Antworten
(9, 39, 73, 1, true, '2024-03-02 13:47:00'),
(9, 39, 77, 2, true, '2024-03-02 13:49:00'),
(9, 39, 70, 3, false, '2024-03-02 13:51:00'),
(9, 39, 41, 4, true, '2024-03-02 13:53:00'),
(9, 39, 45, 5, true, '2024-03-02 13:55:00');

-- ========================================================
INSERT INTO CHATS (User_id, Game_id, Text, Time) VALUES
(31, 1, 'Ahoi Matrosen! Bereit für das Quiz?', '2024-03-01 14:31:00'),
(32, 1, 'Aye aye! Lasst uns die Schätze des Wissens heben!', '2024-03-01 14:32:00'),
(31, 1, 'Die Mathematik-Fragen sind heute schwer...', '2024-03-01 14:34:00'),
(32, 1, 'Bei der Algebra-Frage bin ich mir unsicher', '2024-03-01 14:36:00'),
(33, 3, 'Geometrie ist wie Navigation - man braucht die richtigen Winkel!', '2024-03-02 15:23:00'),
(34, 3, 'Stimmt! Die Oktagon-Frage war clever', '2024-03-02 15:25:00'),
(36, 6, 'Diese Runde läuft gut für mich!', '2024-03-03 16:13:00'),
(37, 7, 'Statistik auf hoher See - interessant!', '2024-03-03 11:23:00'),
(39, 9, 'Geografische Fragen sind mein Spezialgebiet', '2024-03-02 13:48:00'),
(40, 6, 'Blackbeard-Trivia am Ende - perfekt!', '2024-03-03 16:21:00');