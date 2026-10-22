-- RetailPulse core schema, based on docs/MYSQL_SCHEMA_DESIGN.md.
-- Run after 01_create_database.sql. No tables or data are dropped.
USE retailpulse;

CREATE TABLE customers (
    customer_id VARCHAR(32) NOT NULL,
    customer_unique_id VARCHAR(32) NOT NULL,
    customer_zip_code_prefix CHAR(5) NULL,
    customer_city VARCHAR(100) NOT NULL,
    customer_state CHAR(2) NOT NULL,
    PRIMARY KEY (customer_id),
    KEY idx_customers_customer_unique_id (customer_unique_id)
) ENGINE=InnoDB DEFAULT CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE products (
    product_id VARCHAR(32) NOT NULL,
    product_category_name VARCHAR(100) NULL,
    product_name_lenght INT NULL,
    product_description_lenght INT NULL,
    product_photos_qty INT NULL,
    product_weight_g INT NULL,
    product_length_cm INT NULL,
    product_height_cm INT NULL,
    product_width_cm INT NULL,
    PRIMARY KEY (product_id)
) ENGINE=InnoDB DEFAULT CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE sellers (
    seller_id VARCHAR(32) NOT NULL,
    seller_zip_code_prefix CHAR(5) NULL,
    seller_city VARCHAR(100) NOT NULL,
    seller_state CHAR(2) NOT NULL,
    PRIMARY KEY (seller_id)
) ENGINE=InnoDB DEFAULT CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE product_category_translations (
    product_category_name VARCHAR(100) NOT NULL,
    product_category_name_english VARCHAR(100) NOT NULL,
    PRIMARY KEY (product_category_name)
) ENGINE=InnoDB DEFAULT CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE orders (
    order_id VARCHAR(32) NOT NULL,
    customer_id VARCHAR(32) NOT NULL,
    order_status VARCHAR(20) NOT NULL,
    order_purchase_timestamp DATETIME NOT NULL,
    order_approved_at DATETIME NULL,
    order_delivered_carrier_date DATETIME NULL,
    order_delivered_customer_date DATETIME NULL,
    order_estimated_delivery_date DATETIME NOT NULL,
    PRIMARY KEY (order_id),
    KEY idx_orders_customer_id (customer_id),
    KEY idx_orders_purchase_timestamp (order_purchase_timestamp),
    KEY idx_orders_status (order_status),
    CONSTRAINT fk_orders_customers
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
) ENGINE=InnoDB DEFAULT CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE order_items (
    order_id VARCHAR(32) NOT NULL,
    order_item_id SMALLINT NOT NULL,
    product_id VARCHAR(32) NOT NULL,
    seller_id VARCHAR(32) NOT NULL,
    shipping_limit_date DATETIME NOT NULL,
    price DECIMAL(12,2) NOT NULL,
    freight_value DECIMAL(12,2) NOT NULL,
    PRIMARY KEY (order_id, order_item_id),
    KEY idx_order_items_product_id (product_id),
    KEY idx_order_items_seller_id (seller_id),
    CONSTRAINT fk_order_items_orders
        FOREIGN KEY (order_id) REFERENCES orders (order_id),
    CONSTRAINT fk_order_items_products
        FOREIGN KEY (product_id) REFERENCES products (product_id),
    CONSTRAINT fk_order_items_sellers
        FOREIGN KEY (seller_id) REFERENCES sellers (seller_id)
) ENGINE=InnoDB DEFAULT CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE payments (
    order_id VARCHAR(32) NOT NULL,
    payment_sequential SMALLINT NOT NULL,
    payment_type VARCHAR(30) NOT NULL,
    payment_installments SMALLINT NOT NULL,
    payment_value DECIMAL(12,2) NOT NULL,
    PRIMARY KEY (order_id, payment_sequential),
    CONSTRAINT fk_payments_orders
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
) ENGINE=InnoDB DEFAULT CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE reviews (
    review_id VARCHAR(32) NOT NULL,
    order_id VARCHAR(32) NOT NULL,
    review_score TINYINT UNSIGNED NOT NULL,
    review_comment_title TEXT NULL,
    review_comment_message TEXT NULL,
    review_creation_date DATETIME NOT NULL,
    review_answer_timestamp DATETIME NOT NULL,
    PRIMARY KEY (review_id, order_id),
    KEY idx_reviews_order_id (order_id),
    CONSTRAINT chk_reviews_score CHECK (review_score BETWEEN 1 AND 5),
    CONSTRAINT fk_reviews_orders
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
) ENGINE=InnoDB DEFAULT CHARACTER SET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
