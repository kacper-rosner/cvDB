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

CREATE TABLE server.Logs (
    date DATE NOT NULL,
    user VARCHAR(255) REFERENCES users.user(login),
    message VARCHAR(255),
    ip INET NOT NULL,
    type VARCHAR(255) NOT NULL,
    PRIMARY KEY (date,user)
);
