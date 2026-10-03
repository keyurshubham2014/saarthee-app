-- gen_random_uuid() is built in on PostgreSQL >= 13 (running 17.6), so no pgcrypto.
CREATE TYPE "source_tag" AS ENUM ('rwa', 'activist', 'social', 'network', 'unknown');

CREATE TYPE "verification_result" AS ENUM ('fixed', 'not_fixed');

CREATE TYPE "photo_purpose" AS ENUM ('report', 'verification');

CREATE TYPE "storage_driver" AS ENUM ('local', 'cloudflare_r2');

CREATE TYPE "reminder_channel" AS ENUM ('whatsapp_manual');

CREATE TYPE "exclusion_reason" AS ENUM ('test', 'invalid', 'duplicate', 'other');

CREATE TYPE "platform" AS ENUM ('android', 'ios');
