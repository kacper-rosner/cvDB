CREATE TABLE users.Themes (
     language VARCHAR(50),
     theme VARCHAR(50),
     PRIMARY KEY (language, theme)
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
     accountType VARCHAR(50) REFERENCES users.AccountType(accountType),
     FOREIGN KEY (language, theme) REFERENCES users.Themes(language, theme)
);

CREATE TABLE users.Regions (
     country VARCHAR(100),
     region VARCHAR(100),
     maxDistance INT NOT NULL,
     PRIMARY KEY (country, region)
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

