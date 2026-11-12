
CREATE TABLE categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE,
    parent_category_id INT REFERENCES categories(category_id) ON DELETE SET NULL,
    description TEXT
);

-- 2. ОН ЦАГИЙН ҮЕ (Historical Periods)
CREATE TABLE historical_periods (
    period_id SERIAL PRIMARY KEY,
    period_name VARCHAR(100) NOT NULL UNIQUE,
    start_century INT,
    end_century INT,
    era_description TEXT
);

-- 3. ОЛДСОН ГАЗАР (Origin / Discovery Locations)
CREATE TABLE origin_locations (
    location_id SERIAL PRIMARY KEY,
    aimag VARCHAR(100) NOT NULL,
    soum VARCHAR(100) NOT NULL,
    site_name VARCHAR(150) NOT NULL,
    gps_coordinates VARCHAR(100),
    discovery_year INT CHECK (discovery_year <= EXTRACT(YEAR FROM CURRENT_DATE))
);

-- 4. ХАРИУЦАГЧ / АЖИЛТАН (Staff / Curators - Рекурсив холбоотой: ахлах куратор)
CREATE TABLE staff (
    staff_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    role VARCHAR(50) NOT NULL CHECK (role IN ('Curator', 'Conservator', 'Registrar', 'Security', 'Manager')),
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20) NOT NULL,
    manager_id INT REFERENCES staff(staff_id) ON DELETE SET NULL
);

-- 5. ТАНХИМ (Exhibition Halls)
CREATE TABLE halls (
    hall_id SERIAL PRIMARY KEY,
    hall_name VARCHAR(100) NOT NULL UNIQUE,
    floor_number INT NOT NULL CHECK (floor_number BETWEEN 1 AND 5),
    max_capacity INT NOT NULL CHECK (max_capacity > 0),
    is_climate_controlled BOOLEAN DEFAULT TRUE NOT NULL
);

-- 6. ҮЗЭСГЭЛЭН (Exhibitions)
CREATE TABLE exhibitions (
    exhibition_id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    hall_id INT REFERENCES halls(hall_id) ON DELETE RESTRICT,
    curator_id INT REFERENCES staff(staff_id) ON DELETE RESTRICT,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    ticket_price DECIMAL(10, 2) DEFAULT 0.00 CHECK (ticket_price >= 0),
    status VARCHAR(20) DEFAULT 'PLANNED' CHECK (status IN ('PLANNED', 'ONGOING', 'CLOSED')),
    CONSTRAINT chk_exhibition_dates CHECK (end_date >= start_date)
);

-- 7. ҮЗМЭР (Exhibits - ISA зарчим, ховор байдлын түвшин)
CREATE TABLE exhibits (
    exhibit_id SERIAL PRIMARY KEY,
    inventory_code VARCHAR(50) NOT NULL UNIQUE, -- Жишээ: MUS-2024-001
    name_mn VARCHAR(200) NOT NULL,
    name_en VARCHAR(200),
    category_id INT NOT NULL REFERENCES categories(category_id) ON DELETE RESTRICT,
    period_id INT REFERENCES historical_periods(period_id) ON DELETE SET NULL,
    origin_id INT REFERENCES origin_locations(location_id) ON DELETE SET NULL,
    rarity_level VARCHAR(30) NOT NULL DEFAULT 'NORMAL' 
        CHECK (rarity_level IN ('NORMAL', 'RARE', 'VERY_RARE', 'TREASURE')), -- Нэн ховор үзмэр
    exhibit_type VARCHAR(30) NOT NULL 
        CHECK (exhibit_type IN ('ARTIFACT', 'ARTWORK', 'MANUSCRIPT')), -- ISA ялгагч
    material VARCHAR(100),
    weight_kg DECIMAL(8, 2) CHECK (weight_kg > 0),
    estimated_value_mnt DECIMAL(15, 2) CHECK (estimated_value_mnt >= 0),
    current_status VARCHAR(30) NOT NULL DEFAULT 'IN_STORAGE'
        CHECK (current_status IN ('IN_STORAGE', 'EXHIBITED', 'ON_LOAN', 'UNDER_RESTORATION')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 8. СУЛ ENTITY: ҮЗМЭРИЙН ЗУРАГ / БАРИМТЖУУЛАЛТ (Exhibit Photos - Weak Entity)
-- Эзэн түлхүүр exhibit_id-тай хамт нийлмэл PK (exhibit_id, photo_seq) үүсгэнэ.
CREATE TABLE exhibit_photos (
    exhibit_id INT REFERENCES exhibits(exhibit_id) ON DELETE CASCADE,
    photo_seq INT NOT NULL,
    photo_url VARCHAR(255) NOT NULL,
    caption TEXT,
    taken_date DATE DEFAULT CURRENT_DATE,
    PRIMARY KEY (exhibit_id, photo_seq)
);

-- 9. БАЙРШЛЫН ТҮҮХ (Location History - Онцгой дүрэм 1 хэрэгжүүлэх суурь)
-- "Үзмэр нэг үед зөвхөн нэг байршилд; түүхийг огноотой хадгална"
CREATE TABLE exhibit_location_history (
    history_id SERIAL PRIMARY KEY,
    exhibit_id INT NOT NULL REFERENCES exhibits(exhibit_id) ON DELETE CASCADE,
    location_type VARCHAR(30) NOT NULL 
        CHECK (location_type IN ('STORAGE', 'EXHIBITION', 'LOAN', 'RESTORATION')),
    location_detail VARCHAR(200) NOT NULL, -- Жишээ: Фонд А, Танхим 2-Витрин 5, Гадаад музей
    start_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    end_date TIMESTAMP, -- NULL байвал тухайн байршилд одоо байгаа гэсэн үг
    handler_staff_id INT REFERENCES staff(staff_id) ON DELETE SET NULL,
    notes TEXT,
    CONSTRAINT chk_location_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

-- 10. АТРИБУТТАЙ M:N ХОЛБОО: ҮЗЭСГЭЛЭН-ҮЗМЭР (Exhibition_Exhibits)
CREATE TABLE exhibition_exhibits (
    exhibition_id INT NOT NULL REFERENCES exhibitions(exhibition_id) ON DELETE CASCADE,
    exhibit_id INT NOT NULL REFERENCES exhibits(exhibit_id) ON DELETE CASCADE,
    showcase_no VARCHAR(50), -- Витриний дугаар
    assigned_date DATE NOT NULL DEFAULT CURRENT_DATE,
    removed_date DATE,
    insurance_amount DECIMAL(15, 2) NOT NULL DEFAULT 0.00 CHECK (insurance_amount >= 0),
    display_notes TEXT,
    PRIMARY KEY (exhibition_id, exhibit_id)
);

-- 11. ЗЭЭЛ (Loans - Онцгой дүрэм 2 хэрэгжүүлэх суурь)
-- "Нэн ховор үзмэрийг гадаадад зээлүүлэхэд 2 шатны зөвшөөрөл шаардлагатай"
CREATE TABLE exhibit_loans (
    loan_id SERIAL PRIMARY KEY,
    exhibit_id INT NOT NULL REFERENCES exhibits(exhibit_id) ON DELETE RESTRICT,
    borrower_institution VARCHAR(200) NOT NULL,
    is_international BOOLEAN NOT NULL DEFAULT FALSE,
    loan_start DATE NOT NULL,
    loan_end DATE NOT NULL,
    academic_council_approved BOOLEAN NOT NULL DEFAULT FALSE, -- 1-р шат: Эрдмийн зөвлөл
    ministry_approved BOOLEAN NOT NULL DEFAULT FALSE,          -- 2-р шат: Соёлын яам
    loan_status VARCHAR(20) NOT NULL DEFAULT 'REQUESTED'
        CHECK (loan_status IN ('REQUESTED', 'APPROVED', 'ACTIVE', 'RETURNED', 'REJECTED')),
    CONSTRAINT chk_loan_dates CHECK (loan_end >= loan_start)
);

-- 12. СЭРГЭЭН ЗАСВАРЛАЛТ (Restoration)
CREATE TABLE restorations (
    restoration_id SERIAL PRIMARY KEY,
    exhibit_id INT NOT NULL REFERENCES exhibits(exhibit_id) ON DELETE RESTRICT,
    conservator_id INT NOT NULL REFERENCES staff(staff_id) ON DELETE RESTRICT,
    condition_before TEXT NOT NULL,
    action_taken TEXT,
    condition_after TEXT,
    start_date DATE NOT NULL,
    completion_date DATE,
    cost DECIMAL(12, 2) DEFAULT 0.00 CHECK (cost >= 0),
    CONSTRAINT chk_restoration_dates CHECK (completion_date IS NULL OR completion_date >= start_date)
);
