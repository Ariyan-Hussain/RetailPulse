-- DESTRUCTIVE: permanently removes the RetailPulse database and all its data.
-- Run only when you intentionally want a complete clean import.
-- This script does not recreate the database; run 01_create_database.sql next.
DROP DATABASE IF EXISTS retailpulse;
