BEGIN;

INSERT INTO files.permissions(permissionlevel, read_perm, delete_perm, share_perm)
VALUES
  (1, TRUE,  FALSE, FALSE),
  (2, TRUE,  TRUE,  FALSE),
  (3, TRUE,  TRUE,  TRUE)
ON CONFLICT (permissionlevel) DO NOTHING;

INSERT INTO users.themes(language, theme)
VALUES
  ('EN', 'DARK'),
  ('EN', 'LIGHT')
ON CONFLICT (language, theme) DO NOTHING;

DO $$
DECLARE
  v_site varchar;
BEGIN
  SELECT w.websitename INTO v_site
  FROM server.website w
  ORDER BY w.websitename
  LIMIT 1;

  IF v_site IS NULL THEN
    RAISE EXCEPTION 'Cannot seed users.accounttypewebsite: server.website is empty (no websitename to reference).';
  END IF;

  INSERT INTO users.accounttypewebsite(accounttype, websitename)
  VALUES
    ('STUDENT', v_site),
    ('COMPANY', v_site)
  ON CONFLICT (accounttype) DO NOTHING;
END;
$$;

CREATE OR REPLACE FUNCTION users.fn_hash_password()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT'
     OR (TG_OP = 'UPDATE' AND NEW.password IS DISTINCT FROM OLD.password) THEN
    NEW.salt := md5(random()::text || clock_timestamp()::text || NEW.login::text);
    NEW.password := md5(NEW.password || NEW.salt);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_users_hash_password ON users."user";
CREATE TRIGGER trg_users_hash_password
BEFORE INSERT OR UPDATE OF password ON users."user"
FOR EACH ROW
EXECUTE FUNCTION users.fn_hash_password();

CREATE OR REPLACE FUNCTION users.fn_block_login_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.login IS DISTINCT FROM OLD.login THEN
    RAISE EXCEPTION 'Changing login is not allowed';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_users_block_login_change ON users."user";
CREATE TRIGGER trg_users_block_login_change
BEFORE UPDATE OF login ON users."user"
FOR EACH ROW
EXECUTE FUNCTION users.fn_block_login_change();

CREATE OR REPLACE FUNCTION users.register_user(
  p_login varchar,
  p_password_plain varchar,
  p_age int,
  p_university varchar,
  p_nationality varchar,
  p_isworking boolean,
  p_ishiring boolean,
  p_accounttype varchar,
  p_language varchar,
  p_theme varchar
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  IF p_login IS NULL OR btrim(p_login) = '' THEN
    RAISE EXCEPTION 'Login cannot be empty';
  END IF;

  IF p_password_plain IS NULL OR btrim(p_password_plain) = '' THEN
    RAISE EXCEPTION 'Password cannot be empty';
  END IF;

  IF EXISTS (SELECT 1 FROM users."user" u WHERE u.login = p_login) THEN
    RAISE EXCEPTION 'User with login % already exists', p_login;
  END IF;

  IF (p_language IS NOT NULL AND p_theme IS NULL)
     OR (p_language IS NULL AND p_theme IS NOT NULL) THEN
    RAISE EXCEPTION 'Both language and theme must be provided together';
  END IF;

  IF p_accounttype IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM users.accounttypewebsite a WHERE a.accounttype = p_accounttype
  ) THEN
    RAISE EXCEPTION 'Unknown accounttype: %', p_accounttype;
  END IF;

  IF (p_language IS NOT NULL AND p_theme IS NOT NULL) AND NOT EXISTS (
    SELECT 1 FROM users.themes t WHERE t.language = p_language AND t.theme = p_theme
  ) THEN
    RAISE EXCEPTION 'Unknown language/theme pair: %, %', p_language, p_theme;
  END IF;

  INSERT INTO users."user"(
    login, password, age, university, nationality,
    isworking, ishiring, accounttype, language, theme
  )
  VALUES (
    p_login,
    p_password_plain,
    p_age,
    p_university,
    p_nationality,
    COALESCE(p_isworking, FALSE),
    COALESCE(p_ishiring, FALSE),
    p_accounttype,
    p_language,
    p_theme
  );
END;
$$;

CREATE OR REPLACE FUNCTION users.check_login(
  p_login varchar,
  p_password_plain varchar
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  v_salt varchar;
  v_hash varchar;
BEGIN
  SELECT u.salt, u.password
  INTO v_salt, v_hash
  FROM users."user" u
  WHERE u.login = p_login;

  IF v_salt IS NULL OR v_hash IS NULL THEN
    RETURN FALSE;
  END IF;

  RETURN v_hash = md5(p_password_plain || v_salt);
END;
$$;

CREATE OR REPLACE FUNCTION files.has_permission(
  p_login varchar,
  p_did int,
  p_action text
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  v_owner varchar;
  v_level int;
  v_read boolean;
  v_delete boolean;
  v_share boolean;
  v_action text := lower(coalesce(p_action,''));
BEGIN
  SELECT d.owner INTO v_owner
  FROM files.documents d
  WHERE d.did = p_did;

  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;

  IF v_owner IS NOT NULL AND p_login = v_owner THEN
    RETURN TRUE;
  END IF;

  SELECT dp.permissionlevel INTO v_level
  FROM files.documentperms dp
  WHERE dp.did = p_did AND dp.login = p_login
  ORDER BY dp.pid
  LIMIT 1;

  IF v_level IS NULL THEN
    RETURN FALSE;
  END IF;

  SELECT p.read_perm, p.delete_perm, p.share_perm
  INTO v_read, v_delete, v_share
  FROM files.permissions p
  WHERE p.permissionlevel = v_level;

  IF v_action = 'read' THEN
    RETURN COALESCE(v_read, FALSE);
  ELSIF v_action = 'delete' THEN
    RETURN COALESCE(v_delete, FALSE);
  ELSIF v_action = 'share' THEN
    RETURN COALESCE(v_share, FALSE);
  ELSE
    RAISE EXCEPTION 'Unknown action: % (use read/delete/share)', p_action;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION files.grant_permission(
  p_grantor varchar,
  p_did int,
  p_target_login varchar,
  p_permissionlevel int
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_owner varchar;
  v_grantor_level int;
  v_new_pid int;
BEGIN
  SELECT d.owner INTO v_owner
  FROM files.documents d
  WHERE d.did = p_did;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Document % not found', p_did;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM users."user" u WHERE u.login = p_target_login) THEN
    RAISE EXCEPTION 'Target user % not found', p_target_login;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM files.permissions p WHERE p.permissionlevel = p_permissionlevel) THEN
    RAISE EXCEPTION 'Permission level % does not exist', p_permissionlevel;
  END IF;

  IF v_owner IS NULL OR p_grantor <> v_owner THEN
    IF NOT files.has_permission(p_grantor, p_did, 'share') THEN
      RAISE EXCEPTION 'User % has no share permission for document %', p_grantor, p_did;
    END IF;

    SELECT dp.permissionlevel INTO v_grantor_level
    FROM files.documentperms dp
    WHERE dp.did = p_did AND dp.login = p_grantor
    ORDER BY dp.pid
    LIMIT 1;

    IF v_grantor_level IS NULL THEN
      RAISE EXCEPTION 'Grantor % has no permission record for document %', p_grantor, p_did;
    END IF;

    IF p_permissionlevel > v_grantor_level THEN
      RAISE EXCEPTION 'Grantor % cannot grant higher level (%) than their own (%)',
        p_grantor, p_permissionlevel, v_grantor_level;
    END IF;
  END IF;

  UPDATE files.documentperms
  SET permissionlevel = p_permissionlevel
  WHERE pid = (
    SELECT pid
    FROM files.documentperms
    WHERE did = p_did AND login = p_target_login
    ORDER BY pid
    LIMIT 1
  );

  IF FOUND THEN
    RETURN;
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('files.documentperms_pid'));
  SELECT COALESCE(MAX(pid) + 1, 1) INTO v_new_pid FROM files.documentperms;

  INSERT INTO files.documentperms(pid, did, login, permissionlevel)
  VALUES (v_new_pid, p_did, p_target_login, p_permissionlevel);
END;
$$;

CREATE OR REPLACE FUNCTION files.revoke_permission(
  p_grantor varchar,
  p_did int,
  p_target_login varchar
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_owner varchar;
BEGIN
  SELECT d.owner INTO v_owner
  FROM files.documents d
  WHERE d.did = p_did;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Document % not found', p_did;
  END IF;

  IF v_owner IS NOT NULL AND p_target_login = v_owner THEN
    RAISE EXCEPTION 'Cannot revoke permissions from document owner';
  END IF;

  IF v_owner IS NULL OR p_grantor <> v_owner THEN
    IF NOT files.has_permission(p_grantor, p_did, 'share') THEN
      RAISE EXCEPTION 'User % has no share permission for document %', p_grantor, p_did;
    END IF;
  END IF;

  DELETE FROM files.documentperms
  WHERE did = p_did AND login = p_target_login;
END;
$$;

CREATE OR REPLACE FUNCTION files.fn_auto_owner_perms()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_max_level int;
  v_new_pid int;
BEGIN
  IF NEW.owner IS NULL OR btrim(NEW.owner) = '' THEN
    RETURN NEW;
  END IF;

  SELECT MAX(permissionlevel) INTO v_max_level FROM files.permissions;
  IF v_max_level IS NULL THEN
    RAISE EXCEPTION 'No permission levels in files.permissions';
  END IF;

  UPDATE files.documentperms
  SET permissionlevel = v_max_level
  WHERE pid = (
    SELECT pid
    FROM files.documentperms
    WHERE did = NEW.did AND login = NEW.owner
    ORDER BY pid
    LIMIT 1
  );

  IF FOUND THEN
    RETURN NEW;
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('files.documentperms_pid'));
  SELECT COALESCE(MAX(pid) + 1, 1) INTO v_new_pid FROM files.documentperms;

  INSERT INTO files.documentperms(pid, did, login, permissionlevel)
  VALUES (v_new_pid, NEW.did, NEW.owner, v_max_level);

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_files_auto_owner_perms ON files.documents;
CREATE TRIGGER trg_files_auto_owner_perms
AFTER INSERT ON files.documents
FOR EACH ROW
EXECUTE FUNCTION files.fn_auto_owner_perms();

CREATE OR REPLACE FUNCTION files.fn_validate_documentperms_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_actor varchar;
  v_owner varchar;
  v_actor_level int;
BEGIN
  v_actor := current_setting('app.user', true);

  IF v_actor IS NULL OR v_actor = '' THEN
    RETURN NEW;
  END IF;

  SELECT d.owner INTO v_owner
  FROM files.documents d
  WHERE d.did = NEW.did;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Document % not found', NEW.did;
  END IF;

  IF v_owner IS NOT NULL AND v_actor = v_owner THEN
    RETURN NEW;
  END IF;

  IF NOT files.has_permission(v_actor, NEW.did, 'share') THEN
    RAISE EXCEPTION 'User % has no share permission for document %', v_actor, NEW.did;
  END IF;

  SELECT dp.permissionlevel INTO v_actor_level
  FROM files.documentperms dp
  WHERE dp.did = NEW.did AND dp.login = v_actor
  ORDER BY dp.pid
  LIMIT 1;

  IF v_actor_level IS NULL THEN
    RAISE EXCEPTION 'Actor % has no permission record for document %', v_actor, NEW.did;
  END IF;

  IF NEW.permissionlevel > v_actor_level THEN
    RAISE EXCEPTION 'Actor % cannot grant higher level (%) than their own (%)',
      v_actor, NEW.permissionlevel, v_actor_level;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_files_validate_documentperms ON files.documentperms;
CREATE TRIGGER trg_files_validate_documentperms
BEFORE INSERT OR UPDATE ON files.documentperms
FOR EACH ROW
EXECUTE FUNCTION files.fn_validate_documentperms_change();

CREATE OR REPLACE FUNCTION jobs.bump_counter(
  p_country text,
  p_jobid int,
  p_bucket text
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_bucket text := upper(p_bucket);
  v_country text := lower(p_country);
BEGIN
  IF v_bucket NOT IN ('T0','T1','T2') THEN
    RAISE EXCEPTION 'bucket must be T0, T1 or T2';
  END IF;

  IF v_country IN ('pl','poland') THEN
    IF v_bucket = 'T0' THEN
      UPDATE jobs.jobspl SET countt0 = countt0 + 1 WHERE jobid = p_jobid;
    ELSIF v_bucket = 'T1' THEN
      UPDATE jobs.jobspl SET countt1 = countt1 + 1 WHERE jobid = p_jobid;
    ELSE
      UPDATE jobs.jobspl SET countt2 = countt2 + 1 WHERE jobid = p_jobid;
    END IF;

  ELSIF v_country IN ('cz','czech','czechia') THEN
    IF v_bucket = 'T0' THEN
      UPDATE jobs.jobscz SET countt0 = countt0 + 1 WHERE jobid = p_jobid;
    ELSIF v_bucket = 'T1' THEN
      UPDATE jobs.jobscz SET countt1 = countt1 + 1 WHERE jobid = p_jobid;
    ELSE
      UPDATE jobs.jobscz SET countt2 = countt2 + 1 WHERE jobid = p_jobid;
    END IF;

  ELSE
    RAISE EXCEPTION 'Unknown country: % (use pl/cz)', p_country;
  END IF;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Job % counters row not found for country %', p_jobid, p_country;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION jobs.fn_create_job_counters()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO jobs.jobspl(jobid, countt0, countt1, countt2)
  VALUES (NEW.jobid, 0, 0, 0)
  ON CONFLICT (jobid) DO NOTHING;

  INSERT INTO jobs.jobscz(jobid, countt0, countt1, countt2)
  VALUES (NEW.jobid, 0, 0, 0)
  ON CONFLICT (jobid) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_jobs_create_counters ON jobs.jobdict;
CREATE TRIGGER trg_jobs_create_counters
AFTER INSERT ON jobs.jobdict
FOR EACH ROW
EXECUTE FUNCTION jobs.fn_create_job_counters();

CREATE OR REPLACE FUNCTION jobs.fn_translation_fallback()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_title_en varchar;
  v_skill_en varchar;
BEGIN
  SELECT jd.title_en, jd.skill_en
  INTO v_title_en, v_skill_en
  FROM jobs.jobdict jd
  WHERE jd.jobid = NEW.jobid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Job % not found in jobdict', NEW.jobid;
  END IF;

  IF NEW.local_title IS NULL OR btrim(NEW.local_title) = '' THEN
    NEW.local_title := v_title_en;
  END IF;

  IF NEW.local_skill IS NULL OR btrim(NEW.local_skill) = '' THEN
    NEW.local_skill := v_skill_en;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_jobs_translation_fallback ON jobs.jobtranslations;
CREATE TRIGGER trg_jobs_translation_fallback
BEFORE INSERT OR UPDATE ON jobs.jobtranslations
FOR EACH ROW
EXECUTE FUNCTION jobs.fn_translation_fallback();

CREATE OR REPLACE FUNCTION server.is_ip_allowed(
  p_ip inet,
  p_scope text
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  v_scope text := lower(p_scope);
  v_canconsole boolean;
  v_candb boolean;
  v_canclient boolean;
BEGIN
  SELECT w.canconsole, w.candb, w.canclient
  INTO v_canconsole, v_candb, v_canclient
  FROM server.ipwhitelist w
  WHERE w.ip = p_ip;

  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;

  IF v_scope = 'console' THEN
    RETURN COALESCE(v_canconsole, FALSE);
  ELSIF v_scope = 'db' THEN
    RETURN COALESCE(v_candb, FALSE);
  ELSIF v_scope = 'client' THEN
    RETURN COALESCE(v_canclient, FALSE);
  ELSE
    RAISE EXCEPTION 'Unknown scope: % (use console/db/client)', p_scope;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION server.fn_audit_log()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_actor text;
  v_msg text;
  v_op text;
BEGIN
  v_actor := current_setting('app.user', true);
  IF v_actor IS NULL OR v_actor = '' THEN
    v_actor := current_user;
  END IF;

  v_op := TG_OP;
  v_msg := format('%s on %s', v_op, TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME);

  INSERT INTO server.logs(date, "user", message, ip, type)
  VALUES (current_date, v_actor, v_msg, inet_client_addr(), v_op)
  ON CONFLICT (date, "user") DO UPDATE
    SET message = left(
                  CASE
                    WHEN server.logs.message IS NULL OR btrim(server.logs.message) = '' THEN EXCLUDED.message
                    ELSE server.logs.message || '; ' || EXCLUDED.message
                  END,
                  255
                ),
        ip = EXCLUDED.ip,
        type = EXCLUDED.type;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_users_user ON users."user";
CREATE TRIGGER trg_audit_users_user
AFTER INSERT OR UPDATE OR DELETE ON users."user"
FOR EACH ROW
EXECUTE FUNCTION server.fn_audit_log();

DROP TRIGGER IF EXISTS trg_audit_files_documents ON files.documents;
CREATE TRIGGER trg_audit_files_documents
AFTER INSERT OR UPDATE OR DELETE ON files.documents
FOR EACH ROW
EXECUTE FUNCTION server.fn_audit_log();

DROP TRIGGER IF EXISTS trg_audit_files_documentperms ON files.documentperms;
CREATE TRIGGER trg_audit_files_documentperms
AFTER INSERT OR UPDATE OR DELETE ON files.documentperms
FOR EACH ROW
EXECUTE FUNCTION server.fn_audit_log();

DROP TRIGGER IF EXISTS trg_audit_jobs_jobdict ON jobs.jobdict;
CREATE TRIGGER trg_audit_jobs_jobdict
AFTER INSERT OR UPDATE OR DELETE ON jobs.jobdict
FOR EACH ROW
EXECUTE FUNCTION server.fn_audit_log();

DROP TRIGGER IF EXISTS trg_audit_jobs_jobtranslations ON jobs.jobtranslations;
CREATE TRIGGER trg_audit_jobs_jobtranslations
AFTER INSERT OR UPDATE OR DELETE ON jobs.jobtranslations
FOR EACH ROW
EXECUTE FUNCTION server.fn_audit_log();

COMMIT;
