CREATE TABLE jobs.JobDict (    
jobid SERIAL PRIMARY KEY,    
title_en VARCHAR(255) NOT NULL,
skill_en VARCHAR(255) NOT NULL,
UNIQUE(title_en, skill_en) );

CREATE TABLE jobs.JobTranslations (
jobid INT REFERENCES jobs.JobDict(jobid) ON DELETE CASCADE,
lang_code CHAR(2),
local_title VARCHAR(255),
local_skill VARCHAR(255),
PRIMARY KEY (jobid, lang_code)
);

CREATE TABLE jobs.JobsPL (    
jobid INT PRIMARY KEY REFERENCES jobs.JobDict(jobid),    
countT0 INT DEFAULT 0,    
countT1 INT DEFAULT 0,    
countT2 INT DEFAULT 0);

CREATE TABLE jobs.JobsCZ (    
jobid INT PRIMARY KEY REFERENCES jobs.JobDict(jobid),    
countT0 INT DEFAULT 0,    
countT1 INT DEFAULT 0,    
countT2 INT DEFAULT 0);
