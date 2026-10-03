-- V2 TASK-01 §5.2 / Spec D11: v1 pilot tables become read-only history. Writes are allowed only inside
-- a transaction that ran `SELECT set_config('saarthee.legacy_write', 'on', true)` (withLegacyWrite in
-- src/lib/db: legacy migration, v1 anonymize, seeds). photos and events stay writable (v2 reuses them).
-- TRUNCATE is not covered (test resets only).
CREATE FUNCTION legacy_read_only() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF coalesce(current_setting('saarthee.legacy_write', true), '') = 'on' THEN
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'LEGACY_READ_ONLY' USING ERRCODE = 'P0001', DETAIL = TG_TABLE_NAME || ' is read-only (v1 history)';
END;
$$;

CREATE TRIGGER trg_complaints_read_only BEFORE INSERT OR UPDATE OR DELETE ON "complaints"
  FOR EACH ROW EXECUTE FUNCTION legacy_read_only();

CREATE TRIGGER trg_reminders_read_only BEFORE INSERT OR UPDATE OR DELETE ON "reminders"
  FOR EACH ROW EXECUTE FUNCTION legacy_read_only();

CREATE TRIGGER trg_verifications_read_only BEFORE INSERT OR UPDATE OR DELETE ON "verifications"
  FOR EACH ROW EXECUTE FUNCTION legacy_read_only();

CREATE TRIGGER trg_invite_codes_read_only BEFORE INSERT OR UPDATE OR DELETE ON "invite_codes"
  FOR EACH ROW EXECUTE FUNCTION legacy_read_only();

CREATE TRIGGER trg_ccrs_categories_read_only BEFORE INSERT OR UPDATE OR DELETE ON "ccrs_categories"
  FOR EACH ROW EXECUTE FUNCTION legacy_read_only();
