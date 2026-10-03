-- V2 TASK-01 §5.2: enums for the v2 data model (Spec §3, §5, §6). v1 "platform" and
-- "verification_result" are reused.
CREATE TYPE "user_role" AS ENUM ('citizen', 'moderator', 'admin', 'representative');

CREATE TYPE "user_status" AS ENUM ('active', 'suspended', 'deleted');

CREATE TYPE "app_language" AS ENUM ('gu', 'en');

CREATE TYPE "consent_purpose" AS ENUM ('core_service', 'share_with_representatives', 'share_with_amc_handoff', 'notifications');

CREATE TYPE "issue_status" AS ENUM ('reported', 'sent', 'acknowledged', 'in_progress', 'marked_fixed', 'verified', 'reopened', 'rejected', 'merged');

CREATE TYPE "issue_visibility" AS ENUM ('public', 'hidden');

CREATE TYPE "issue_photo_kind" AS ENUM ('report', 'after', 'verification');

CREATE TYPE "issue_event_type" AS ENUM ('status_change', 'comment', 'ccrs_linked', 'escalated', 'merged', 'rejected');

CREATE TYPE "actor_role" AS ENUM ('citizen', 'moderator', 'admin', 'representative', 'system');
