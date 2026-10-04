-- V2 app_settings (REQ-D-011; single DDL from TASK-10 §5.2). Created by TASK-09 because it landed first;
-- TASK-10 must skip its own CREATE. Keys are an allow-list in code (APP_SETTING_KEYS); missing key ⇒ default.
CREATE TABLE IF NOT EXISTS "app_settings" (
    "key" TEXT NOT NULL,
    "value" JSONB NOT NULL,
    "updated_by" UUID,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "pk_app_settings" PRIMARY KEY ("key"),
    CONSTRAINT "ck_app_settings_key" CHECK ("key" ~ '^[a-z][a-z0-9_]{2,63}$')
);
