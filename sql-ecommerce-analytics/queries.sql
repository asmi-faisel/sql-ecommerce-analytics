-- ============================================================
-- PROJECT 3: Advanced SQL Analytics — E-Commerce Dataset
-- Database: PostgreSQL | Dataset: Olist (Kaggle)
-- ============================================================

-- QUERY 1: RFM Customer Segmentation
-- Recency, Frequency, Monetary analysis

WITH rfm_base AS (
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp)::date AS last_purchase,
        COUNT(o.order_id) AS frequency,
        SUM(op.payment_value) AS monetary,
        CURRENT_DATE - MAX(o.order_purchase_timestamp)::date AS recency_days
    FROM customers c
    JOIN orders o USING(customer_id)
    JOIN order_payments op USING(order_id)
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
rfm_scores AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY recency_days ASC)  AS r_score,
        NTILE(5) OVER (ORDER BY frequency DESC)   AS f_score,
        NTILE(5) OVER (ORDER BY monetary DESC)    AS m_score
    FROM rfm_base
)
SELECT
    customer_unique_id,
    recency_days, frequency, ROUND(monetary, 2),
    r_score, f_score, m_score,
    CONCAT(r_score, f_score, m_score) AS rfm_cell,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'New Customers'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
        WHEN r_score = 1 THEN 'Lost'
        ELSE 'Potential Loyalists'
    END AS segment
FROM rfm_scores
ORDER BY r_score DESC, f_score DESC;

-- QUERY 2: Cohort Retention Analysis
WITH cohorts AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS cohort_month
    FROM customers c JOIN orders o USING(customer_id)
    GROUP BY c.customer_unique_id
),
activity AS (
    SELECT
        c.customer_unique_id,
        cohort_month,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS activity_month,
        EXTRACT(EPOCH FROM
            DATE_TRUNC('month', o.order_purchase_timestamp) - cohort_month
        ) / 2592000 AS months_since_join
    FROM customers c
    JOIN orders o USING(customer_id)
    JOIN cohorts USING(customer_unique_id)
)
SELECT
    TO_CHAR(cohort_month, 'YYYY-MM') AS cohort,
    months_since_join,
    COUNT(DISTINCT customer_unique_id) AS retained_customers
FROM activity
GROUP BY cohort_month, months_since_join
ORDER BY cohort_month, months_since_join;

-- QUERY 3: 7-day Rolling Revenue + YoY Comparison
WITH daily_revenue AS (
    SELECT
        o.order_purchase_timestamp::date AS day,
        SUM(op.payment_value) AS revenue
    FROM orders o JOIN order_payments op USING(order_id)
    WHERE o.order_status = 'delivered'
    GROUP BY 1
)
SELECT
    day,
    revenue,
    ROUND(AVG(revenue) OVER (
        ORDER BY day
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_7d_avg,
    LAG(revenue, 365) OVER (ORDER BY day) AS revenue_yoy,
    ROUND(
        100.0 * (revenue - LAG(revenue, 365) OVER (ORDER BY day))
        / NULLIF(LAG(revenue, 365) OVER (ORDER BY day), 0), 2
    ) AS yoy_growth_pct
FROM daily_revenue
ORDER BY day;