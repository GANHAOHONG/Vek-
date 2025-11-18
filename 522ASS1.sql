
-- ========================================================================
-- 第一部分：去范式化表创建
-- ========================================================================

-- 1. 客户价值分析去范式化表
DROP TABLE IF EXISTS customer_analysis_agg;
CREATE TABLE customer_analysis_agg AS
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.email,
    a.address,
    ci.city,
    co.country,
    -- 客户基本统计
    COUNT(r.rental_id) AS total_rentals,
    COUNT(p.payment_id) AS total_payments,
    COALESCE(SUM(p.amount), 0) AS total_spent,
    COALESCE(AVG(p.amount), 0) AS avg_payment_amount,
    -- 时间分析
    MIN(r.rental_date) AS first_rental_date,
    MAX(r.rental_date) AS last_rental_date,
    EXTRACT(DAYS FROM (MAX(r.rental_date) - MIN(r.rental_date))) AS customer_lifetime_days,
    EXTRACT(DAYS FROM (CURRENT_DATE - MAX(r.rental_date))) AS days_since_last_rental,
    -- 价值分层
    CASE 
        WHEN COUNT(p.payment_id) >= 40 AND SUM(p.amount) >= 200 THEN 'VIP Customer'
        WHEN COUNT(p.payment_id) >= 25 AND SUM(p.amount) >= 150 THEN 'Loyal Customer'
        WHEN COUNT(p.payment_id) >= 15 AND SUM(p.amount) >= 100 THEN 'Regular Customer'
        WHEN COUNT(p.payment_id) >= 5 THEN 'Occasional Customer'
        ELSE 'New/Inactive Customer'
    END AS customer_segment
FROM customer c
LEFT JOIN address a ON c.address_id = a.address_id
LEFT JOIN city ci ON a.city_id = ci.city_id
LEFT JOIN country co ON ci.country_id = co.country_id
LEFT JOIN rental r ON c.customer_id = r.customer_id
LEFT JOIN payment p ON r.rental_id = p.rental_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.email, a.address, ci.city, co.country;

-- 2. 影片表现分析去范式化表
DROP TABLE IF EXISTS film_performance_agg;
CREATE TABLE film_performance_agg AS
SELECT 
    f.film_id,
    f.title,
    f.description,
    f.length,
    f.rental_rate,
    f.rating,
    f.release_year,
    c.name AS category_name,
    -- 租赁统计
    COUNT(r.rental_id) AS total_rentals,
    COUNT(i.inventory_id) AS total_inventory,
    COUNT(r.rental_id) * 1.0 / NULLIF(COUNT(i.inventory_id), 0) AS rental_to_inventory_ratio,
    -- 财务表现
    COALESCE(SUM(p.amount), 0) AS total_revenue,
    COALESCE(AVG(p.amount), 0) AS avg_revenue_per_rental,
    f.rental_rate * COUNT(r.rental_id) AS potential_revenue,
    (COALESCE(SUM(p.amount), 0) - (f.rental_rate * COUNT(r.rental_id))) AS revenue_gap,
    -- 绩效评级
    CASE 
        WHEN COUNT(r.rental_id) >= 30 THEN 'High Performer'
        WHEN COUNT(r.rental_id) >= 20 THEN 'Medium Performer'
        WHEN COUNT(r.rental_id) >= 10 THEN 'Low Performer'
        ELSE 'Poor Performer'
    END AS performance_tier
FROM film f
LEFT JOIN film_category fc ON f.film_id = fc.film_id
LEFT JOIN category c ON fc.category_id = c.category_id
LEFT JOIN inventory i ON f.film_id = i.film_id
LEFT JOIN rental r ON i.inventory_id = r.inventory_id
LEFT JOIN payment p ON r.rental_id = p.rental_id
GROUP BY f.film_id, f.title, f.description, f.length, f.rental_rate, f.rating, f.release_year, c.name;

-- 3. 运营效率分析去范式化表
DROP TABLE IF EXISTS operation_efficiency_agg;
CREATE TABLE operation_efficiency_agg AS
SELECT 
    co.country,
    ci.city,
    s.store_id,
    st.first_name || ' ' || st.last_name AS store_manager,
    -- 门店运营统计
    COUNT(DISTINCT c.customer_id) AS total_customers,
    COUNT(r.rental_id) AS total_rentals,
    COALESCE(SUM(p.amount), 0) AS total_revenue,
    COALESCE(AVG(p.amount), 0) AS avg_transaction_value,
    -- 地理分析
    COUNT(DISTINCT a.address_id) AS served_addresses,
    COUNT(DISTINCT f.film_id) AS unique_films_available,
    -- 效率指标
    CASE 
        WHEN SUM(p.amount) >= 5000 THEN 'High Efficiency'
        WHEN SUM(p.amount) >= 3000 THEN 'Medium Efficiency'
        WHEN SUM(p.amount) >= 1000 THEN 'Low Efficiency'
        ELSE 'Poor Efficiency'
    END AS store_efficiency_tier
FROM store s
LEFT JOIN staff st ON s.manager_staff_id = st.staff_id
LEFT JOIN address a ON s.address_id = a.address_id
LEFT JOIN city ci ON a.city_id = ci.city_id
LEFT JOIN country co ON ci.country_id = co.country_id
LEFT JOIN inventory i ON s.store_id = i.store_id
LEFT JOIN rental r ON i.inventory_id = r.inventory_id
LEFT JOIN customer c ON r.customer_id = c.customer_id
LEFT JOIN payment p ON r.rental_id = p.rental_id
LEFT JOIN film f ON i.film_id = f.film_id
GROUP BY co.country, ci.city, s.store_id, st.first_name, st.last_name;

-- ========================================================================
-- 第二部分：数据完整性验证
-- ========================================================================

-- 验证数据完整性
DO $$
BEGIN
    RAISE NOTICE '数据去范式化完成，正在验证数据质量...';
    RAISE NOTICE '客户分析表记录数: %', (SELECT COUNT(*) FROM customer_analysis_agg);
    RAISE NOTICE '影片表现表记录数: %', (SELECT COUNT(*) FROM film_performance_agg);
    RAISE NOTICE '运营效率表记录数: %', (SELECT COUNT(*) FROM operation_efficiency_agg);
    RAISE NOTICE '数据验证完成！可以开始执行分析查询。';
END $$;

-- ========================================================================
-- 第三部分：三个核心分析查询
-- ========================================================================

-- 分析查询 1：客户价值分层与保留分析
-- ========================================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========== 客户价值分层与保留分析 ==========';
    RAISE NOTICE '';
END $$;

-- 1.1 客户价值分层概览
SELECT 
    customer_segment,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customer_analysis_agg), 2) AS percentage,
    ROUND(AVG(total_spent), 2) AS avg_spent,
    ROUND(AVG(total_rentals), 1) AS avg_rentals,
    ROUND(AVG(days_since_last_rental), 1) AS avg_days_since_last_rental
FROM customer_analysis_agg
GROUP BY customer_segment
ORDER BY avg_spent DESC;

-- 1.2 Top 10 高价值客户
SELECT 
    customer_name,
    customer_segment,
    total_spent,
    total_rentals,
    days_since_last_rental,
    city || ', ' || country AS location
FROM customer_analysis_agg
WHERE customer_segment IN ('VIP Customer', 'Loyal Customer')
ORDER BY total_spent DESC
LIMIT 10;

-- 1.3 客户流失风险分析
SELECT 
    customer_segment,
    CASE 
        WHEN days_since_last_rental > 180 THEN 'High Risk'
        WHEN days_since_last_rental > 90 THEN 'Medium Risk'
        WHEN days_since_last_rental > 30 THEN 'Low Risk'
        ELSE 'Active'
    END AS churn_risk,
    COUNT(*) AS customer_count,
    ROUND(AVG(total_spent), 2) AS avg_spent
FROM customer_analysis_agg
GROUP BY customer_segment, 
    CASE 
        WHEN days_since_last_rental > 180 THEN 'High Risk'
        WHEN days_since_last_rental > 90 THEN 'Medium Risk'
        WHEN days_since_last_rental > 30 THEN 'Low Risk'
        ELSE 'Active'
    END
ORDER BY customer_segment, churn_risk;

-- 分析查询 2：影片表现分析与库存优化
-- ========================================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========== 影片表现分析与库存优化 ==========';
    RAISE NOTICE '';
END $$;

-- 2.1 按分类的影片表现排行
SELECT 
    category_name,
    COUNT(*) AS total_films,
    ROUND(AVG(total_rentals), 1) AS avg_rentals,
    ROUND(AVG(total_revenue), 2) AS avg_revenue,
    ROUND(AVG(rental_to_inventory_ratio), 2) AS avg_utilization_rate,
    SUM(CASE WHEN performance_tier = 'High Performer' THEN 1 ELSE 0 END) AS high_performers
FROM film_performance_agg
GROUP BY category_name
HAVING COUNT(*) > 5  -- 只显示有足够样本的分类
ORDER BY avg_revenue DESC;

-- 2.2 Top 10 盈利影片
SELECT 
    title,
    category_name,
    total_rentals,
    total_revenue,
    performance_tier,
    CASE 
        WHEN total_inventory > 0 THEN ROUND((total_rentals * 1.0 / total_inventory) * 100, 1) || '%'
        ELSE 'N/A'
    END AS inventory_utilization
FROM film_performance_agg
ORDER BY total_revenue DESC
LIMIT 10;

-- 2.3 库存效率分析
SELECT 
    performance_tier,
    COUNT(*) AS film_count,
    ROUND(AVG(total_rentals), 1) AS avg_rentals,
    ROUND(AVG(total_inventory), 1) AS avg_inventory,
    ROUND(AVG(rental_to_inventory_ratio), 2) AS avg_efficiency_ratio,
    ROUND(SUM(total_revenue), 2) AS total_category_revenue
FROM film_performance_agg
GROUP BY performance_tier
ORDER BY 
    CASE performance_tier 
        WHEN 'High Performer' THEN 1 
        WHEN 'Medium Performer' THEN 2 
        WHEN 'Low Performer' THEN 3 
        ELSE 4 
    END;

-- 分析查询 3：运营效率与盈利能力分析
-- ========================================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========== 运营效率与盈利能力分析 ==========';
    RAISE NOTICE '';
END $$;

-- 3.1 地域绩效排行
SELECT 
    country,
    COUNT(*) AS store_count,
    ROUND(SUM(total_revenue), 2) AS total_revenue,
    ROUND(AVG(total_revenue), 2) AS avg_revenue_per_store,
    ROUND(AVG(total_customers), 0) AS avg_customers_per_store,
    COUNT(CASE WHEN store_efficiency_tier = 'High Efficiency' THEN 1 END) AS high_efficiency_stores
FROM operation_efficiency_agg
GROUP BY country
ORDER BY total_revenue DESC;

-- 3.2 门店详细绩效
SELECT 
    store_id,
    store_manager,
    city || ', ' || country AS location,
    total_revenue,
    total_customers,
    total_rentals,
    avg_transaction_value,
    store_efficiency_tier,
    unique_films_available
FROM operation_efficiency_agg
ORDER BY total_revenue DESC;

-- 3.3 运营效率趋势分析
SELECT 
    store_efficiency_tier,
    COUNT(*) AS store_count,
    ROUND(AVG(total_revenue), 2) AS avg_revenue,
    ROUND(AVG(total_customers), 0) AS avg_customers,
    ROUND(AVG(avg_transaction_value), 2) AS avg_transaction_value,
    ROUND((COUNT(*) * 100.0 / (SELECT COUNT(*) FROM operation_efficiency_agg)), 2) AS percentage
FROM operation_efficiency_agg
GROUP BY store_efficiency_tier
ORDER BY avg_revenue DESC;

-- ========================================================================
-- 执行完成提示
-- ========================================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========== 执行完成 ==========';
    RAISE NOTICE '您已成功完成了DVD Rental数据库的去范式化与数据分析';
END $$;
