
SET client_encoding TO 'UTF8';
CREATE SCHEMA IF NOT EXISTS users;
CREATE SCHEMA IF NOT EXISTS jobs;
CREATE SCHEMA IF NOT EXISTS files;
CREATE SCHEMA IF NOT EXISTS server;

CREATE DOMAIN azure_url AS VARCHAR(500) CHECK (VALUE ~ '^azure\.database\.com/.*');


CREATE TABLE server.IPWhitelist (    
    ip INET PRIMARY KEY,    
    canConsole BOOLEAN DEFAULT FALSE,    
    canDB BOOLEAN DEFAULT FALSE,    
    canClient BOOLEAN DEFAULT TRUE
);

CREATE TABLE server.Website (    
    websiteName VARCHAR(255) PRIMARY KEY,    
    htmlPath azure_url NOT NULL,    
    cssPath azure_url NOT NULL,    
    czContent azure_url,    
    plContent azure_url
);

CREATE TABLE users.Themes (
     language VARCHAR(50),
     theme VARCHAR(50),
     PRIMARY KEY (language, theme)
);

CREATE TABLE users.Regions (
     country VARCHAR(100),
     region VARCHAR(100),
     maxDistance INT NOT NULL,
     PRIMARY KEY (country, region)
);

CREATE TABLE files.Permissions (    
    permissionLevel INT PRIMARY KEY,
    read_perm BOOLEAN DEFAULT TRUE,
    delete_perm BOOLEAN DEFAULT FALSE,
    share_perm BOOLEAN DEFAULT FALSE
);

CREATE TABLE jobs.JobDict (    
    jobid SERIAL PRIMARY KEY,    
    title_en VARCHAR(255) NOT NULL,
    skill_en VARCHAR(255) NOT NULL,
    UNIQUE(title_en, skill_en) 
);


CREATE TABLE users.AccountTypeWebsite (
    accountType VARCHAR(50) PRIMARY KEY,
    websiteName VARCHAR(255) REFERENCES server.Website(websiteName)
);

CREATE TABLE users.User (
     login VARCHAR(255) PRIMARY KEY,
     password VARCHAR(255) NOT NULL,
     salt VARCHAR(255) NOT NULL,
     age INT,
     university VARCHAR(255),
     nationality VARCHAR(100),
     isWorking BOOLEAN DEFAULT FALSE,
     isHiring BOOLEAN DEFAULT FALSE,
     language VARCHAR(50),
     theme VARCHAR(50),
     accountType VARCHAR(50) REFERENCES users.AccountTypeWebsite(accountType),
     FOREIGN KEY (language, theme) REFERENCES users.Themes(language, theme)
);

CREATE TABLE server.Logs (
    date DATE NOT NULL,
    "user" VARCHAR(255) REFERENCES users.User(login),
    message VARCHAR(255),
    ip INET NOT NULL,
    type VARCHAR(255) NOT NULL,
    PRIMARY KEY (date, "user")
);

CREATE TABLE users.UserSearchSettings (
     login VARCHAR(255) REFERENCES users.User(login),
     priority INT,
     country VARCHAR(100),
     region VARCHAR(100),
     distance INT,
     PRIMARY KEY (login, priority),
     FOREIGN KEY (country, region) REFERENCES users.Regions(country, region)
);

CREATE TABLE files.Documents (    
    did INT PRIMARY KEY,
    owner VARCHAR(255) REFERENCES users.User(login) ON UPDATE CASCADE ON DELETE CASCADE,
    creation DATE DEFAULT CURRENT_DATE,
    title VARCHAR(255),
    path azure_url UNIQUE NOT NULL
);

CREATE TABLE jobs.JobTranslations (
    jobid INT REFERENCES jobs.JobDict(jobid) ON DELETE CASCADE,
    language VARCHAR(50),
    local_title VARCHAR(255),
    local_skill VARCHAR(255),
    PRIMARY KEY (jobid, language)
);

CREATE TABLE jobs.JobsPL (    
    jobid INT PRIMARY KEY REFERENCES jobs.JobDict(jobid),    
    countT0 INT DEFAULT 0,    
    countT1 INT DEFAULT 0,    
    countT2 INT DEFAULT 0
);

CREATE TABLE jobs.JobsCZ (    
    jobid INT PRIMARY KEY REFERENCES jobs.JobDict(jobid),    
    countT0 INT DEFAULT 0,    
    countT1 INT DEFAULT 0,    
    countT2 INT DEFAULT 0
);

CREATE TABLE files.DocumentPerms (    
    pid INT PRIMARY KEY,    
    did INT REFERENCES files.Documents(did) ON UPDATE CASCADE ON DELETE CASCADE,    
    login VARCHAR(255) REFERENCES users.User(login),    
    permissionLevel INT REFERENCES files.Permissions(permissionLevel)
);
