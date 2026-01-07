CREATE TABLE server.IPWhitelist (    
ip INET PRIMARY KEY,    
canConsole BOOLEAN DEFAULT FALSE,    
canDB BOOLEAN DEFAULT FALSE,    
canClient BOOLEAN DEFAULT TRUE);
!-- if no record => canCLient, ! canConsole, ! canDB

CREATE TABLE server.Website (    
websiteName VARCHAR(255) PRIMARY KEY,    
htmlPath azure_url NOT NULL,    
cssPath azure_url NOT NULL,    
czContent azure_url,    
plContent azure_url);
