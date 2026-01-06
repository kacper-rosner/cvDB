--! przygotowanie bazy danych
SET client_encoding TO 'UTF8';
CREATE SCHEMA IF NOT EXISTS users;
CREATE SCHEMA IF NOT EXISTS jobs;
CREATE SCHEMA IF NOT EXISTS files;
CREATE SCHEMA IF NOT EXISTS server;
CREATE DOMAIN azure_url AS VARCHAR(500) CHECK (VALUE ~ '^azure\.database\.com/.*');
