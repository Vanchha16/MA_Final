# Entity Relationship Diagram

The diagram below renders on GitHub. For a polished image for the report, paste
[`erd.dbml`](erd.dbml) into <https://dbdiagram.io> and export as PNG/PDF.

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
        datetime created_at
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
        bool is_read
    }
    REVIEWS {
        int id PK
        int product_id FK
        int user_id FK
        tinyint rating "1-5"
        text comment
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
| User → Notifications | 1 : N | Order updates, promos |
| User/Product → Reviews | N : M | Bonus feature; one review per user per product |
