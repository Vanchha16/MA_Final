-- =============================================================
-- E-Commerce Mobile App - Database Schema (MySQL 8.0)
-- =============================================================

CREATE DATABASE IF NOT EXISTS ecommerce_db
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ecommerce_db;

-- -------------------------------------------------------------
-- Users & accounts
-- -------------------------------------------------------------
CREATE TABLE users (
  id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  full_name     VARCHAR(100)  NOT NULL,
  email         VARCHAR(150)  NOT NULL UNIQUE,
  password_hash VARCHAR(255)  NOT NULL,
  phone         VARCHAR(20)   NULL,
  avatar_url    VARCHAR(255)  NULL,
  role          ENUM('customer','admin') NOT NULL DEFAULT 'customer',
  is_active     BOOLEAN       NOT NULL DEFAULT TRUE,
    -- Settings > Notify me about
  notify_orders  BOOLEAN NOT NULL DEFAULT TRUE,
  notify_offers  BOOLEAN NOT NULL DEFAULT TRUE,
  notify_news    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- One-time codes for "Forgot Password"
CREATE TABLE password_resets (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id     INT UNSIGNED NOT NULL,
  code_hash   VARCHAR(255) NOT NULL,
  expires_at  DATETIME     NOT NULL,
  attempts    INT UNSIGNED NOT NULL DEFAULT 0,   -- wrong codes entered (max 5)
  used        BOOLEAN      NOT NULL DEFAULT FALSE,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE addresses (
  id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id        INT UNSIGNED NOT NULL,
  label          VARCHAR(50)  NOT NULL DEFAULT 'Home',
  recipient_name VARCHAR(100) NOT NULL,
  phone          VARCHAR(20)  NOT NULL,
  street         VARCHAR(255) NOT NULL,
  city           VARCHAR(100) NOT NULL,
  province       VARCHAR(100) NULL,
  postal_code    VARCHAR(20)  NULL,
  is_default     BOOLEAN      NOT NULL DEFAULT FALSE,
  created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- -------------------------------------------------------------
-- Catalog
-- -------------------------------------------------------------
CREATE TABLE categories (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(100) NOT NULL,
  slug        VARCHAR(120) NOT NULL UNIQUE,
  description TEXT         NULL,
  image_url   VARCHAR(255) NULL,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Anime franchise (One Piece, Pokemon, ...) - lets users browse/filter by series
CREATE TABLE series (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(100) NOT NULL,
  slug        VARCHAR(120) NOT NULL UNIQUE,
  image_url   VARCHAR(255) NULL,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE products (
  id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  category_id    INT UNSIGNED  NOT NULL,
  series_id      INT UNSIGNED  NULL,
  brand          VARCHAR(100)  NULL,   -- Good Smile, Bandai, Banpresto, The Pokemon Company ...
  name           VARCHAR(150)  NOT NULL,
  slug           VARCHAR(170)  NOT NULL UNIQUE,
  description    TEXT          NULL,
  price          DECIMAL(10,2) NOT NULL,
  discount_price DECIMAL(10,2) NULL,
  stock          INT UNSIGNED  NOT NULL DEFAULT 0,
  is_featured    BOOLEAN       NOT NULL DEFAULT FALSE,
  is_active      BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE RESTRICT,
  FOREIGN KEY (series_id)   REFERENCES series(id)     ON DELETE SET NULL,
  INDEX idx_products_name (name),
  INDEX idx_products_brand (brand),
  INDEX idx_products_price (price)
);

CREATE TABLE product_images (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  product_id INT UNSIGNED NOT NULL,
  image_url  VARCHAR(255) NOT NULL,
  is_primary BOOLEAN      NOT NULL DEFAULT FALSE,
  sort_order INT          NOT NULL DEFAULT 0,
  FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

-- -------------------------------------------------------------
-- Shopping
-- -------------------------------------------------------------
-- Each row is one product in a user's cart (the "Cart" entity)
CREATE TABLE cart_items (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id    INT UNSIGNED NOT NULL,
  product_id INT UNSIGNED NOT NULL,
  quantity   INT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id)    REFERENCES users(id)    ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
  UNIQUE KEY uq_cart_user_product (user_id, product_id)
);

CREATE TABLE favorites (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id    INT UNSIGNED NOT NULL,
  product_id INT UNSIGNED NOT NULL,
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id)    REFERENCES users(id)    ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
  UNIQUE KEY uq_fav_user_product (user_id, product_id)
);

-- -------------------------------------------------------------
-- Orders
-- -------------------------------------------------------------
CREATE TABLE orders (
  id               INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_number     VARCHAR(30)   NOT NULL UNIQUE,
  user_id          INT UNSIGNED  NOT NULL,
  -- shipping address is copied at checkout so later address edits don't change old orders
  shipping_name    VARCHAR(100)  NOT NULL,
  shipping_phone   VARCHAR(20)   NOT NULL,
  shipping_address VARCHAR(500)  NOT NULL,
  subtotal         DECIMAL(10,2) NOT NULL,
  shipping_fee     DECIMAL(10,2) NOT NULL DEFAULT 0,
  discount         DECIMAL(10,2) NOT NULL DEFAULT 0,
  coupon_code      VARCHAR(30)   NULL,
  total            DECIMAL(10,2) NOT NULL,
  delivery_method  ENUM('standard','pickup') NOT NULL DEFAULT 'standard',
  status           ENUM('pending','confirmed','shipped','delivered','cancelled') NOT NULL DEFAULT 'pending',
  payment_method   ENUM('cod','khqr','aba','card') NOT NULL DEFAULT 'cod',
  payment_status   ENUM('unpaid','paid','failed','refunded') NOT NULL DEFAULT 'unpaid',
  note             VARCHAR(255)  NULL,
  created_at       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT,
  INDEX idx_orders_user (user_id, created_at)
);

CREATE TABLE order_items (
  id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id     INT UNSIGNED  NOT NULL,
  product_id   INT UNSIGNED  NULL,
  -- name/price snapshot at time of purchase
  product_name VARCHAR(150)  NOT NULL,
  unit_price   DECIMAL(10,2) NOT NULL,
  quantity     INT UNSIGNED  NOT NULL,
  subtotal     DECIMAL(10,2) NOT NULL,
  FOREIGN KEY (order_id)   REFERENCES orders(id)   ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL
);

-- One online payment per order attempt (Bakong KHQR or ABA PayWay). The QR string
-- and its md5 are made once and reused for every status check (a new QR would be a
-- new transaction). PayWay rows also keep PayWay's tran_id and the ABA Mobile link.
CREATE TABLE payments (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id   INT UNSIGNED  NOT NULL,
  provider   ENUM('mock','bakong','payway') NOT NULL,
  qr         TEXT          NOT NULL,
  md5        CHAR(32)      NOT NULL UNIQUE,
  tran_id    VARCHAR(20)   NULL UNIQUE,
  deeplink   TEXT          NULL,
  amount     DECIMAL(10,2) NOT NULL,
  currency   CHAR(3)       NOT NULL DEFAULT 'USD',
  status     ENUM('pending','paid','expired') NOT NULL DEFAULT 'pending',
  expires_at DATETIME      NOT NULL,
  paid_at    DATETIME      NULL,
  created_at DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  INDEX idx_payments_order (order_id)
);

-- -------------------------------------------------------------
-- Extras
-- -------------------------------------------------------------
CREATE TABLE notifications (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id    INT UNSIGNED NOT NULL,
  title      VARCHAR(150) NOT NULL,
  message    TEXT         NOT NULL,
  type       ENUM('order','promo','system') NOT NULL DEFAULT 'system',
  -- placed, paid, confirmed, shipped, delivered, cancelled, welcome, promo, news, support
  event      VARCHAR(20)  NULL,
  order_id   INT UNSIGNED NULL,
  promo_code VARCHAR(30)  NULL,
  is_read    BOOLEAN      NOT NULL DEFAULT FALSE,
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
);

-- Questions sent from the app's Contact screen; replies arrive as notifications
CREATE TABLE contact_messages (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id    INT UNSIGNED NOT NULL,
  order_id   INT UNSIGNED NULL,
  topic      ENUM('order','payment','product','other') NOT NULL DEFAULT 'other',
  message    TEXT         NOT NULL,
  status     ENUM('open','answered') NOT NULL DEFAULT 'open',
  reply      TEXT         NULL,
  replied_at DATETIME     NULL,
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL
);

-- Bonus: product reviews & ratings. Only for products in the customer's
-- delivered orders (checked by the API); one per customer and product.
CREATE TABLE reviews (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  product_id INT UNSIGNED     NOT NULL,
  user_id    INT UNSIGNED     NOT NULL,
  rating     TINYINT UNSIGNED NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment    TEXT             NULL,
  tags       JSON             NULL,  -- quality, as_pictured, packaging, delivery, value
  created_at DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME         NULL,  -- set when the customer edits it
  FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id)    REFERENCES users(id)    ON DELETE CASCADE,
  UNIQUE KEY uq_review_user_product (user_id, product_id)
);

-- Promo codes for the cart (WELCOME10, ANIME5 ...). A coupon stands alone:
-- the cart sends its code, the server checks it and works out the discount.
CREATE TABLE coupons (
  id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code          VARCHAR(30)   NOT NULL UNIQUE,          -- upper case
  description   VARCHAR(150)  NOT NULL,
  discount_type ENUM('percent','fixed') NOT NULL,
  value         DECIMAL(10,2) NOT NULL,                 -- 10 = 10% or $10
  min_subtotal  DECIMAL(10,2) NOT NULL DEFAULT 0,
  max_discount  DECIMAL(10,2) NULL,                     -- cap for percent coupons
  expires_at    DATETIME      NULL,
  is_active     BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
);
