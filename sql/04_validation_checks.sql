-- Technical validation only. These queries do not calculate business KPIs.
USE retailpulse;

-- Compare actual row counts with the approved source CSV row counts.
SELECT expected_counts.table_name,
       expected_counts.expected_rows,
       actual_counts.actual_rows,
       actual_counts.actual_rows - expected_counts.expected_rows AS difference,
       CASE WHEN actual_counts.actual_rows = expected_counts.expected_rows
            THEN 'PASS' ELSE 'CHECK' END AS count_status
FROM (
    SELECT 'customers' AS table_name, 99441 AS expected_rows
    UNION ALL SELECT 'orders', 99441
    UNION ALL SELECT 'order_items', 112650
    UNION ALL SELECT 'payments', 103886
    UNION ALL SELECT 'reviews', 99224
    UNION ALL SELECT 'products', 32951
    UNION ALL SELECT 'sellers', 3095
    UNION ALL SELECT 'product_category_translations', 71
) AS expected_counts
JOIN (
    SELECT 'customers' AS table_name, COUNT(*) AS actual_rows FROM customers
    UNION ALL SELECT 'orders', COUNT(*) FROM orders
    UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
    UNION ALL SELECT 'payments', COUNT(*) FROM payments
    UNION ALL SELECT 'reviews', COUNT(*) FROM reviews
    UNION ALL SELECT 'products', COUNT(*) FROM products
    UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
    UNION ALL SELECT 'product_category_translations', COUNT(*) FROM product_category_translations
) AS actual_counts USING (table_name)
ORDER BY expected_counts.table_name;

-- Constraint definitions show the primary and foreign keys currently applied.
SHOW CREATE TABLE customers;
SHOW CREATE TABLE orders;
SHOW CREATE TABLE order_items;
SHOW CREATE TABLE payments;
SHOW CREATE TABLE reviews;
SHOW CREATE TABLE products;
SHOW CREATE TABLE sellers;
SHOW CREATE TABLE product_category_translations;

-- Duplicate-key checks; each result should return no rows.
SELECT customer_id, COUNT(*) AS duplicate_count FROM customers GROUP BY customer_id HAVING COUNT(*) > 1;
SELECT order_id, COUNT(*) AS duplicate_count FROM orders GROUP BY order_id HAVING COUNT(*) > 1;
SELECT product_id, COUNT(*) AS duplicate_count FROM products GROUP BY product_id HAVING COUNT(*) > 1;
SELECT seller_id, COUNT(*) AS duplicate_count FROM sellers GROUP BY seller_id HAVING COUNT(*) > 1;
SELECT order_id, order_item_id, COUNT(*) AS duplicate_count FROM order_items GROUP BY order_id, order_item_id HAVING COUNT(*) > 1;
SELECT order_id, payment_sequential, COUNT(*) AS duplicate_count FROM payments GROUP BY order_id, payment_sequential HAVING COUNT(*) > 1;
SELECT review_id, order_id, COUNT(*) AS duplicate_count FROM reviews GROUP BY review_id, order_id HAVING COUNT(*) > 1;

-- Foreign-key orphan checks; each result should be zero.
SELECT COUNT(*) AS orphan_orders_customers
FROM orders o LEFT JOIN customers c ON c.customer_id = o.customer_id
WHERE c.customer_id IS NULL;
SELECT COUNT(*) AS orphan_items_orders
FROM order_items i LEFT JOIN orders o ON o.order_id = i.order_id
WHERE o.order_id IS NULL;
SELECT COUNT(*) AS orphan_items_products
FROM order_items i LEFT JOIN products p ON p.product_id = i.product_id
WHERE p.product_id IS NULL;
SELECT COUNT(*) AS orphan_items_sellers
FROM order_items i LEFT JOIN sellers s ON s.seller_id = i.seller_id
WHERE s.seller_id IS NULL;
SELECT COUNT(*) AS orphan_payments_orders
FROM payments p LEFT JOIN orders o ON o.order_id = p.order_id
WHERE o.order_id IS NULL;
SELECT COUNT(*) AS orphan_reviews_orders
FROM reviews r LEFT JOIN orders o ON o.order_id = r.order_id
WHERE o.order_id IS NULL;

-- Required identifiers and imported timestamps should not be NULL.
SELECT 'customers.customer_id' AS field_name, COUNT(*) AS null_rows FROM customers WHERE customer_id IS NULL
UNION ALL SELECT 'orders.order_id', COUNT(*) FROM orders WHERE order_id IS NULL
UNION ALL SELECT 'orders.customer_id', COUNT(*) FROM orders WHERE customer_id IS NULL
UNION ALL SELECT 'order_items.order_id', COUNT(*) FROM order_items WHERE order_id IS NULL
UNION ALL SELECT 'order_items.product_id', COUNT(*) FROM order_items WHERE product_id IS NULL
UNION ALL SELECT 'order_items.seller_id', COUNT(*) FROM order_items WHERE seller_id IS NULL
UNION ALL SELECT 'orders.order_purchase_timestamp', COUNT(*) FROM orders WHERE order_purchase_timestamp IS NULL;

-- Numeric and status checks; zero values are reported, not changed.
SELECT COUNT(*) AS zero_or_negative_prices FROM order_items WHERE price <= 0;
SELECT COUNT(*) AS zero_freight_rows FROM order_items WHERE freight_value = 0;
SELECT COUNT(*) AS negative_freight_rows FROM order_items WHERE freight_value < 0;
SELECT order_status, COUNT(*) AS rows_in_status
FROM orders
GROUP BY order_status
ORDER BY order_status;
SELECT order_status, COUNT(*) AS unexpected_status_rows
FROM orders
WHERE order_status NOT IN ('delivered', 'shipped', 'invoiced', 'processing', 'approved', 'created', 'unavailable', 'canceled')
GROUP BY order_status;
SELECT COUNT(*) AS products_without_category FROM products WHERE product_category_name IS NULL;
SELECT COUNT(DISTINCT customer_unique_id) AS distinct_customer_unique_ids FROM customers;

-- Optional source blank fields should remain SQL NULL after import.
SELECT COUNT(*) AS null_review_titles FROM reviews WHERE review_comment_title IS NULL;
SELECT COUNT(*) AS null_review_messages FROM reviews WHERE review_comment_message IS NULL;
