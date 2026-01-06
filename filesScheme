CREATE TABLE files.Permissions (    
permissionLevel INT PRIMARY KEY,
read_perm BOOLEAN DEFAULT TRUE,
delete_perm BOOLEAN DEFAULT FALSE,
share_perm BOOLEAN DEFAULT FALSE);

CREATE TABLE files.Documents (    
did INT PRIMARY KEY,
owner VARCHAR(255) REFERENCES users.User(login) ON UPDATE CASCADE ON DELETE CASCADE,
creation DATE DEFAULT CURRENT_DATE,
title VARCHAR(255),
path azure_url UNIQUE NOT NULL);

CREATE TABLE files.DocumentPerms (    
pid INT PRIMARY KEY,    
did INT REFERENCES files.Documents(did) ON UPDATE CASCADE ON DELETE CASCADE,    
login VARCHAR(255) REFERENCES users.User(login),    
permissionLevel INT REFERENCES files.Permissions(permissionLevel));

!-- pid może być potrzebne do logów
