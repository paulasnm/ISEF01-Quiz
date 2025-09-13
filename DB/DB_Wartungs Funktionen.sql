-- =====================================================
-- WARTUNGS-FUNKTIONEN
-- =====================================================

-- ====================
-- 1. INDEX-WARTUNG
-- ====================

CREATE OR REPLACE FUNCTION check_index_usage()
RETURNS TABLE(
    schemaname TEXT,
    tablename TEXT,
    indexname TEXT,
    num_rows BIGINT,
    table_size TEXT,
    index_size TEXT,
    unique_index BOOLEAN,
    number_of_scans BIGINT,
    tuples_read BIGINT,
    tuples_fetched BIGINT
) AS $$
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
$$ LANGUAGE plpgsql;

-- ====================
-- 2. STATISTIK-FUNKTIONEN
-- ====================

-- Funktion für Performance-Statistiken
CREATE OR REPLACE FUNCTION get_table_stats()
RETURNS TABLE(
    table_name TEXT,
    row_count BIGINT,
    table_size TEXT,
    index_size TEXT,
    total_size TEXT
) AS $$
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
$$ LANGUAGE plpgsql;
