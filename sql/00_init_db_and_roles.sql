DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bank_owner') THEN CREATE ROLE bank_owner LOGIN; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'grp_analyste') THEN CREATE ROLE grp_analyste NOLOGIN; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'grp_support')  THEN CREATE ROLE grp_support NOLOGIN;  END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'grp_appli')    THEN CREATE ROLE grp_appli NOLOGIN;    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'grp_auditeur') THEN CREATE ROLE grp_auditeur NOLOGIN; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_analyste') THEN CREATE ROLE usr_analyste LOGIN IN ROLE grp_analyste; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_support')  THEN CREATE ROLE usr_support  LOGIN IN ROLE grp_support;  END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_appli')    THEN CREATE ROLE usr_appli    LOGIN IN ROLE grp_appli;    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_auditeur') THEN CREATE ROLE usr_auditeur LOGIN IN ROLE grp_auditeur; END IF;
END $$;

DROP DATABASE IF EXISTS bankdb;
CREATE DATABASE bankdb OWNER bank_owner;

\c bankdb
CREATE SCHEMA IF NOT EXISTS core AUTHORIZATION bank_owner;
CREATE SCHEMA IF NOT EXISTS audit AUTHORIZATION bank_owner;
CREATE EXTENSION IF NOT EXISTS pg_trgm SCHEMA core;
