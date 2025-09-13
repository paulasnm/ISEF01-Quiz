-- =====================================================
-- TRIGGER-FUNKTIONEN UND TRIGGER
-- =====================================================

-- ====================
-- 1. AUTO-UPDATE von Timestamps
-- ====================

-- Funktion für automatische Timestamp-Updates
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Füge updated_at Spalte zu relevanten Tabellen hinzu, da User eigene Daten verwalten können
-- und somit jederzeit den Namen oder E-Mail ändern können

 ALTER TABLE USERS ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
 
 CREATE TRIGGER users_update_timestamp 
 	BEFORE UPDATE ON USERS
    FOR EACH ROW 
	EXECUTE FUNCTION update_timestamp();

-- ====================
-- 2. GAME STATUS VALIDATION
-- ====================

-- Funktion zur Validierung von Game-Status-Übergängen
CREATE OR REPLACE FUNCTION validate_game_status_transition()
RETURNS TRIGGER AS $$
BEGIN
    -- Überprüfe gültige Status-Übergänge
    IF OLD.Status IS NOT NULL THEN
        -- Von 'waiting' zu 'active' oder 'finished'
        IF OLD.Status = 'waiting' AND NEW.Status NOT IN ('waiting', 'active', 'finished') THEN
            RAISE EXCEPTION 'Ungültiger Status-Übergang von % zu %', OLD.Status, NEW.Status;
        END IF;
        
        -- Von 'active' zu 'finished' oder bleibt 'active'
        IF OLD.Status = 'active' AND NEW.Status NOT IN ('active', 'finished') THEN
            RAISE EXCEPTION 'Ungültiger Status-Übergang von % zu %', OLD.Status, NEW.Status;
        END IF;
        
        -- Von 'finished' kann nicht mehr geändert werden
        IF OLD.Status = 'finished' AND NEW.Status != 'finished' THEN
            RAISE EXCEPTION 'Ein beendetes Spiel kann nicht reaktiviert werden';
        END IF;
    END IF;
    
    -- Setze Start_date automatisch wenn Status zu 'active' wechselt
    IF NEW.Status = 'active' AND OLD.Status != 'active' AND NEW.Start_date IS NULL THEN
        NEW.Start_date = CURRENT_TIMESTAMP;
    END IF;
    
    -- Setze Finish_date automatisch wenn Status zu 'finished' wechselt
    IF NEW.Status = 'finished' AND OLD.Status != 'finished' AND NEW.Finish_date IS NULL THEN
        NEW.Finish_date = CURRENT_TIMESTAMP;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER games_status_validation 
    BEFORE UPDATE ON GAMES
    FOR EACH ROW 
    EXECUTE FUNCTION validate_game_status_transition();

-- ====================
-- 3. QUESTION STATUS VALIDATION
-- ====================

-- Funktion zur Validierung von Question-Status und Check_date
CREATE OR REPLACE FUNCTION validate_question_status()
RETURNS TRIGGER AS $$
BEGIN
    -- Setze Check_date automatisch wenn Status geändert wird
    IF NEW.Status IN ('approved', 'rejected') AND OLD.Status = 'pending' THEN
        IF NEW.Check_date IS NULL THEN
            NEW.Check_date = CURRENT_TIMESTAMP;
        END IF;
        -- Überprüfe ob Admin zugewiesen ist
        IF NEW.Checked_by_AdminID IS NULL THEN
            RAISE EXCEPTION 'Ein Admin muss zugewiesen werden wenn der Status geändert wird';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER questions_status_validation 
    BEFORE UPDATE ON QUESTIONS
    FOR EACH ROW 
    EXECUTE FUNCTION validate_question_status();

-- ====================
-- 4. GAME_ANSWERS SCORING
-- ====================

-- Funktion zur automatischen Berechnung von Right_wrong basierend auf Answer
CREATE OR REPLACE FUNCTION calculate_game_answer_score()
RETURNS TRIGGER AS $$
DECLARE
    correct_answer BOOLEAN;
BEGIN
    -- Hole die Korrektheit der gewählten Antwort
    SELECT Right_wrong INTO correct_answer
    FROM ANSWERS 
    WHERE Answer_id = NEW.Answer_id;
    
    -- Setze Right_wrong entsprechend
    NEW.Right_wrong = correct_answer;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER game_answers_auto_score 
    BEFORE INSERT ON GAME_ANSWERS
    FOR EACH ROW 
    EXECUTE FUNCTION calculate_game_answer_score();

-- ====================
-- 5. SCORE UPDATE IN GAME_GROUPS
-- ====================

-- Funktion zur automatischen Score-Aktualisierung in GAME_GROUPS
CREATE OR REPLACE FUNCTION update_game_group_score()
RETURNS TRIGGER AS $$
DECLARE
    current_score INTEGER;
BEGIN
    -- Berechne den aktuellen Score für den User
    SELECT COALESCE(SUM(CASE WHEN ga.Right_wrong THEN 10 ELSE 0 END), 0)
    INTO current_score
    FROM GAME_ANSWERS ga
    JOIN GAMES g ON ga.Game_id = g.Game_id
    WHERE ga.User_id = NEW.User_id;
    
    -- Aktualisiere den Score in GAME_GROUPS
    UPDATE GAME_GROUPS 
    SET Score = current_score
    WHERE User_id = NEW.User_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_score_after_answer 
    AFTER INSERT ON GAME_ANSWERS
    FOR EACH ROW 
    EXECUTE FUNCTION update_game_group_score();

-- ====================
-- 6. PREVENT DUPLICATE ANSWERS
-- ====================

-- Funktion zur Verhinderung doppelter Antworten pro Runde
CREATE OR REPLACE FUNCTION prevent_duplicate_round_answers()
RETURNS TRIGGER AS $$
DECLARE
    existing_answer_count INTEGER;
BEGIN
    -- Prüfe ob bereits eine Antwort für diese Runde existiert
    SELECT COUNT(*) INTO existing_answer_count
    FROM GAME_ANSWERS
    WHERE Game_id = NEW.Game_id 
      AND User_id = NEW.User_id 
      AND Round_no = NEW.Round_no;
    
    IF existing_answer_count > 0 THEN
        RAISE EXCEPTION 'User % hat bereits eine Antwort für Runde % in Game % gegeben', 
            NEW.User_id, NEW.Round_no, NEW.Game_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevent_duplicate_answers 
    BEFORE INSERT ON GAME_ANSWERS
    FOR EACH ROW 
    EXECUTE FUNCTION prevent_duplicate_round_answers();

-- ====================
-- 7. LOGGING TRIGGER (Optional)
-- ====================

-- Audit-Tabelle für wichtige Änderungen (optional)
CREATE TABLE IF NOT EXISTS audit_log (
    log_id SERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    operation VARCHAR(10) NOT NULL,
    user_id INTEGER,
    old_values JSONB,
    new_values JSONB,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Funktion für Audit-Logging
CREATE OR REPLACE FUNCTION audit_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (table_name, operation, old_values)
        VALUES (TG_TABLE_NAME, TG_OP, row_to_json(OLD));
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (table_name, operation, old_values, new_values)
        VALUES (TG_TABLE_NAME, TG_OP, row_to_json(OLD), row_to_json(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (table_name, operation, new_values)
        VALUES (TG_TABLE_NAME, TG_OP, row_to_json(NEW));
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================================================
-- Audit-Trigger für kritische Tabellen (optional aktivierbar)
-- Umfassende Protokollierung wenn nachvollziehbar sein soll, wer was wann geändert hat,
-- bei Compliance-Anforderungen (DSGVO), bei sicherheitskritischen Anwendungen oder bei mehreren Admins
-- =====================================================================================================
-- CREATE TRIGGER audit_users AFTER INSERT OR UPDATE OR DELETE ON USERS
--     FOR EACH ROW EXECUTE FUNCTION audit_changes();

-- CREATE TRIGGER audit_questions AFTER INSERT OR UPDATE OR DELETE ON QUESTIONS
--     FOR EACH ROW EXECUTE FUNCTION audit_changes();


