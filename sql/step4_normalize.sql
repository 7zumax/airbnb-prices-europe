-- =====================================================================
-- Step 4: SQL Normalization — Airbnb Prices in European Cities
-- Input : airbnb_staging (cleaned data imported from airbnb_cleaned.xlsx)
-- Output: 6 normalized tables in 3NF with primary and foreign keys
-- =====================================================================

USE AirbnbEurope;
GO

-- 4C: Creating the normalized tables ---------------------------------
DROP TABLE IF EXISTS Listings, Neighbourhoods, PropertyTypes, RoomTypes, DayTypes, Cities;
GO

CREATE TABLE Cities (
    city_id    INT IDENTITY(1,1) PRIMARY KEY,
    city_name  NVARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE DayTypes (
    day_type_id    INT IDENTITY(1,1) PRIMARY KEY,
    day_type_name  NVARCHAR(20) NOT NULL UNIQUE
);

CREATE TABLE RoomTypes (
    room_type_id    INT IDENTITY(1,1) PRIMARY KEY,
    room_type_name  NVARCHAR(50) NOT NULL UNIQUE,
    is_shared       BIT NOT NULL,
    is_private      BIT NOT NULL
);

CREATE TABLE PropertyTypes (
    property_type_id    INT IDENTITY(1,1) PRIMARY KEY,
    property_type_name  NVARCHAR(200) NOT NULL UNIQUE
);

CREATE TABLE Neighbourhoods (
    neighbourhood_id    INT IDENTITY(1,1) PRIMARY KEY,
    neighbourhood_name  NVARCHAR(200) NOT NULL,
    city_id             INT NOT NULL FOREIGN KEY REFERENCES Cities(city_id),
    CONSTRAINT UQ_Neighbourhood UNIQUE (neighbourhood_name, city_id)
);

CREATE TABLE Listings (
    listing_id                  INT IDENTITY(1,1) PRIMARY KEY,
    neighbourhood_id            INT NOT NULL FOREIGN KEY REFERENCES Neighbourhoods(neighbourhood_id),
    room_type_id                INT NOT NULL FOREIGN KEY REFERENCES RoomTypes(room_type_id),
    property_type_id            INT NOT NULL FOREIGN KEY REFERENCES PropertyTypes(property_type_id),
    day_type_id                 INT NOT NULL FOREIGN KEY REFERENCES DayTypes(day_type_id),
    real_sum                    FLOAT NOT NULL,
    person_capacity             INT,
    bedrooms                    INT,
    host_is_superhost           BIT,
    multi                       BIT,
    biz                         BIT,
    cleanliness_rating          FLOAT,
    guest_satisfaction_overall  FLOAT,
    dist                        FLOAT,
    metro_dist                  FLOAT,
    attr_index                  FLOAT,
    attr_index_norm             FLOAT,
    rest_index                  FLOAT,
    rest_index_norm             FLOAT,
    lat                         FLOAT,
    lng                         FLOAT,
    amenities_count             FLOAT,
    number_of_reviews           FLOAT,
    review_scores_rating        FLOAT,
    availability_365            FLOAT,
    is_matched                  BIT
);
GO

-- 4D: Filling the lookup tables ---------------------------------------
INSERT INTO Cities (city_name)
SELECT DISTINCT city FROM airbnb_staging;

INSERT INTO DayTypes (day_type_name)
SELECT DISTINCT day_type FROM airbnb_staging;

INSERT INTO RoomTypes (room_type_name, is_shared, is_private)
SELECT DISTINCT room_type, room_shared, room_private FROM airbnb_staging;

INSERT INTO PropertyTypes (property_type_name)
SELECT DISTINCT property_type FROM airbnb_staging;

INSERT INTO Neighbourhoods (neighbourhood_name, city_id)
SELECT DISTINCT s.neighbourhood, c.city_id
FROM airbnb_staging s
JOIN Cities c ON s.city = c.city_name;
GO

-- 4E: Filling the main Listings table ---------------------------------
INSERT INTO Listings (
    neighbourhood_id, room_type_id, property_type_id, day_type_id,
    real_sum, person_capacity, bedrooms, host_is_superhost, multi, biz,
    cleanliness_rating, guest_satisfaction_overall, dist, metro_dist,
    attr_index, attr_index_norm, rest_index, rest_index_norm, lat, lng,
    amenities_count, number_of_reviews, review_scores_rating, availability_365, is_matched
)
SELECT
    n.neighbourhood_id, r.room_type_id, p.property_type_id, d.day_type_id,
    s.realSum, s.person_capacity, s.bedrooms, s.host_is_superhost, s.multi, s.biz,
    s.cleanliness_rating, s.guest_satisfaction_overall, s.dist, s.metro_dist,
    s.attr_index, s.attr_index_norm, s.rest_index, s.rest_index_norm, s.lat, s.lng,
    s.amenities_count, s.number_of_reviews, s.review_scores_rating, s.availability_365, s.is_matched
FROM airbnb_staging s
JOIN Cities c         ON s.city = c.city_name
JOIN Neighbourhoods n ON s.neighbourhood = n.neighbourhood_name AND n.city_id = c.city_id
JOIN RoomTypes r      ON s.room_type = r.room_type_name
JOIN PropertyTypes p  ON s.property_type = p.property_type_name
JOIN DayTypes d       ON s.day_type = d.day_type_name;
GO

-- 4F: Checking the result ---------------------------------------------
SELECT COUNT(*) AS total_listings FROM Listings;

SELECT c.city_name, COUNT(*) AS listings, ROUND(AVG(l.real_sum), 2) AS avg_price
FROM Listings l
JOIN Neighbourhoods n ON l.neighbourhood_id = n.neighbourhood_id
JOIN Cities c         ON n.city_id = c.city_id
GROUP BY c.city_name
ORDER BY avg_price DESC;
GO
