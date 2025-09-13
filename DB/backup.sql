--
-- PostgreSQL database dump
--

\restrict HqzSFEJmLuTBEHFCuUrmNgFLEi8cv9oHWoWacfedaTatmXr34gdIqfdLfV2eJCE

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: audit_changes(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.audit_changes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.audit_changes() OWNER TO postgres;

--
-- Name: calculate_game_answer_score(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.calculate_game_answer_score() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.calculate_game_answer_score() OWNER TO postgres;

--
-- Name: check_index_usage(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_index_usage() RETURNS TABLE(schemaname text, tablename text, indexname text, num_rows bigint, table_size text, index_size text, unique_index boolean, number_of_scans bigint, tuples_read bigint, tuples_fetched bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.schemaname::TEXT,
        t.relname::TEXT,
        s.indexrelname::TEXT,  -- Korrigiert: indexrelname statt indexname
        t.reltuples::BIGINT,
        pg_size_pretty(pg_total_relation_size(t.oid))::TEXT,
        pg_size_pretty(pg_total_relation_size(i.indexrelid))::TEXT,
        i.indisunique,
        s.idx_scan,
        s.idx_tup_read,
        s.idx_tup_fetch
    FROM pg_stat_user_indexes s
    JOIN pg_index i ON s.indexrelid = i.indexrelid
    JOIN pg_class t ON i.indrelid = t.oid
    WHERE s.schemaname = 'public'
    ORDER BY s.idx_scan ASC;
END;
$$;


ALTER FUNCTION public.check_index_usage() OWNER TO postgres;

--
-- Name: get_table_stats(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_table_stats() RETURNS TABLE(table_name text, row_count bigint, table_size text, index_size text, total_size text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.relname::TEXT,
        c.reltuples::BIGINT,
        pg_size_pretty(pg_total_relation_size(c.oid) - pg_indexes_size(c.oid))::TEXT,
        pg_size_pretty(pg_indexes_size(c.oid))::TEXT,
        pg_size_pretty(pg_total_relation_size(c.oid))::TEXT
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'r' 
      AND n.nspname = 'public'
    ORDER BY pg_total_relation_size(c.oid) DESC;
END;
$$;


ALTER FUNCTION public.get_table_stats() OWNER TO postgres;

--
-- Name: prevent_duplicate_round_answers(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.prevent_duplicate_round_answers() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.prevent_duplicate_round_answers() OWNER TO postgres;

--
-- Name: update_game_group_score(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_game_group_score() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.update_game_group_score() OWNER TO postgres;

--
-- Name: update_timestamp(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_timestamp() OWNER TO postgres;

--
-- Name: validate_game_status_transition(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.validate_game_status_transition() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.validate_game_status_transition() OWNER TO postgres;

--
-- Name: validate_question_status(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.validate_question_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.validate_question_status() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: admins; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.admins (
    admin_id integer NOT NULL,
    username character varying(30) NOT NULL,
    email character varying(100) NOT NULL,
    password character varying(255) NOT NULL
);


ALTER TABLE public.admins OWNER TO postgres;

--
-- Name: admins_admin_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.admins_admin_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.admins_admin_id_seq OWNER TO postgres;

--
-- Name: admins_admin_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.admins_admin_id_seq OWNED BY public.admins.admin_id;


--
-- Name: answers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.answers (
    answer_id integer NOT NULL,
    question_id integer,
    text character varying(255) NOT NULL,
    right_wrong boolean NOT NULL
);


ALTER TABLE public.answers OWNER TO postgres;

--
-- Name: answers_answer_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.answers_answer_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.answers_answer_id_seq OWNER TO postgres;

--
-- Name: answers_answer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.answers_answer_id_seq OWNED BY public.answers.answer_id;


--
-- Name: audit_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.audit_log (
    log_id integer NOT NULL,
    table_name character varying(50) NOT NULL,
    operation character varying(10) NOT NULL,
    user_id integer,
    old_values jsonb,
    new_values jsonb,
    "timestamp" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.audit_log OWNER TO postgres;

--
-- Name: audit_log_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.audit_log_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.audit_log_log_id_seq OWNER TO postgres;

--
-- Name: audit_log_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.audit_log_log_id_seq OWNED BY public.audit_log.log_id;


--
-- Name: avatars; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.avatars (
    avatar_id integer NOT NULL,
    avatar_name character varying(50) NOT NULL,
    avatar_image_url character varying(255) NOT NULL
);


ALTER TABLE public.avatars OWNER TO postgres;

--
-- Name: avatars_avatar_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.avatars_avatar_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.avatars_avatar_id_seq OWNER TO postgres;

--
-- Name: avatars_avatar_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.avatars_avatar_id_seq OWNED BY public.avatars.avatar_id;


--
-- Name: chats; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.chats (
    chat_id integer NOT NULL,
    user_id integer,
    game_id integer,
    text text NOT NULL,
    "time" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.chats OWNER TO postgres;

--
-- Name: chats_chat_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.chats_chat_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.chats_chat_id_seq OWNER TO postgres;

--
-- Name: chats_chat_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.chats_chat_id_seq OWNED BY public.chats.chat_id;


--
-- Name: courses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.courses (
    course_id integer NOT NULL,
    course_name character varying(100) NOT NULL,
    creation_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.courses OWNER TO postgres;

--
-- Name: courses_course_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.courses_course_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.courses_course_id_seq OWNER TO postgres;

--
-- Name: courses_course_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.courses_course_id_seq OWNED BY public.courses.course_id;


--
-- Name: game_answers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.game_answers (
    game_answer_id integer NOT NULL,
    game_id integer,
    user_id integer,
    answer_id integer,
    round_no integer,
    right_wrong boolean NOT NULL,
    answered_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.game_answers OWNER TO postgres;

--
-- Name: game_answers_game_answer_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.game_answers_game_answer_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.game_answers_game_answer_id_seq OWNER TO postgres;

--
-- Name: game_answers_game_answer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.game_answers_game_answer_id_seq OWNED BY public.game_answers.game_answer_id;


--
-- Name: game_groups; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.game_groups (
    game_id integer NOT NULL,
    user_id integer,
    score integer DEFAULT 0,
    joined_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.game_groups OWNER TO postgres;

--
-- Name: game_groups_game_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.game_groups_game_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.game_groups_game_id_seq OWNER TO postgres;

--
-- Name: game_groups_game_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.game_groups_game_id_seq OWNED BY public.game_groups.game_id;


--
-- Name: game_rounds; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.game_rounds (
    round_no integer NOT NULL,
    game_id integer,
    question_id integer
);


ALTER TABLE public.game_rounds OWNER TO postgres;

--
-- Name: game_rounds_round_no_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.game_rounds_round_no_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.game_rounds_round_no_seq OWNER TO postgres;

--
-- Name: game_rounds_round_no_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.game_rounds_round_no_seq OWNED BY public.game_rounds.round_no;


--
-- Name: games; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.games (
    game_id integer NOT NULL,
    course_id integer,
    user_id integer,
    status character varying(20) DEFAULT 'waiting'::character varying,
    start_date timestamp without time zone,
    finish_date timestamp without time zone,
    CONSTRAINT games_status_check CHECK (((status)::text = ANY ((ARRAY['waiting'::character varying, 'active'::character varying, 'finished'::character varying])::text[])))
);


ALTER TABLE public.games OWNER TO postgres;

--
-- Name: games_game_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.games_game_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.games_game_id_seq OWNER TO postgres;

--
-- Name: games_game_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.games_game_id_seq OWNED BY public.games.game_id;


--
-- Name: questions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.questions (
    question_id integer NOT NULL,
    course_id integer,
    made_by_userid integer,
    checked_by_adminid integer,
    creation_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    check_date timestamp without time zone,
    text text NOT NULL,
    explanation text,
    status character varying(20) DEFAULT 'pending'::character varying,
    CONSTRAINT questions_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying])::text[])))
);


ALTER TABLE public.questions OWNER TO postgres;

--
-- Name: questions_question_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.questions_question_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.questions_question_id_seq OWNER TO postgres;

--
-- Name: questions_question_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.questions_question_id_seq OWNED BY public.questions.question_id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    user_id integer NOT NULL,
    firstname character varying(50) NOT NULL,
    surname character varying(50) NOT NULL,
    username character varying(30) NOT NULL,
    email character varying(100) NOT NULL,
    password character varying(255) NOT NULL,
    avatar_id integer,
    registry_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: users_user_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_user_id_seq OWNER TO postgres;

--
-- Name: users_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_user_id_seq OWNED BY public.users.user_id;


--
-- Name: admins admin_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admins ALTER COLUMN admin_id SET DEFAULT nextval('public.admins_admin_id_seq'::regclass);


--
-- Name: answers answer_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.answers ALTER COLUMN answer_id SET DEFAULT nextval('public.answers_answer_id_seq'::regclass);


--
-- Name: audit_log log_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_log ALTER COLUMN log_id SET DEFAULT nextval('public.audit_log_log_id_seq'::regclass);


--
-- Name: avatars avatar_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.avatars ALTER COLUMN avatar_id SET DEFAULT nextval('public.avatars_avatar_id_seq'::regclass);


--
-- Name: chats chat_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chats ALTER COLUMN chat_id SET DEFAULT nextval('public.chats_chat_id_seq'::regclass);


--
-- Name: courses course_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.courses ALTER COLUMN course_id SET DEFAULT nextval('public.courses_course_id_seq'::regclass);


--
-- Name: game_answers game_answer_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.game_answers ALTER COLUMN game_answer_id SET DEFAULT nextval('public.game_answers_game_answer_id_seq'::regclass);


--
-- Name: game_groups game_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.game_groups ALTER COLUMN game_id SET DEFAULT nextval('public.game_groups_game_id_seq'::regclass);


--
-- Name: game_rounds round_no; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.game_rounds ALTER COLUMN round_no SET DEFAULT nextval('public.game_rounds_round_no_seq'::regclass);


--
-- Name: games game_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.games ALTER COLUMN game_id SET DEFAULT nextval('public.games_game_id_seq'::regclass);


--
-- Name: questions question_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.questions ALTER COLUMN question_id SET DEFAULT nextval('public.questions_question_id_seq'::regclass);


--
-- Name: users user_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN user_id SET DEFAULT nextval('public.users_user_id_seq'::regclass);


--
-- Data for Name: admins; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.admins (admin_id, username, email, password) FROM stdin;
11	admin_captain	captain@treasure-island.com	$2b$12$adminhashedpassword1
12	admin_navigator	navigator@treasure-island.com	$2b$12$adminhashedpassword2
13	admin_treasure	treasure@treasure-island.com	$2b$12$adminhashedpassword3
14	admin_island	island@treasure-island.com	$2b$12$adminhashedpassword4
15	admin_pirate	pirate@treasure-island.com	$2b$12$adminhashedpassword5
16	admin_ocean	ocean@treasure-island.com	$2b$12$adminhashedpassword6
17	admin_ship	ship@treasure-island.com	$2b$12$adminhashedpassword7
18	admin_map	map@treasure-island.com	$2b$12$adminhashedpassword8
19	admin_compass	compass@treasure-island.com	$2b$12$adminhashedpassword9
20	admin_gold	gold@treasure-island.com	$2b$12$adminhashedpassword10
\.


--
-- Data for Name: answers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.answers (answer_id, question_id, text, right_wrong) FROM stdin;
41	31	56	t
42	31	54	f
43	31	58	f
44	31	52	f
45	32	38	t
46	32	35	f
47	32	40	f
48	32	33	f
49	33	5	t
50	33	7	f
51	33	10	f
52	33	3	f
53	34	8	t
54	34	6	f
55	34	10	f
56	34	12	f
57	35	10π	t
58	35	5π	f
59	35	25π	f
60	35	15π	f
61	36	12	t
62	36	10	f
63	36	14	f
64	36	16	f
65	37	75	t
66	37	70	f
67	37	80	f
68	37	65	f
69	38	20	t
70	38	15	f
71	38	25	f
72	38	18	f
73	39	Pazifik	t
74	39	Atlantik	f
75	39	Indischer Ozean	f
76	39	Arktischer Ozean	f
77	40	Edward Teach	t
78	40	Henry Morgan	f
79	40	William Kidd	f
80	40	Bartholomew Roberts	f
\.


--
-- Data for Name: audit_log; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.audit_log (log_id, table_name, operation, user_id, old_values, new_values, "timestamp") FROM stdin;
\.


--
-- Data for Name: avatars; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.avatars (avatar_id, avatar_name, avatar_image_url) FROM stdin;
31	Pirat Pete	/images/avatars/pirate_pete.png
32	Kapitän Hook	/images/avatars/captain_hook.png
33	Schatzjäger Sam	/images/avatars/treasure_hunter_sam.png
34	Meerjungfrau Marina	/images/avatars/mermaid_marina.png
35	Papagei Polly	/images/avatars/parrot_polly.png
36	Navigator Nick	/images/avatars/navigator_nick.png
37	Piratin Ruby	/images/avatars/pirate_ruby.png
38	Matrose Max	/images/avatars/sailor_max.png
39	Inselkönig Leo	/images/avatars/island_king_leo.png
40	Schatzhüterin Luna	/images/avatars/treasure_keeper_luna.png
\.


--
-- Data for Name: chats; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.chats (chat_id, user_id, game_id, text, "time") FROM stdin;
1	31	1	Ahoi Matrosen! Bereit für das Quiz?	2024-03-01 14:31:00
2	32	1	Aye aye! Lasst uns die Schätze des Wissens heben!	2024-03-01 14:32:00
3	31	1	Die Mathematik-Fragen sind heute schwer...	2024-03-01 14:34:00
4	32	1	Bei der Algebra-Frage bin ich mir unsicher	2024-03-01 14:36:00
5	33	3	Geometrie ist wie Navigation - man braucht die richtigen Winkel!	2024-03-02 15:23:00
6	34	3	Stimmt! Die Oktagon-Frage war clever	2024-03-02 15:25:00
7	36	6	Diese Runde läuft gut für mich!	2024-03-03 16:13:00
8	37	7	Statistik auf hoher See - interessant!	2024-03-03 11:23:00
9	39	9	Geografische Fragen sind mein Spezialgebiet	2024-03-02 13:48:00
10	40	6	Blackbeard-Trivia am Ende - perfekt!	2024-03-03 16:21:00
\.


--
-- Data for Name: courses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.courses (course_id, course_name, creation_date) FROM stdin;
1	Die Haifischbucht: Mathematik	2024-01-15 10:00:00
2	Piratenalgebra	2024-01-20 11:30:00
3	Schatzgeometrie	2024-02-01 14:15:00
4	Navigationsrechnung	2024-02-10 09:45:00
5	Münzzählerei	2024-03-01 16:20:00
6	Seefahrer-Statistik	2024-03-05 12:10:00
7	Kanonen-Physik	2024-03-10 15:30:00
8	Insel-Geografie	2024-03-15 08:45:00
9	Piratenkunde	2024-03-20 13:25:00
10	Schiffbau-Mathematik	2024-03-25 10:55:00
\.


--
-- Data for Name: game_answers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.game_answers (game_answer_id, game_id, user_id, answer_id, round_no, right_wrong, answered_at) FROM stdin;
1	1	31	41	1	t	2024-03-01 14:31:00
2	1	31	45	2	t	2024-03-01 14:33:00
3	1	31	50	3	f	2024-03-01 14:35:00
4	1	31	53	4	t	2024-03-01 14:37:00
5	1	31	57	5	t	2024-03-01 14:39:00
6	2	32	41	1	t	2024-03-01 14:33:00
7	2	32	45	2	t	2024-03-01 14:35:00
8	2	32	61	3	t	2024-03-01 14:37:00
9	2	32	69	4	t	2024-03-01 14:39:00
10	2	32	73	5	t	2024-03-01 14:41:00
11	3	33	49	1	t	2024-03-02 15:22:00
12	3	33	54	2	f	2024-03-02 15:24:00
13	3	33	57	3	t	2024-03-02 15:26:00
14	3	33	42	4	f	2024-03-02 15:28:00
15	3	33	46	5	f	2024-03-02 15:30:00
16	6	36	41	1	t	2024-03-03 16:12:00
17	6	36	46	2	f	2024-03-03 16:14:00
18	6	36	61	3	t	2024-03-03 16:16:00
19	6	36	69	4	t	2024-03-03 16:18:00
20	6	36	77	5	t	2024-03-03 16:20:00
21	7	37	57	1	t	2024-03-03 11:22:00
22	7	37	69	2	t	2024-03-03 11:24:00
23	7	37	73	3	t	2024-03-03 11:26:00
24	7	37	77	4	t	2024-03-03 11:28:00
25	7	37	42	5	f	2024-03-03 11:30:00
26	9	39	73	1	t	2024-03-02 13:47:00
27	9	39	77	2	t	2024-03-02 13:49:00
28	9	39	70	3	f	2024-03-02 13:51:00
29	9	39	41	4	t	2024-03-02 13:53:00
30	9	39	45	5	t	2024-03-02 13:55:00
\.


--
-- Data for Name: game_groups; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.game_groups (game_id, user_id, score, joined_date) FROM stdin;
1	31	85	2024-03-01 14:30:00
2	32	92	2024-03-01 14:32:00
3	33	78	2024-03-01 14:35:00
4	34	88	2024-03-02 15:20:00
5	35	95	2024-03-02 15:22:00
6	36	82	2024-03-02 15:25:00
7	37	91	2024-03-03 16:10:00
8	38	76	2024-03-03 16:12:00
9	39	89	2024-03-03 16:15:00
10	40	93	2024-03-04 10:45:00
\.


--
-- Data for Name: game_rounds; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.game_rounds (round_no, game_id, question_id) FROM stdin;
1	1	31
2	1	32
3	1	33
4	1	34
5	1	35
6	2	31
7	2	32
8	2	36
9	2	38
10	2	39
11	3	33
12	3	34
13	3	35
14	3	31
15	3	32
16	6	31
17	6	32
18	6	36
19	6	38
20	6	40
21	7	35
22	7	38
23	7	39
24	7	40
25	7	31
26	9	39
27	9	40
28	9	38
29	9	31
30	9	32
\.


--
-- Data for Name: games; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.games (game_id, course_id, user_id, status, start_date, finish_date) FROM stdin;
1	1	31	finished	2024-03-01 14:30:00	2024-03-01 14:45:00
2	1	32	finished	2024-03-01 14:32:00	2024-03-01 14:47:00
3	2	33	finished	2024-03-02 15:20:00	2024-03-02 15:35:00
4	2	34	active	2024-03-04 10:30:00	\N
5	3	35	waiting	\N	\N
6	1	36	finished	2024-03-03 16:10:00	2024-03-03 16:25:00
7	4	37	finished	2024-03-03 11:20:00	2024-03-03 11:35:00
8	6	38	active	2024-03-04 09:15:00	\N
9	8	39	finished	2024-03-02 13:45:00	2024-03-02 14:00:00
10	9	40	waiting	\N	\N
\.


--
-- Data for Name: questions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.questions (question_id, course_id, made_by_userid, checked_by_adminid, creation_date, check_date, text, explanation, status) FROM stdin;
31	1	31	11	2025-09-03 19:02:47.481957	2024-01-16 11:00:00	Was ist 7 × 8?	Multiplikation: 7 mal 8 ergibt 56	approved
32	1	32	11	2025-09-03 19:02:47.481957	2024-01-17 12:00:00	Wie viel ist 15 + 23?	Addition: 15 plus 23 ergibt 38	approved
33	2	33	12	2025-09-03 19:02:47.481957	2024-01-22 14:30:00	Was ist x, wenn 2x + 5 = 15?	Lösung: 2x = 10, also x = 5	approved
34	3	34	12	2025-09-03 19:02:47.481957	2024-02-02 10:15:00	Wie viele Ecken hat ein Oktagon?	Ein Oktagon (Achteck) hat 8 Ecken	approved
35	4	35	13	2025-09-03 19:02:47.481957	2024-02-12 15:45:00	Was ist der Umfang eines Kreises mit Radius 5?	Umfang = 2πr = 2π × 5 = 10π ≈ 31,4	approved
36	1	36	11	2025-09-03 19:02:47.481957	\N	Was ist 144 ÷ 12?	Division: 144 geteilt durch 12 ergibt 12	pending
37	5	37	\N	2025-09-03 19:02:47.481957	\N	Wie viele Goldmünzen sind 3 Säckchen à 25 Münzen?	Multiplikation: 3 × 25 = 75 Münzen	pending
38	6	38	14	2025-09-03 19:02:47.481957	2024-03-07 09:30:00	Was ist der Mittelwert von 10, 20, 30?	Mittelwert = (10+20+30)/3 = 20	approved
39	8	39	14	2025-09-03 19:02:47.481957	2024-03-17 11:20:00	Welcher Ozean ist der größte?	Der Pazifische Ozean ist der größte Ozean der Erde	approved
40	9	40	15	2025-09-03 19:02:47.481957	2024-03-22 16:10:00	Wie hieß der berühmte Pirat Blackbeard richtig?	Edward Teach war der richtige Name von Blackbeard	approved
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (user_id, firstname, surname, username, email, password, avatar_id, registry_date, updated_at) FROM stdin;
31	Max	Mustermann	pirate_max	max@example.com	$2b$12$hashedpassword1	31	2025-01-15 10:00:00	2025-09-11 23:04:18.445134
32	Anna	Schmidt	treasure_anna	anna@example.com	$2b$12$hashedpassword2	32	2025-01-10 10:00:00	2025-09-11 23:04:18.445134
33	Tim	Weber	sailor_tim	tim@example.com	$2b$12$hashedpassword3	33	2025-01-11 10:00:00	2025-09-11 23:04:18.445134
34	Lisa	Müller	captain_lisa	lisa@example.com	$2b$12$hashedpassword4	34	2025-03-15 10:00:00	2025-09-11 23:04:18.445134
35	Ben	Fischer	navigator_ben	ben@example.com	$2b$12$hashedpassword5	35	2025-02-15 10:00:00	2025-09-11 23:04:18.445134
36	Emma	Wagner	mermaid_emma	emma@example.com	$2b$12$hashedpassword6	36	2025-02-19 10:00:00	2025-09-11 23:04:18.445134
37	Paul	Becker	pirate_paul	paul@example.com	$2b$12$hashedpassword7	37	2025-03-25 10:00:00	2025-09-11 23:04:18.445134
38	Sarah	Schulz	treasure_sarah	sarah@example.com	$2b$12$hashedpassword8	38	2025-04-15 10:00:00	2025-09-11 23:04:18.445134
39	Tom	Hoffmann	sailor_tom	tom@example.com	$2b$12$hashedpassword9	39	2025-05-25 10:00:00	2025-09-11 23:04:18.445134
40	Nina	Klein	captain_nina	nina@example.com	$2b$12$hashedpassword10	40	2025-02-09 10:00:00	2025-09-11 23:04:18.445134
\.


--
-- Name: admins_admin_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.admins_admin_id_seq', 20, true);


--
-- Name: answers_answer_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.answers_answer_id_seq', 80, true);


--
-- Name: audit_log_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.audit_log_log_id_seq', 1, false);


--
-- Name: avatars_avatar_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.avatars_avatar_id_seq', 40, true);


--
-- Name: chats_chat_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.chats_chat_id_seq', 10, true);


--
-- Name: courses_course_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.courses_course_id_seq', 10, true);


--
-- Name: game_answers_game_answer_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.game_answers_game_answer_id_seq', 30, true);


--
-- Name: game_groups_game_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.game_groups_game_id_seq', 10, true);


--
-- Name: game_rounds_round_no_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.game_rounds_round_no_seq', 30, true);


--
-- Name: games_game_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.games_game_id_seq', 10, true);


--
-- Name: questions_question_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.questions_question_id_seq', 40, true);


--
-- Name: users_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_user_id_seq', 40, true);


--
-- Name: admins admins_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admins
    ADD CONSTRAINT admins_email_key UNIQUE (email);


--
-- Name: admins admins_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admins
    ADD CONSTRAINT admins_pkey PRIMARY KEY (admin_id);


--
-- Name: admins admins_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admins
    ADD CONSTRAINT admins_username_key UNIQUE (username);


--
-- Name: answers answers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.answers
    ADD CONSTRAINT answers_pkey PRIMARY KEY (answer_id);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (log_id);


--
-- Name: avatars avatars_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.avatars
    ADD CONSTRAINT avatars_pkey PRIMARY KEY (avatar_id);


--
-- Name: chats chats_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chats
    ADD CONSTRAINT chats_pkey PRIMARY KEY (chat_id);


--
-- Name: courses courses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_pkey PRIMARY KEY (course_id);


--
-- Name: game_answers game_answers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.game_answers
    ADD CONSTRAINT game_answers_pkey PRIMARY KEY (game_answer_id);


--
-- Name: game_groups game_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.game_groups
    ADD CONSTRAINT game_groups_pkey PRIMARY KEY (game_id);


--
-- Name: game_rounds game_rounds_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.game_rounds
    ADD CONSTRAINT game_rounds_pkey PRIMARY KEY (round_no);


--
-- Name: games games_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.games
    ADD CONSTRAINT games_pkey PRIMARY KEY (game_id);


--
-- Name: questions questions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.questions
    ADD CONSTRAINT questions_pkey PRIMARY KEY (question_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: idx_admins_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_admins_email ON public.admins USING btree (email);


--
-- Name: idx_admins_username; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_admins_username ON public.admins USING btree (username);


--
-- Name: idx_answers_question_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_answers_question_id ON public.answers USING btree (question_id);


--
-- Name: idx_answers_right_wrong; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_answers_right_wrong ON public.answers USING btree (right_wrong);


--
-- Name: idx_chats_game_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_chats_game_id ON public.chats USING btree (game_id);


--
-- Name: idx_chats_game_time; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_chats_game_time ON public.chats USING btree (game_id, "time");


--
-- Name: idx_chats_time; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_chats_time ON public.chats USING btree ("time");


--
-- Name: idx_chats_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_chats_user_id ON public.chats USING btree (user_id);


--
-- Name: idx_courses_creation_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_courses_creation_date ON public.courses USING btree (creation_date);


--
-- Name: idx_game_answers_answer_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_game_answers_answer_id ON public.game_answers USING btree (answer_id);


--
-- Name: idx_game_answers_answered_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_game_answers_answered_at ON public.game_answers USING btree (answered_at);


--
-- Name: idx_game_answers_game_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_game_answers_game_id ON public.game_answers USING btree (game_id);


--
-- Name: idx_game_answers_round_no; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_game_answers_round_no ON public.game_answers USING btree (round_no);


--
-- Name: idx_game_answers_user_game; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_game_answers_user_game ON public.game_answers USING btree (user_id, game_id);


--
-- Name: idx_game_answers_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_game_answers_user_id ON public.game_answers USING btree (user_id);


--
-- Name: idx_game_groups_joined_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_game_groups_joined_date ON public.game_groups USING btree (joined_date);


--
-- Name: idx_game_groups_score; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_game_groups_score ON public.game_groups USING btree (score);


--
-- Name: idx_game_groups_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_game_groups_user_id ON public.game_groups USING btree (user_id);


--
-- Name: idx_game_rounds_game_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_game_rounds_game_id ON public.game_rounds USING btree (game_id);


--
-- Name: idx_game_rounds_question_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_game_rounds_question_id ON public.game_rounds USING btree (question_id);


--
-- Name: idx_games_course_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_games_course_id ON public.games USING btree (course_id);


--
-- Name: idx_games_finish_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_games_finish_date ON public.games USING btree (finish_date);


--
-- Name: idx_games_start_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_games_start_date ON public.games USING btree (start_date);


--
-- Name: idx_games_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_games_status ON public.games USING btree (status);


--
-- Name: idx_games_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_games_user_id ON public.games USING btree (user_id);


--
-- Name: idx_games_user_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_games_user_status ON public.games USING btree (user_id, status);


--
-- Name: idx_questions_checked_by_adminid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_questions_checked_by_adminid ON public.questions USING btree (checked_by_adminid);


--
-- Name: idx_questions_course_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_questions_course_id ON public.questions USING btree (course_id);


--
-- Name: idx_questions_course_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_questions_course_status ON public.questions USING btree (course_id, status);


--
-- Name: idx_questions_creation_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_questions_creation_date ON public.questions USING btree (creation_date);


--
-- Name: idx_questions_made_by_userid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_questions_made_by_userid ON public.questions USING btree (made_by_userid);


--
-- Name: idx_questions_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_questions_status ON public.questions USING btree (status);


--
-- Name: idx_users_avatar_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_avatar_id ON public.users USING btree (avatar_id);


--
-- Name: idx_users_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_email ON public.users USING btree (email);


--
-- Name: idx_users_registry_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_registry_date ON public.users USING btree (registry_date);


--
-- Name: idx_users_username; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_username ON public.users USING btree (username);


--
-- Name: game_answers game_answers_auto_score; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER game_answers_auto_score BEFORE INSERT ON public.game_answers FOR EACH ROW EXECUTE FUNCTION public.calculate_game_answer_score();


--
-- Name: games games_status_validation; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER games_status_validation BEFORE UPDATE ON public.games FOR EACH ROW EXECUTE FUNCTION public.validate_game_status_transition();


--
-- Name: game_answers prevent_duplicate_answers; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER prevent_duplicate_answers BEFORE INSERT ON public.game_answers FOR EACH ROW EXECUTE FUNCTION public.prevent_duplicate_round_answers();


--
-- Name: questions questions_status_validation; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER questions_status_validation BEFORE UPDATE ON public.questions FOR EACH ROW EXECUTE FUNCTION public.validate_question_status();


--
-- Name: game_answers update_score_after_answer; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_score_after_answer AFTER INSERT ON public.game_answers FOR EACH ROW EXECUTE FUNCTION public.update_game_group_score();


--
-- Name: users users_update_timestamp; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER users_update_timestamp BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();


--
-- Name: answers answers_question_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.answers
    ADD CONSTRAINT answers_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.questions(question_id);


--
-- Name: chats chats_game_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chats
    ADD CONSTRAINT chats_game_id_fkey FOREIGN KEY (game_id) REFERENCES public.games(game_id);


--
-- Name: chats chats_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chats
    ADD CONSTRAINT chats_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id);


--
-- Name: game_answers game_answers_answer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.game_answers
    ADD CONSTRAINT game_answers_answer_id_fkey FOREIGN KEY (answer_id) REFERENCES public.answers(answer_id);


--
-- Name: game_answers game_answers_game_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.game_answers
    ADD CONSTRAINT game_answers_game_id_fkey FOREIGN KEY (game_id) REFERENCES public.games(game_id);


--
-- Name: game_answers game_answers_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.game_answers
    ADD CONSTRAINT game_answers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id);


--
-- Name: game_groups game_groups_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.game_groups
    ADD CONSTRAINT game_groups_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id);


--
-- Name: game_rounds game_rounds_game_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.game_rounds
    ADD CONSTRAINT game_rounds_game_id_fkey FOREIGN KEY (game_id) REFERENCES public.games(game_id);


--
-- Name: game_rounds game_rounds_question_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.game_rounds
    ADD CONSTRAINT game_rounds_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.questions(question_id);


--
-- Name: games games_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.games
    ADD CONSTRAINT games_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(course_id);


--
-- Name: games games_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.games
    ADD CONSTRAINT games_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id);


--
-- Name: questions questions_checked_by_adminid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.questions
    ADD CONSTRAINT questions_checked_by_adminid_fkey FOREIGN KEY (checked_by_adminid) REFERENCES public.admins(admin_id);


--
-- Name: questions questions_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.questions
    ADD CONSTRAINT questions_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(course_id);


--
-- Name: questions questions_made_by_userid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.questions
    ADD CONSTRAINT questions_made_by_userid_fkey FOREIGN KEY (made_by_userid) REFERENCES public.users(user_id);


--
-- Name: users users_avatar_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_avatar_id_fkey FOREIGN KEY (avatar_id) REFERENCES public.avatars(avatar_id);


--
-- PostgreSQL database dump complete
--

\unrestrict HqzSFEJmLuTBEHFCuUrmNgFLEi8cv9oHWoWacfedaTatmXr34gdIqfdLfV2eJCE

