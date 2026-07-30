-- ============================================================================
-- audit-sequences.sql
--
-- Flags: (1) a table whose implied sequence doesn't exist (only applies to
-- tables using the sequence+trigger PK strategy -- schema-model.md §7; tables
-- using an identity-column PK have no separate sequence to check here), (2) a
-- sequence not on the configured expected CACHE size, (3) a sequence with
-- CYCLE on (rejected -- a cycling PK-backing sequence would eventually
-- reissue an already-used id).
--
-- EVIDENCE CONTRACT: violations only. Empty result = PASS.
-- ============================================================================

SET DEFINE ON
SET VERIFY OFF
SET LINESIZE 200
SET PAGESIZE 100

ACCEPT table_prefix CHAR PROMPT 'Table prefix to audit (e.g. APP): '
ACCEPT seq_suffix CHAR DEFAULT 'SEQ' PROMPT 'Sequence suffix (e.g. SEQ, S) [SEQ]: '
-- CACHE 20 is Oracle's own default when CACHE is omitted from CREATE
-- SEQUENCE (schema-model.md §7) -- change this only if the target schema
-- has deliberately chosen a different value for a stated reason.
ACCEPT expected_cache NUMBER DEFAULT 20 PROMPT 'Expected sequence CACHE size [20]: '

-- ----------------------------------------------------------------------------
-- CHECK 1 -- table exists, implied sequence does not.
-- Derivation: <PREFIX>_<ROOT>_T -> <PREFIX>_<ROOT>_<suffix>. This only
-- applies to tables using the sequence+trigger PK strategy -- lookup-shaped
-- tables seeded into a shared lookup-values table (schema-emit's
-- lookup-seed.sql) are correctly excluded: they don't get their own table OR
-- their own sequence by design (schema-model.md §2). If most tables in this
-- schema use identity columns instead (schema-model.md §7, the recommended
-- greenfield strategy), expect this check to legitimately return nothing to
-- flag for those tables -- an identity column has no separate named sequence
-- object to check for by name (Oracle creates one internally, but it isn't
-- named per this schema's own convention).
-- ----------------------------------------------------------------------------
SELECT t.table_name,
       REGEXP_REPLACE(t.table_name, '_T$', '_' || UPPER('&&seq_suffix')) AS expected_sequence
  FROM user_tables t
 WHERE t.table_name LIKE UPPER('&&table_prefix') || '\_%\_T' ESCAPE '\'
   AND NOT EXISTS (
       SELECT 1 FROM user_tab_columns c
        WHERE c.table_name = t.table_name AND c.identity_column = 'YES'
       )
   AND NOT EXISTS (
       SELECT 1
         FROM user_sequences s
        WHERE s.sequence_name = REGEXP_REPLACE(t.table_name, '_T$', '_' || UPPER('&&seq_suffix'))
       )
 ORDER BY 1;

-- ----------------------------------------------------------------------------
-- CHECK 2 -- sequence exists but CACHE_SIZE <> the expected value.
-- ----------------------------------------------------------------------------
SELECT s.sequence_name,
       s.cache_size,
       &&expected_cache AS expected_cache_size
  FROM user_sequences s
 WHERE s.sequence_name LIKE UPPER('&&table_prefix') || '\_%' ESCAPE '\'
   AND NVL(s.cache_size, 0) <> &&expected_cache
 ORDER BY 1;

-- ----------------------------------------------------------------------------
-- CHECK 3 -- sequence exists but CYCLE_FLAG = 'Y' (rejected: a PK-backing
-- sequence should be NOCYCLE -- a cycling sequence would eventually reissue
-- an already-used id once it wraps).
-- ----------------------------------------------------------------------------
SELECT s.sequence_name,
       s.cycle_flag
  FROM user_sequences s
 WHERE s.sequence_name LIKE UPPER('&&table_prefix') || '\_%' ESCAPE '\'
   AND s.cycle_flag = 'Y'
 ORDER BY 1;

-- ----------------------------------------------------------------------------
-- OPTIONAL hard-fail wrapper -- same assert()/RAISE_APPLICATION_ERROR idiom
-- as audit-conventions.sql. Wrap CHECK 2's or CHECK 3's COUNT(*) the same way
-- if this needs to block a deploy pipeline rather than just report.
-- ----------------------------------------------------------------------------
