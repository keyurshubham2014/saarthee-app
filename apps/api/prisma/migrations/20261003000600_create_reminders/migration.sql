CREATE TABLE "reminders" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "complaint_id" UUID NOT NULL,
    "token_hash" CHAR(64) NOT NULL,
    "channel" "reminder_channel" NOT NULL DEFAULT 'whatsapp_manual',
    "sent_by" UUID NOT NULL,
    "sent_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMPTZ(6),
    "revoked_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "reminders_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "idx_reminders_complaint_sent" ON "reminders"("complaint_id", "sent_at" DESC);

CREATE INDEX "idx_reminders_sent_by" ON "reminders"("sent_by");

CREATE UNIQUE INDEX "uq_reminders_token_hash" ON "reminders"("token_hash");

ALTER TABLE "reminders" ADD CONSTRAINT "reminders_complaint_id_fkey" FOREIGN KEY ("complaint_id") REFERENCES "complaints"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "reminders" ADD CONSTRAINT "reminders_sent_by_fkey" FOREIGN KEY ("sent_by") REFERENCES "admin_users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Hand-written: token hash format CHECK (04 §3.6).
ALTER TABLE "reminders" ADD CONSTRAINT "ck_reminders_token_hash" CHECK (token_hash ~ '^[0-9a-f]{64}$');
