-- =====================================================
-- NÜTZLICHE ABFRAGEN ZUM TESTEN
-- =====================================================

-- Alle User mit ihren Avataren
SELECT u.Username, u.Firstname, u.Surname, a.Avatar_name 
FROM USERS u 
JOIN AVATARS a ON u.Avatar_id = a.Avatar_id;

-- Alle genehmigten Kurse mit Fragenzahl
SELECT c.Course_name,  COUNT(q.Question_id) as question_count
FROM COURSES c 
LEFT JOIN QUESTIONS q ON c.Course_id = q.Course_id 
GROUP BY c.Course_id, c.Course_name;

-- Quiz-Ergebnisse eines Users
SELECT u.Username, g.Game_id, c.Course_name, 
       COUNT(ga.Game_answer_id) as total_answers,
       SUM(CASE WHEN ga.Right_wrong THEN 1 ELSE 0 END) as correct_answers
FROM USERS u
JOIN GAME_ANSWERS ga ON u.User_ID = ga.User_id
JOIN GAMES g ON ga.Game_id = g.Game_id
JOIN COURSES c ON g.Course_id = c.Course_id
WHERE u.User_ID = 31
GROUP BY u.Username, g.Game_id, c.Course_name;

-- Aktuelle Chat-Nachrichten eines Games
SELECT u.Username, c.Text, c.Time
FROM CHATS c
JOIN USERS u ON c.User_id = u.User_ID
WHERE c.Game_id = 1
ORDER BY c.Time;


-- ========================================================