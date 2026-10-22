-- Load each original source CSV exactly once into empty RetailPulse tables.
-- Run the mysql client from the RetailPulse project root so these relative
-- LOCAL INFILE paths resolve. This script does not alter raw files.
-- Do not rerun after a partial import until table counts/state are inspected.
USE retailpulse;

LOAD DATA LOCAL INFILE 'data/raw/olist_customers_dataset.csv'
INTO TABLE customers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state);

LOAD DATA LOCAL INFILE 'data/raw/olist_products_dataset.csv'
INTO TABLE products
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(@product_id, @product_category_name, @product_name_lenght,
 @product_description_lenght, @product_photos_qty, @product_weight_g,
 @product_length_cm, @product_height_cm, @product_width_cm)
SET product_id = @product_id,
    product_category_name = NULLIF(@product_category_name, ''),
    product_name_lenght = NULLIF(@product_name_lenght, ''),
    product_description_lenght = NULLIF(@product_description_lenght, ''),
    product_photos_qty = NULLIF(@product_photos_qty, ''),
    product_weight_g = NULLIF(@product_weight_g, ''),
    product_length_cm = NULLIF(@product_length_cm, ''),
    product_height_cm = NULLIF(@product_height_cm, ''),
    product_width_cm = NULLIF(@product_width_cm, '');

LOAD DATA LOCAL INFILE 'data/raw/olist_sellers_dataset.csv'
INTO TABLE sellers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(seller_id, seller_zip_code_prefix, seller_city, seller_state);

LOAD DATA LOCAL INFILE 'data/raw/product_category_name_translation.csv'
INTO TABLE product_category_translations
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(product_category_name, product_category_name_english);

LOAD DATA LOCAL INFILE 'data/raw/olist_orders_dataset.csv'
INTO TABLE orders
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(@order_id, @customer_id, @order_status, @order_purchase_timestamp,
 @order_approved_at, @order_delivered_carrier_date,
 @order_delivered_customer_date, @order_estimated_delivery_date)
SET order_id = @order_id,
    customer_id = @customer_id,
    order_status = @order_status,
    order_purchase_timestamp = @order_purchase_timestamp,
    order_approved_at = NULLIF(@order_approved_at, ''),
    order_delivered_carrier_date = NULLIF(@order_delivered_carrier_date, ''),
    order_delivered_customer_date = NULLIF(@order_delivered_customer_date, ''),
    order_estimated_delivery_date = @order_estimated_delivery_date;

LOAD DATA LOCAL INFILE 'data/raw/olist_order_items_dataset.csv'
INTO TABLE order_items
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, order_item_id, product_id, seller_id, shipping_limit_date, price, freight_value);

LOAD DATA LOCAL INFILE 'data/raw/olist_order_payments_dataset.csv'
INTO TABLE payments
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, payment_sequential, payment_type, payment_installments, payment_value);

LOAD DATA LOCAL INFILE 'data/raw/olist_order_reviews_dataset.csv'
INTO TABLE reviews
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(@review_id, @order_id, @review_score, @review_comment_title,
 @review_comment_message, @review_creation_date, @review_answer_timestamp)
SET review_id = @review_id,
    order_id = @order_id,
    review_score = @review_score,
    review_comment_title = NULLIF(@review_comment_title, ''),
    review_comment_message = NULLIF(@review_comment_message, ''),
    review_creation_date = @review_creation_date,
    review_answer_timestamp = @review_answer_timestamp;
