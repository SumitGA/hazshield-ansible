-- migrations/0004_grants.sql
-- Codifies the hand-applied fix from the Session 2 permission incident.
-- Migrations run as postgres; tables are owned by postgres; the app role
-- needs explicit grants, both on existing tables and on any table a
-- FUTURE migration creates (that's the DEFAULT PRIVILEGES half).

GRANT USAGE ON SCHEMA public TO hazshield;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO hazshield;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO hazshield;

-- Not strictly needed today (all PKs are UUIDs, no sequences), but free
-- insurance for any future serial/identity column:
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO hazshield;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO hazshield;
