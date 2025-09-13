-- =====================================================
-- BEISPIEL-AUFRUFE ZUR KONTROLLE
-- =====================================================

-- Index-Nutzung prüfen
 SELECT * FROM check_index_usage();

-- Tabellen-Statistiken anzeigen
-- SELECT * FROM get_table_stats();

-- Alle Trigger anzeigen
-- SELECT trigger_name, event_manipulation, event_object_table, action_statement
-- FROM information_schema.triggers 
-- WHERE trigger_schema = 'public'
-- ORDER BY event_object_table, trigger_name;

-- Alle Indizes anzeigen
-- SELECT indexname, tablename, indexdef 
-- FROM pg_indexes 
-- WHERE schemaname = 'public' 
-- ORDER BY tablename, indexname;