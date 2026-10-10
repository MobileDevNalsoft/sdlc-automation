-- ============================================================================
-- audit-conventions.sql
--
-- Flags: (1) tables missing any of the 5 audit ("WHO") columns, (2)
-- CREATED_BY/LAST_UPDATED_BY at the wrong width, (3) VARCHAR2 columns using
-- byte semantics instead of character semantics, (4) OBJECT_VERSION_NUMBER
-- not NUMBER-family, (5) WHO columns declared NULLable, (6) a boolean-shaped
-- column that isn't CHAR(1) and isn't a legitimate native BOOLEAN, (7)
-- audit-timestamp columns mixing DATE and TIMESTAMP WITH TIME ZONE across
-- sibling tables under the same prefix, (8) a table with PK-generation
-- machinery (identity column or a NEXTVAL-driving trigger) but no actual
-- PRIMARY KEY constraint, (9) columns using Oracle SQL reserved keywords
-- (COMMENT, NUMBER, DATE, UID, USER, TYPE, LEVEL, MODE, SIZE, ORDER, DEFAULT,
-- CHECK, ACCESS, ROWNUM, SESSION, STATUS).
--
-- EVIDENCE CONTRACT: every query below returns VIOLATIONS ONLY. An empty
-- result set is a real PASS -- these are exhaustive negative-filter queries
-- against the data dictionary (USER_TAB_COLUMNS/USER_TABLES/USER_CONSTRAINTS),
-- not a sample, so "nothing came back" means "nothing matched the violation
-- condition," not "we didn't look."
--
-- Run in the schema that owns the tables you're auditing.
-- ============================================================================

SET DEFINE ON
SET VERIFY OFF
SET LINESIZE 200
SET PAGESIZE 100

-- Table-name prefix to audit, e.g. APP (unquoted Oracle identifiers are
-- always stored UPPERCASE in USER_TABLES/USER_TAB_COLUMNS regardless of the
-- lower/upper case used in the original CREATE TABLE text).
ACCEPT table_prefix CHAR PROMPT 'Table prefix to audit (e.g. APP): '

-- This schema's chosen WHO-column identity width -- a documented parameter
-- per schema-model.md §4, not a magic number. Default 128 assumes the column
-- stores a UUID/subject-claim/username identity; raise to 320 if the column
-- stores a raw email address.
ACCEPT who_varchar_width NUMBER DEFAULT 128 PROMPT 'CREATED_BY/LAST_UPDATED_BY expected width [128]: '

-- Tables to exclude entirely from these checks -- ad hoc backup/snapshot
-- tables (see schema-promote's rollback-drop-snapshot.sql) are one-off
-- copies, not part of the live convention surface.
ACCEPT exclude_pattern CHAR DEFAULT '%\_BKP\_%' PROMPT 'Table-name exclusion LIKE pattern (ESCAPE ''\'') [%\_BKP\_%]: '

-- ----------------------------------------------------------------------------
-- CHECK 1 -- tables missing one or more of the 5 WHO columns.
-- ----------------------------------------------------------------------------
SELECT t.table_name,
       who.who_column AS missing_who_column
  FROM user_tables t
 CROSS JOIN (
       SELECT 'CREATED_BY' AS who_column FROM dual UNION ALL
       SELECT 'CREATION_DATE'          FROM dual UNION ALL
       SELECT 'LAST_UPDATED_BY'        FROM dual UNION ALL
       SELECT 'LAST_UPDATE_DATE'       FROM dual UNION ALL
       SELECT 'OBJECT_VERSION_NUMBER'  FROM dual
       ) who
 WHERE t.table_name LIKE UPPER('&&table_prefix') || '\_%' ESCAPE '\'
   AND t.table_name NOT LIKE UPPER('&&exclude_pattern') ESCAPE '\'
   AND NOT EXISTS (
       SELECT 1
         FROM user_tab_columns c
        WHERE c.table_name  = t.table_name
          AND c.column_name = who.who_column
       )
 ORDER BY 1, 2;

-- ----------------------------------------------------------------------------
-- CHECK 2 -- CREATED_BY / LAST_UPDATED_BY present but wrong width.
-- ----------------------------------------------------------------------------
SELECT c.table_name,
       c.column_name,
       c.data_type,
       c.char_length AS actual_width,
       &&who_varchar_width AS expected_width
  FROM user_tab_columns c
 WHERE c.table_name LIKE UPPER('&&table_prefix') || '\_%' ESCAPE '\'
   AND c.column_name IN ('CREATED_BY', 'LAST_UPDATED_BY')
   AND (c.data_type <> 'VARCHAR2' OR c.char_length <> &&who_varchar_width)
 ORDER BY 1, 2;

-- ----------------------------------------------------------------------------
-- CHECK 3 -- VARCHAR2 columns declared with BYTE semantics instead of CHAR
-- semantics (schema-model.md §4: VARCHAR2(n CHAR) is the recommended default
-- to avoid a multibyte-data truncation footgun that depends on the instance's
-- NLS_LENGTH_SEMANTICS setting rather than being visible in the DDL itself).
-- CHAR_USED = 'B' means byte semantics; 'C' means character semantics.
-- ----------------------------------------------------------------------------
SELECT c.table_name,
       c.column_name,
       c.data_type,
       c.char_used,
       c.char_length
  FROM user_tab_columns c
 WHERE c.table_name LIKE UPPER('&&table_prefix') || '\_%' ESCAPE '\'
   AND c.data_type IN ('VARCHAR2', 'CHAR')
   AND c.char_used = 'B'
 ORDER BY 1, 2;

-- ----------------------------------------------------------------------------
-- CHECK 4 -- OBJECT_VERSION_NUMBER present but not NUMBER-family.
-- Precision is deliberately NOT checked here as a violation -- both plain
-- NUMBER and NUMBER(10) are valid NUMBER-family declarations
-- (schema-model.md §4); pin one per schema as a documented choice, not
-- something this check enforces.
-- ----------------------------------------------------------------------------
SELECT c.table_name,
       c.column_name,
       c.data_type,
       c.data_default
  FROM user_tab_columns c
 WHERE c.table_name LIKE UPPER('&&table_prefix') || '\_%' ESCAPE '\'
   AND c.column_name = 'OBJECT_VERSION_NUMBER'
   AND c.data_type <> 'NUMBER'
 ORDER BY 1;

-- ----------------------------------------------------------------------------
-- CHECK 5 -- WHO columns present but declared NULLable
-- (schema-model.md §4 recommends NOT NULL on all five).
-- ----------------------------------------------------------------------------
SELECT c.table_name,
       c.column_name,
       c.nullable
  FROM user_tab_columns c
 WHERE c.table_name LIKE UPPER('&&table_prefix') || '\_%' ESCAPE '\'
   AND c.column_name IN ('CREATED_BY', 'CREATION_DATE', 'LAST_UPDATED_BY',
                          'LAST_UPDATE_DATE', 'OBJECT_VERSION_NUMBER')
   AND c.nullable = 'Y'
 ORDER BY 1, 2;

-- ----------------------------------------------------------------------------
-- CHECK 6 -- boolean-shaped column that isn't CHAR(1) and isn't a
-- legitimate native BOOLEAN (schema-model.md §6: 23ai+ BOOLEAN columns are an
-- accepted alternative to CHAR(1), so they are explicitly excluded here, not
-- flagged as drift). Two detection strategies, combined, since naming-pattern
-- matching alone misses a column that stores a Y/N-shaped value under a name
-- that doesn't look like a flag (e.g. a single-character status abbreviation
-- column that should have been CHAR(1) and wasn't):
--   (a) any column exactly 1 character wide whose DATA_TYPE is neither CHAR
--       nor BOOLEAN.
--   (b) any column named like a flag (%_FLAG, IS_%, HAS_%, ENABLE%) that
--       isn't CHAR(1) and isn't BOOLEAN at all, regardless of width.
-- ----------------------------------------------------------------------------
SELECT c.table_name,
       c.column_name,
       c.data_type,
       c.char_length,
       'single-char column not declared CHAR or BOOLEAN' AS violation_reason
  FROM user_tab_columns c
 WHERE c.table_name LIKE UPPER('&&table_prefix') || '\_%' ESCAPE '\'
   AND c.char_length = 1
   AND c.data_type NOT IN ('CHAR', 'BOOLEAN')
UNION ALL
SELECT c.table_name,
       c.column_name,
       c.data_type,
       c.char_length,
       'flag-named column not CHAR(1) or BOOLEAN' AS violation_reason
  FROM user_tab_columns c
 WHERE c.table_name LIKE UPPER('&&table_prefix') || '\_%' ESCAPE '\'
   AND ( c.column_name LIKE '%\_FLAG' ESCAPE '\'
      OR c.column_name LIKE 'IS\_%' ESCAPE '\'
      OR c.column_name LIKE 'HAS\_%' ESCAPE '\'
      OR c.column_name LIKE 'ENABLE%' )
   AND NOT (c.data_type = 'CHAR' AND c.char_length = 1)
   AND c.data_type <> 'BOOLEAN'
 ORDER BY 1, 2;

-- ----------------------------------------------------------------------------
-- CHECK 7 -- audit-timestamp columns mixing DATE and TIMESTAMP WITH TIME ZONE
-- across sibling tables under the same prefix. schema-model.md §4 allows
-- DATE only as a legacy-compatibility match to an existing all-DATE schema --
-- a schema with SOME tables on TIMESTAMP WITH TIME ZONE and others still on
-- DATE has drifted, not deliberately chosen either convention.
-- ----------------------------------------------------------------------------
SELECT c.data_type,
       COUNT(DISTINCT c.table_name) AS table_count,
       LISTAGG(DISTINCT c.table_name, ', ') WITHIN GROUP (ORDER BY c.table_name) AS example_tables
  FROM user_tab_columns c
 WHERE c.table_name LIKE UPPER('&&table_prefix') || '\_%' ESCAPE '\'
   AND c.column_name IN ('CREATION_DATE', 'LAST_UPDATE_DATE')
 GROUP BY c.data_type
HAVING (SELECT COUNT(DISTINCT c2.data_type)
          FROM user_tab_columns c2
         WHERE c2.table_name LIKE UPPER('&&table_prefix') || '\_%' ESCAPE '\'
           AND c2.column_name IN ('CREATION_DATE', 'LAST_UPDATE_DATE')) > 1
 ORDER BY 1;

-- ----------------------------------------------------------------------------
-- CHECK 8 -- a table shows PK-generation machinery (an identity column, or a
-- BEFORE INSERT/UPDATE trigger whose body references .NEXTVAL for this
-- table) but has no PRIMARY KEY constraint in USER_CONSTRAINTS. A generator
-- supplying values is not the same fact as a constraint enforcing uniqueness
-- -- see schema-model.md §1 and this skill's own SKILL.md.
--
-- The trigger-text half of this check reads USER_SOURCE (TYPE = 'TRIGGER'),
-- not USER_TRIGGERS.TRIGGER_BODY -- TRIGGER_BODY is a LONG column, and Oracle
-- does not allow a LONG column in a WHERE clause or inside a function call
-- (ORA-00997); USER_SOURCE.TEXT holds the same source text as VARCHAR2 per
-- line and can be filtered directly. This is still a best-effort text
-- search, not a guaranteed parse -- treat a hit as a strong lead to confirm
-- by hand, not an infallible result.
-- ----------------------------------------------------------------------------
SELECT t.table_name,
       'IDENTITY COLUMN, NO PK' AS violation_reason
  FROM user_tables t
 WHERE t.table_name LIKE UPPER('&&table_prefix') || '\_%' ESCAPE '\'
   AND t.table_name NOT LIKE UPPER('&&exclude_pattern') ESCAPE '\'
   AND EXISTS (
       SELECT 1 FROM user_tab_columns c
        WHERE c.table_name = t.table_name
          AND c.identity_column = 'YES'
       )
   AND NOT EXISTS (
       SELECT 1 FROM user_constraints uc
        WHERE uc.table_name = t.table_name
          AND uc.constraint_type = 'P'
       )
UNION ALL
SELECT ut.table_name,
       'NEXTVAL-DRIVING TRIGGER, NO PK' AS violation_reason
  FROM user_triggers ut
 WHERE ut.table_name LIKE UPPER('&&table_prefix') || '\_%' ESCAPE '\'
   AND ut.table_name NOT LIKE UPPER('&&exclude_pattern') ESCAPE '\'
   AND EXISTS (
       SELECT 1 FROM user_source us
        WHERE us.type = 'TRIGGER'
          AND us.name = ut.trigger_name
          AND UPPER(us.text) LIKE '%.NEXTVAL%'
       )
   AND NOT EXISTS (
       SELECT 1 FROM user_constraints uc
        WHERE uc.table_name = ut.table_name
          AND uc.constraint_type = 'P'
       )
 ORDER BY 1;

-- ----------------------------------------------------------------------------
-- CHECK 9 -- Columns using Oracle SQL reserved keywords.
-- Naming a column after an Oracle SQL reserved keyword (COMMENT, NUMBER, DATE,
-- UID, USER, TYPE, LEVEL, MODE, SIZE, ORDER, DEFAULT, CHECK, ACCESS, ROWNUM,
-- SESSION, STATUS) forces double-quoting ("COMMENT"), turns identifiers
-- case-sensitive, and causes ORA-00904 errors in standard unquoted queries.
--
-- See schema-model.md §0.1 for the approved alternative mapping table.
-- ----------------------------------------------------------------------------
SELECT c.table_name,
       c.column_name,
       'RESERVED KEYWORD COLLISION' AS violation_reason
  FROM user_tab_columns c
 WHERE c.table_name LIKE UPPER('&&table_prefix') || '\_%' ESCAPE '\'
   AND c.table_name NOT LIKE UPPER('&&exclude_pattern') ESCAPE '\'
   AND c.column_name IN (
       'ACCESS', 'ADD', 'ALL', 'ALTER', 'AND', 'ANY', 'AS', 'ASC', 'AUDIT',
       'BETWEEN', 'BY', 'CHAR', 'CHECK', 'CLUSTER', 'COLUMN', 'COMMENT',
       'COMPRESS', 'CONNECT', 'CREATE', 'CURRENT', 'DATE', 'DECIMAL', 'DEFAULT',
       'DELETE', 'DESC', 'DISTINCT', 'DROP', 'ELSE', 'EXCLUSIVE', 'EXISTS',
       'FILE', 'FLOAT', 'FOR', 'FROM', 'GRANT', 'GROUP', 'HAVING', 'IDENTIFIED',
       'IMMEDIATE', 'IN', 'INCREMENT', 'INDEX', 'INITIAL', 'INSERT', 'INTEGER',
       'INTERSECT', 'INTO', 'IS', 'LEVEL', 'LIKE', 'LOCK', 'LONG', 'MAXEXTENTS',
       'MINUS', 'MLSLABEL', 'MODE', 'MODIFY', 'NOAUDIT', 'NOCOMPRESS', 'NOT',
       'NOWAIT', 'NULL', 'NUMBER', 'OF', 'OFFLINE', 'ON', 'ONLINE', 'OPTION',
       'OR', 'ORDER', 'PCTFREE', 'PRIOR', 'PRIVILEGES', 'PUBLIC', 'RAW',
       'RENAME', 'RESOURCE', 'REVOKE', 'ROW', 'ROWID', 'ROWNUM', 'ROWS',
       'SELECT', 'SESSION', 'SET', 'SHARE', 'SIZE', 'SMALLINT', 'START',
       'SUCCESSFUL', 'SYNONYM', 'SYSDATE', 'TABLE', 'THEN', 'TO', 'TRIGGER',
       'UID', 'UNION', 'UNIQUE', 'UPDATE', 'USER', 'VALIDATE', 'VALUES',
       'VARCHAR', 'VARCHAR2', 'VIEW', 'WHENEVER', 'WHERE', 'WITH'
   )
 ORDER BY 1, 2;

-- ----------------------------------------------------------------------------
-- OPTIONAL -- hard-fail wrapper for a deploy pipeline. This codifies a
-- simple assert()/RAISE_APPLICATION_ERROR idiom rather than pulling in a full
-- unit-test framework, which typically needs its own installed schema and
-- cross-schema grants that may not be available on every target instance.
-- Uncomment and adapt any CHECK above into this shape to turn "empty =
-- pass" into an actual pipeline-blocking exception:
-- ----------------------------------------------------------------------------
-- DECLARE
--    PROCEDURE assert (p_cond IN BOOLEAN, p_msg IN VARCHAR2) IS
--    BEGIN
--       IF NOT NVL(p_cond, FALSE) THEN
--          raise_application_error(-20999, 'FAIL: ' || p_msg);
--       END IF;
--       DBMS_OUTPUT.PUT_LINE('  pass: ' || p_msg);
--    END;
--    l_violations NUMBER;
-- BEGIN
--    SELECT COUNT(*) INTO l_violations
--      FROM user_tab_columns c
--     WHERE c.table_name LIKE 'APP\_%' ESCAPE '\'
--       AND c.char_length = 1
--       AND c.data_type NOT IN ('CHAR', 'BOOLEAN');
--    assert(l_violations = 0, 'no single-char non-CHAR/BOOLEAN flag columns under APP_%');
-- END;
-- /
