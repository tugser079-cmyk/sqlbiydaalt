

SELECT 
    e.inventory_code,
    e.name_mn,
    c.category_name,
    h.hall_name,
    ee.showcase_no
FROM exhibits e
JOIN categories c ON e.category_id = c.category_id
JOIN exhibition_exhibits ee ON e.exhibit_id = ee.exhibit_id
JOIN exhibitions ex ON ee.exhibition_id = ex.exhibition_id
JOIN halls h ON ex.hall_id = h.hall_id
WHERE e.current_status = 'EXHIBITED' AND ee.removed_date IS NULL;


SELECT 
    e.inventory_code,
    e.name_mn,
    COUNT(r.restoration_id) AS restoration_count,
    SUM(r.cost) AS total_repair_cost
FROM exhibits e
JOIN restorations r ON e.exhibit_id = r.exhibit_id
GROUP BY e.inventory_code, e.name_mn
HAVING COUNT(r.restoration_id) >= 2
ORDER BY total_repair_cost DESC;


SELECT 
    h.hall_id,
    h.hall_name,
    h.floor_number,
    COUNT(ee.exhibit_id) AS current_exhibit_count
FROM halls h
LEFT JOIN exhibitions ex ON h.hall_id = ex.hall_id AND ex.status = 'ONGOING'
LEFT JOIN exhibition_exhibits ee ON ex.exhibition_id = ee.exhibition_id AND ee.removed_date IS NULL
GROUP BY h.hall_id, h.hall_name, h.floor_number
ORDER BY current_exhibit_count DESC;


SELECT 
    inventory_code,
    name_mn,
    rarity_level,
    estimated_value_mnt
FROM exhibits
WHERE estimated_value_mnt > (
    SELECT AVG(estimated_value_mnt) FROM exhibits
)
AND rarity_level IN ('TREASURE', 'VERY_RARE')
ORDER BY estimated_value_mnt DESC;


SELECT 
    e.inventory_code,
    e.name_mn,
    e.rarity_level,
    e.current_status
FROM exhibits e
WHERE EXISTS (
    SELECT 1 
    FROM exhibit_loans el
    WHERE el.exhibit_id = e.exhibit_id 
      AND el.is_international = TRUE 
      AND el.loan_status = 'ACTIVE'
);

WITH PeriodStats AS (
    SELECT 
        p.period_name,
        COUNT(e.exhibit_id) AS exhibit_count,
        COALESCE(SUM(e.estimated_value_mnt), 0) AS total_period_value
    FROM historical_periods p
    LEFT JOIN exhibits e ON p.period_id = e.period_id
    GROUP BY p.period_name
)
SELECT 
    period_name,
    exhibit_count,
    total_period_value,
    ROUND(total_period_value / NULLIF(exhibit_count, 0), 2) AS avg_value_per_exhibit
FROM PeriodStats
ORDER BY total_period_value DESC;


SELECT 
    e.inventory_code,
    e.name_mn,
    e.category_id,
    e.estimated_value_mnt
FROM exhibits e
WHERE e.estimated_value_mnt > (
    SELECT AVG(sub.estimated_value_mnt)
    FROM exhibits sub
    WHERE sub.category_id = e.category_id
);


SELECT 
    e.inventory_code,
    e.name_mn,
    c.category_name,
    e.estimated_value_mnt,
    DENSE_RANK() OVER (
        PARTITION BY e.category_id 
        ORDER BY e.estimated_value_mnt DESC
    ) AS rank_in_category
FROM exhibits e
JOIN categories c ON e.category_id = c.category_id;


SELECT exhibit_id, inventory_code, name_mn 
FROM exhibits
WHERE current_status = 'IN_STORAGE'
EXCEPT
SELECT e.exhibit_id, e.inventory_code, e.name_mn
FROM exhibits e
JOIN exhibition_exhibits ee ON e.exhibit_id = ee.exhibit_id;


SELECT 
    e.inventory_code,
    e.name_mn,
    'Үзэсгэлэнд дэглэгдсэн' AS current_assignment,
    ex.title AS event_name
FROM exhibits e
JOIN exhibition_exhibits ee ON e.exhibit_id = ee.exhibit_id
JOIN exhibitions ex ON ee.exhibition_id = ex.exhibition_id
WHERE ee.removed_date IS NULL
UNION
SELECT 
    e.inventory_code,
    e.name_mn,
    'Гадаадад зээлээр гарсан' AS current_assignment,
    el.borrower_institution AS event_name
FROM exhibits e
JOIN exhibit_loans el ON e.exhibit_id = el.exhibit_id
WHERE el.loan_status = 'ACTIVE';


WITH RECURSIVE CategoryHierarchy AS (
    SELECT 
        category_id,
        category_name,
        parent_category_id,
        1 AS level,
        category_name::TEXT AS path
    FROM categories
    WHERE parent_category_id IS NULL
    UNION ALL
    SELECT 
        c.category_id,
        c.category_name,
        c.parent_category_id,
        ch.level + 1,
        CONCAT(ch.path, ' -> ', c.category_name)
    FROM categories c
    JOIN CategoryHierarchy ch ON c.parent_category_id = ch.category_id
)
SELECT level, path FROM CategoryHierarchy ORDER BY path;

SELECT 
    inventory_code,
    name_mn,
    estimated_value_mnt,
    NTILE(4) OVER (ORDER BY estimated_value_mnt DESC) AS value_quartile
FROM exhibits;

SELECT 
    o.aimag,
    COUNT(e.exhibit_id) AS total_finds,
    SUM(e.estimated_value_mnt) AS total_val
FROM origin_locations o
JOIN exhibits e ON o.location_id = e.origin_id
GROUP BY o.aimag
HAVING COUNT(e.exhibit_id) >= 2
ORDER BY total_val DESC;

SELECT 
    e.inventory_code,
    e.name_mn,
    e.material
FROM exhibits e
WHERE NOT EXISTS (
    SELECT 1 FROM restorations r WHERE r.exhibit_id = e.exhibit_id
);


SELECT 
    s.first_name,
    s.last_name,
    e.name_mn,
    r.cost,
    r.action_taken
FROM restorations r
JOIN staff s ON r.conservator_id = s.staff_id
JOIN exhibits e ON r.exhibit_id = e.exhibit_id
WHERE r.cost >= 1000000.00
ORDER BY r.cost DESC;


SELECT 
    h.hall_name,
    ROUND(AVG(ex.ticket_price), 2) AS avg_ticket_price
FROM halls h
LEFT JOIN exhibitions ex ON h.hall_id = ex.hall_id
WHERE h.is_climate_controlled = TRUE
GROUP BY h.hall_name;


SELECT 
    ex.title,
    sub.total_insured,
    ex.ticket_price
FROM exhibitions ex
JOIN (
    SELECT exhibition_id, SUM(insurance_amount) AS total_insured
    FROM exhibition_exhibits
    GROUP BY exhibition_id
) sub ON ex.exhibition_id = sub.exhibition_id
ORDER BY sub.total_insured DESC;


SELECT 
    emp.first_name || ' ' || emp.last_name AS employee_name,
    emp.role AS employee_role,
    COALESCE(mgr.first_name || ' ' || mgr.last_name, 'Дээд удирдлага') AS manager_name
FROM staff emp
LEFT JOIN staff mgr ON emp.manager_id = mgr.staff_id;

SELECT 
    history_id,
    exhibit_id,
    location_type,
    start_date,
    LAG(location_type) OVER (PARTITION BY exhibit_id ORDER BY start_date) AS prev_location,
    LAG(start_date) OVER (PARTITION BY exhibit_id ORDER BY start_date) AS prev_start_date
FROM exhibit_location_history
WHERE exhibit_id = 1
ORDER BY start_date;

SELECT exhibit_id, name_mn, inventory_code 
FROM exhibits 
WHERE period_id = 3
INTERSECT
SELECT exhibit_id, name_mn, inventory_code 
FROM exhibits 
WHERE exhibit_type = 'ARTIFACT';
