# Entity Relationship Diagram

All 16 tables with their keys and relationships. For the report use the ready
image [`erd.png`](erd.png) or [`erd.pdf`](erd.pdf). The same diagram is below
(GitHub draws it), and [`erd.dbml`](erd.dbml) opens in <https://dbdiagram.io>.

![ERD](erd.png)

```mermaid
erDiagram
    USERS ||--o{ ADDRESSES : has
    USERS ||--o{ PASSWORD_RESETS : requests
    USERS ||--o{ CART_ITEMS : "adds to cart"
    USERS ||--o{ FAVORITES : likes
    USERS ||--o{ ORDERS : places
    USERS ||--o{ NOTIFICATIONS : receives
    USERS ||--o{ REVIEWS : writes
    CATEGORIES ||--o{ PRODUCTS : contains
    SERIES |o--o{ PRODUCTS : features
    PRODUCTS ||--o{ PRODUCT_IMAGES : has
    PRODUCTS ||--o{ CART_ITEMS : "is in"
    PRODUCTS ||--o{ FAVORITES : "is in"
    PRODUCTS ||--o{ ORDER_ITEMS : "is sold as"
    PRODUCTS ||--o{ REVIEWS : receives
    ORDERS ||--|{ ORDER_ITEMS : contains
    ORDERS ||--o{ PAYMENTS : "is paid by"
    ORDERS |o--o{ NOTIFICATIONS : "is about"
    USERS ||--o{ CONTACT_MESSAGES : sends
    ORDERS |o--o{ CONTACT_MESSAGES : "is asked about"

    USERS {
        int id PK
        varchar full_name
        varchar email UK
        varchar password_hash
        varchar phone
        varchar avatar_url
        enum role "customer | admin"
        bool is_active
        datetime created_at
    }
    PASSWORD_RESETS {
        int id PK
        int user_id FK
        varchar code_hash
        datetime expires_at
        int attempts
        bool used
    }
    ADDRESSES {
        int id PK
        int user_id FK
        varchar label
        varchar recipient_name
        varchar phone
        varchar street
        varchar city
        varchar province
        bool is_default
    }
    CATEGORIES {
        int id PK
        varchar name
        varchar slug UK
        text description
        varchar image_url
    }
    SERIES {
        int id PK
        varchar name "One Piece, Pokemon, ..."
        varchar slug UK
        varchar image_url
    }
    PRODUCTS {
        int id PK
        int category_id FK
        int series_id FK
        varchar brand
        varchar name
        varchar slug UK
        text description
        decimal price
        decimal discount_price
        int stock
        bool is_featured
        bool is_active
    }
    PRODUCT_IMAGES {
        int id PK
        int product_id FK
        varchar image_url
        bool is_primary
        int sort_order
    }
    CART_ITEMS {
        int id PK
        int user_id FK
        int product_id FK
        int quantity
    }
    FAVORITES {
        int id PK
        int user_id FK
        int product_id FK
    }
    ORDERS {
        int id PK
        varchar order_number UK
        int user_id FK
        varchar shipping_name
        varchar shipping_phone
        varchar shipping_address
        decimal subtotal
        decimal shipping_fee
        decimal total
        enum status
        enum payment_method
        enum payment_status
        enum delivery_method "standard | pickup"
        decimal discount
        varchar coupon_code
        datetime created_at
    }
    PAYMENTS {
        int id PK
        int order_id FK
        enum provider "mock | bakong | payway"
        text qr
        char md5 UK
        varchar tran_id UK
        text deeplink
        decimal amount
        enum status "pending | paid | expired"
        datetime expires_at
        datetime paid_at
    }
    ORDER_ITEMS {
        int id PK
        int order_id FK
        int product_id FK
        varchar product_name
        decimal unit_price
        int quantity
        decimal subtotal
    }
    NOTIFICATIONS {
        int id PK
        int user_id FK
        varchar title
        text message
        enum type
        varchar event
        int order_id FK
        varchar promo_code
        bool is_read
    }
    CONTACT_MESSAGES {
        int id PK
        int user_id FK
        int order_id FK
        enum topic "order | payment | product | other"
        text message
        enum status "open | answered"
        text reply
        datetime replied_at
    }
    REVIEWS {
        int id PK
        int product_id FK
        int user_id FK
        tinyint rating "1-5"
        text comment
        json tags
        datetime updated_at
    }
    COUPONS {
        int id PK
        varchar code UK
        varchar description
        enum discount_type "percent | fixed"
        decimal value
        decimal min_subtotal
        decimal max_discount
        datetime expires_at
        bool is_active
    }
```

## Relationships

| Relationship | Type | Notes |
|---|---|---|
| User → Addresses | 1 : N | A user can save many shipping addresses |
| User → Cart items | 1 : N | One row per product in the cart; (user, product) is unique |
| User → Favorites | 1 : N | Wishlist; (user, product) is unique |
| User → Orders | 1 : N | |
| Order → Order items | 1 : N | Product name and price are copied at purchase time |
| Category → Products | 1 : N | Figures, Plush, TCG Boosters, ... |
| Series → Products | 1 : N | Anime franchise; optional (e.g. card sleeves have no series) |
| Product → Product images | 1 : N | One image is marked `is_primary` |
| User → Notifications | 1 : N | Order updates, promos, support replies; may point to an order |
| Order → Payments | 1 : N | KHQR / ABA PayWay attempts; the QR and its md5 are made once and reused while checking |
| User → Contact messages | 1 : N | Questions from the Contact screen; the shop's reply comes back as a notification |
| Order → Contact messages | 1 : N | Optional, only for order and payment questions |
| User/Product → Reviews | N : M | Bonus feature; one review per user per product |
