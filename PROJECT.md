# Magray Orchards — Project Status & Documentation

## Overview

Full-stack e-commerce platform selling pesticides, farming tools, and offering orchard services (pruning, visits, spraying). Laravel 12 backend + Flutter mobile app (Android + Web).

> **Note:** This document was significantly updated (Aug 21, 2026) to reflect the current codebase. Earlier phase entries (1-54) describe the historical build; the project has since grown with wallet, POS, reels, brands, configurable home layout, service bookings with distance pricing, notification templates, and mobile-app version/maintenance gating.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | Laravel 12, PHP 8.2 |
| Database | MySQL (`magray`, user: `root`, password: ``) |
| Frontend CSS | Tailwind CSS (CDN via `cdn.tailwindcss.com`) |
| Alpine.js | CDN (incl. `@alpinejs/collapse`) |
| Mobile App | Flutter 3.x, Provider state management, Android + Web |
| Fonts (Flutter) | `google_fonts` package (Inter/Poppins/Roboto/Playfair Display at runtime) |
| Payments | Razorpay + COD + Wallet (full/partial) |
| Courier | Delhivery API (CMU create, tracking, serviceability, labels), Shiprocket, Local |
| Auth | Phone + OTP (demo: 1234) + password login for customers, email+password for admin |
| RBAC | Spatie roles/permissions on separate `admin` guard |
| Subscriptions | Tiered plans with proration, Pro Member badges, free delivery |
| Reports | `phpoffice/phpspreadsheet` (Excel export) + `barryvdh/laravel-dompdf` (PDF export) |
| Build | No Vite for Blade — Tailwind via CDN (Vite present for assets only) |

---

## Credentials

| Account | Email | Password | Guard |
|---------|-------|----------|-------|
| Super Admin | `admin@magray.com` | `password` | `admin` (admins table) |

**Customer auth:** Phone number + OTP (demo OTP: `1234`). No password required.

---

## Design System

- **Colors:** `brand-*` palette — dynamic via theme system (8 palettes: emerald/blue/indigo/purple/rose/orange/teal/amber)
- **Fonts:** 4 Google Fonts options (Inter/Poppins/Roboto/Playfair Display) — configurable per-theme
- **Cards:** rounded-2xl, white bg, border-gray-100, shadow-sm
- **Buttons:** brand-600/700, rounded-2xl, shadow-sm
- **Auth pages:** Split-screen layout — left brand gradient, right white form panel
- **Admin sidebar:** 7 expandable sections (Alpine.js collapse), 3 style modes (dark/light/brand)
- **Logo:** Uploadable via admin settings (stored in `storage/app/public/logos/`)

---

## Architecture: Admin vs Customer Separation

```
┌─────────────────────────────┐     ┌─────────────────────────────┐
│   users table (customers)   │     │   admins table (admin/staff)│
├─────────────────────────────┤     ├─────────────────────────────┤
│ id, name, email             │     │ id, name, email, phone      │
│ password, phone             │     │ password, avatar             │
│ is_active, avatar           │     │ is_active, role              │
│ email_verified_at           │     │ email_verified_at            │
│ timestamps                  │     │ timestamps                   │
└─────────────┬───────────────┘     └─────────────┬───────────────┘
              │                                   │
  ┌───────────┴───────────┐           ┌───────────┴───────────┐
  │  web guard (customer) │           │  admin guard (admin)  │
  │  /login, /register    │           │  /admin/login          │
  │  Sanctum for API      │           │  AdminMiddleware       │
  └───────────────────────┘           └───────────────────────┘
```

- `users` table: all customers — **no `role` column** (dropped in migration)
- `admins` table: all admin/staff — uses `admin` auth guard
- Separate login pages: `/login` (customers), `/admin/login` (admin staff)
- `AdminMiddleware` uses `Auth::guard('admin')` — no `auth` middleware on admin routes
- Spatie roles (`admin` guard): Super Admin, Manager, Staff (~52 permissions)

---

## Directory Structure

```
D:\ai apps\MagrayOrchards\
├── PROJECT.md                        ← This file
├── backend/                          ← Laravel 12 app
│   ├── .env                          ← DB, Razorpay, Delhivery, SMS config
│   ├── bootstrap/app.php             ← Route registration (web, api, admin login, admin protected)
│   ├── config/
│   │   ├── auth.php                  ← web guard (customers) + admin guard (admins)
│   │   ├── cors.php                  ← paths: ['*'], allowed_origins includes magrayorchards.com
│   │   ├── sanctum.php               ← stateful domains includes magrayorchards.com
│   │   ├── services.php              ← razorpay, delhivery, delivery config
│   │   ├── shop.php                  ← pickup pincode, shipping rates, logo_url uses env('APP_URL')
│   │   └── theme.php                 ← 8 color palettes, 4 fonts, 3 sidebar styles
│   ├── routes/
│   │   ├── web.php                   ← Customer-facing + phone gate + dashboard
│   │   ├── admin.php                 ← Protected admin panel routes (AdminMiddleware only)
│   │   ├── api.php                   ← REST API for Flutter app (incl. OTP endpoints, image proxy)
│   │   ├── auth.php                  ← Phone + OTP auth routes (customers)
│   │   └── console.php               ← Scheduler registration (subscriptions:expire daily)
│   ├── app/
│   │   ├── Http/
│   │   │   ├── Controllers/
│   │   │   │   ├── HomeController.php
│   │   │   │   ├── ProductController.php          (gallery, variants, pincode check)
│   │   │   │   ├── CategoryController.php
│   │   │   │   ├── BrandController.php            (web brand listing)
│   │   │   │   ├── ServiceController.php          (quote, book, my-bookings, geocode, reverse geocode)
│   │   │   │   ├── CartController.php             (variant-aware cart, checkout, orders, buy-now, free delivery)
│   │   │   │   ├── CustomerWalletController.php   (web wallet: top-up + Razorpay verify)
│   │   │   │   ├── ProfileController.php
│   │   │   │   ├── CustomerDashboardController.php (orders, addresses, profile, subscription, paid content)
│   │   │   │   ├── PhoneGateController.php        (phone gate OTP verification)
│   │   │   │   ├── Auth/
│   │   │   │   │   └── PhoneAuthController.php    (OTP register/login/password/forgot-reset — web + API, ~900 lines)
│   │   │   │   ├── Admin/             (30 admin controllers)
│   │   │   │   └── Api/              (19 API controllers)
│   │   │   └── Middleware/
│   │   │       ├── AdminMiddleware.php      (Auth::guard('admin'))
│   │   │       ├── AdminPermissionMiddleware.php (Spatie permission → admin guard)
│   │   │       ├── PermissionGate.php       (route→permission map for admin sidebar)
│   │   │       ├── PhoneVerified.php        (checks phone_verified_at)
│   │   │       └── StaffMiddleware.php
│   │   ├── Models/                     (38 Eloquent models)
│   │   │   ├── Admin.php              (Authenticatable, HasRoles, guard='admin')
│   │   │   ├── User.php              (HasApiTokens, customers, phone_verified_at, subscription methods)
│   │   │   ├── Product.php           (brand, composition, dosage, variants, images, stock adjustments)
│   │   │   ├── ProductVariant.php    (price, compare_price, image, attributes, stock)
│   │   │   ├── ProductImage.php      (image_path, sort_order, is_primary)
│   │   │   ├── Brand.php             (auto-slug, hasMany products)
│   │   │   ├── SubscriptionPlan.php  (name, slug, tier, price, billing_period, features JSON)
│   │   │   ├── Subscription.php      (user_id, plan_id, status, dates, amount_paid, cancellation fields)
│   │   │   ├── PaidContent.php       (title, slug, content_type, body HTML, required_plan_id)
│   │   │   ├── UserBadge.php         (user_id, badge_type, earned_at, expires_at)
│   │   │   ├── Wallet.php            (balance, credit/debit/refund with locking)
│   │   │   ├── WalletTransaction.php
│   │   │   ├── PosCustomer.php       (credit_limit, credit_balance)
│   │   │   ├── PosInvoice.php        (auto invoice_number POS-1000+)
│   │   │   ├── PosInvoiceItem.php    (product_variant_id support)
│   │   │   ├── PosCreditTransaction.php
│   │   │   ├── Reel.php              (youtube/uploaded, product link, likes/comments)
│   │   │   ├── ReelLike.php / ReelComment.php
│   │   │   ├── Service.php / ServiceBooking.php (travel: distance_km, travel_charge)
│   │   │   ├── BookingAvailability.php (date + max_bookings)
│   │   │   ├── Setting.php           (KV table, JSON-cast values)
│   │   │   ├── NotificationTemplate.php (trigger-based email/SMS overrides)
│   │   │   └── (15 more: Address, Category, Order, OrderItem, Payment, Pincode, CourierPartner, Shipment, Banner, Coupon, NotificationsLog, Wishlist, Review, StockAdjustment, Service)
│   │   └── Services/
│   │       ├── Delivery/
│   │       │   ├── DeliveryServiceInterface.php
│   │       │   ├── DeliveryManager.php
│   │       │   ├── DelhiveryService.php       (raw curl, CMU create, tracking, labels, rates)
│   │       │   ├── ShiprocketService.php
│   │       │   └── LocalDeliveryService.php
│   │       ├── Shipping/ShippingCalculator.php (unified 5-tier rate chain)
│   │       ├── Booking/
│   │       │   ├── BookingPricingService.php  (travel charge, daily capacity)
│   │       │   └── DistanceService.php        (Google geocode/matrix + haversine fallback)
│   │       ├── Pos/PosService.php             (invoice, stock, credit ledger)
│   │       ├── SubscriptionService.php        (canSubscribe, calculateProration, processSubscription, enrichPlan)
│   │       ├── WalletService.php              (top-up, verify, deduct/refund for orders+subscriptions, admin credit/debit)
│   │       ├── CouponService.php
│   │       ├── ShopSettingsService.php        (DB settings → config at boot)
│   │       ├── Payment/RazorpayService.php
│   │       └── Notification/
│   │           ├── EmailService.php
│   │           ├── SmsService.php
│   │           ├── NotificationService.php
│   │           └── TemplateRegistry.php       (11 default templates)
│   ├── database/
│   │   ├── migrations/               ← 63 migration files (incl. wallet, POS, reels, brands, settings, booking availability, notification templates)
│   │   └── seeders/
│   │       ├── AdminSeeder            (seeds Admin model)
│   │       ├── CategorySeeder        (8 categories)
│   │       ├── ProductSeeder         (~12 products)
│   │       ├── ProductDetailsSeeder  (brand/composition/dosage + size variants)
│   │       ├── ServiceSeeder         (5 services)
│   │       ├── BannerSeeder          (3 banners)
│   │       ├── PincodeSeeder         (8 pincodes)
│   │       ├── CourierPartnerSeeder  (Delhivery)
│   │       ├── RolesAndPermissionsSeeder  (3 roles, ~52 permissions, admin guard) — also PermissionSeeder (more complete)
│   │       ├── SubscriptionPlanSeeder     (4 plans: Basic/Pro/Pro Quarterly/Premium Yearly)
│   │       ├── PaidContentSeeder          (6 content items)
│   │       └── DatabaseSeeder
│   └── resources/views/
│       ├── layouts/
│       │   ├── shop.blade.php        ← Public storefront (dynamic theme + phone gate popup)
│       │   ├── guest.blade.php       ← Customer auth pages (split-screen, dynamic theme)
│       │   ├── customer.blade.php    ← Customer dashboard layout (extends shop)
│       │   ├── app.blade.php         ← Breeze default
│       │   └── navigation.blade.php  ← Dashboard nav
│       ├── components/
│       │   ├── admin/                ← Shared admin form components
│       │   │   ├── input.blade.php       (rounded-xl, brand focus, auto errors)
│       │   │   ├── select.blade.php      (options array, placeholder)
│       │   │   ├── textarea.blade.php    (resizable, rows)
│       │   │   ├── checkbox.blade.php    (hidden input, brand accent)
│       │   │   └── button.blade.php      (primary/secondary/danger/ghost, sm/default/lg)
│       │   ├── application-logo.blade.php
│       │   ├── primary-button.blade.php
│       │   ├── text-input.blade.php
│       │   └── (7 more Breeze components)
│       ├── auth/                     (6 views — split-screen branded)
│       ├── welcome.blade.php         ← Homepage
│       ├── products/
│       │   ├── index.blade.php       ← Product grid (buy now + add to cart)
│       │   └── show.blade.php        ← Product detail (gallery, variants, composition, dosage, swipe)
│       ├── categories/               (index, show)
│       ├── services/                 (index, show)
│       ├── cart/
│       │   ├── index.blade.php       ← Shopping cart
│       │   ├── checkout.blade.php    ← Checkout (conditional payment methods, pre-filled address)
│       │   └── track.blade.php       ← Order tracking
│       ├── customer/
│       │   ├── dashboard.blade.php   ← Overview with stats + recent orders
│       │   ├── orders.blade.php      ← Paginated order list
│       │   ├── order-show.blade.php  ← Order detail with cancel
│       │   ├── addresses.blade.php   ← Address CRUD with Alpine.js modal
│       │   ├── profile.blade.php     ← Profile edit (name/phone/email)
│       │   ├── subscription.blade.php ← Current plan + available plans with proration
│       │   ├── paid-content.blade.php ← Content grid with type badges
│       │   └── paid-content-show.blade.php ← Full HTML content view
│           └── admin/
│               ├── auth/login.blade.php  ← Admin login (standalone, not guest layout)
│               ├── layout.blade.php      ← Dynamic theme layout (Tailwind config, font, logo, sidebar)
│               ├── dashboard.blade.php
│               ├── settings/index.blade.php  ← 5-tab settings (General/Shipping/Payments/Notifications/Appearance)
│               ├── subscriptions/
│               │   ├── plans/         ← Plan CRUD with features builder
│               │   ├── content/       ← Paid content CRUD with HTML body + Edit/Preview tabs
│               │   ├── subscribers/   ← Subscriber list with filters + detail view
│               │   └── setup/index.blade.php ← Documentation page (cron setup, proration, key files)
│               └── (40+ admin Blade views — all use <x-admin.*> components)
└── flutter_app/                      ← Flutter mobile + web app
    ├── android/
    │   └── app/
    │       ├── build.gradle.kts      ← applicationId = "com.magray.orchards"
    │       └── src/main/
    │           ├── AndroidManifest.xml    ← android:label = "Magray Orchards"
    │           └── kotlin/com/magray/orchards/
    │               └── MainActivity.kt
    ├── linux/
    │   └── CMakeLists.txt            ← APPLICATION_ID = "com.magray.orchards"
    └── lib/
        ├── main.dart                 ← MultiProvider (10 providers), MaterialApp, named routes
        ├── config/
        │   ├── api_config.dart       ← baseUrl/imageBaseUrl (dart-define overridable, default localhost:8000)
        │   └── theme_config.dart     ← 8 palettes, buildThemeData() via google_fonts, premium tokens
        ├── services/
        │   ├── api_service.dart      ← HTTP client + endpoint helpers (quote, availability, bookings, brands, shipping, pincode) + _onUnauthorized wiring
        │   ├── shop_config.dart      ← Remote /config: tax, maintenance, versions, home layout
        │   ├── booking_payment.dart  ← Shared Razorpay flow for service bookings
        │   ├── sound_service.dart    ← order-success sound
        │   ├── razorpay_factory.dart ← Conditional import (native vs web stub)
        │   ├── razorpay_helper.dart  ← Abstract interface
        │   ├── razorpay_native_impl.dart  ← Wraps razorpay_flutter
        │   └── razorpay_web_impl.dart     ← Web impl (injects checkout.js, global callbacks)
        ├── models/                   (18 models)
        │   ├── user.dart             ← phoneVerifiedAt, isActive, isProMember, hasFreeDelivery, defaultPincode/City/State
        │   ├── product.dart          ← brand, composition, dosage, classification, recommendedCrops, images, variants, reviews
        │   ├── product_variant.dart  ← id, name, sku, price, comparePrice, stockQuantity, image, attributes
        │   ├── product_image.dart    ← url getter uses image proxy
        │   ├── order.dart            ← Safe _toDouble() for decimal:2 serialization, shipment, walletAmountUsed
        │   ├── review.dart           ← rating, comment, isApproved, userName
        │   ├── subscription_plan.dart ← PlanProration, subscriptionAction, isCurrentPlan, isUpgrade, isDowngradeBlocked
        │   ├── paid_content.dart     ← id, title, slug, contentType, body, requiredPlanName
        │   ├── home_section.dart     ← Admin home_layout → HomeSection/HomeLayout
        │   ├── reel.dart             ← videoType (youtube/uploaded), likesCount, isLiked, product
        │   ├── service_model.dart / service_booking.dart ← travel services, quote, availability
        │   ├── wallet.dart           ← transactions with isCredit/isDebit/isRefund
        │   ├── brand.dart / category.dart / banner.dart / address.dart / reel_comment.dart
        │   └── (user, product variants, etc.)
        ├── providers/                (10 providers)
        │   ├── auth_provider.dart    ← Phone+OTP auth + password + forgot/reset; _handleUnauthorized session clear
        │   ├── product_provider.dart ← Separate _featuredProducts, _categoryProducts, _searchProducts, offers, sections
        │   ├── cart_provider.dart    ← clearCart() async — deletes server items first; SharedPreferences persistence + server sync
        │   ├── subscription_provider.dart ← plans, paidContents, currentSubscription, subscribe, cancel
        │   ├── wallet_provider.dart  ← balance, transactions, topUp, verifyTopUp
        │   ├── reels_provider.dart   ← paginated reels, likes, comments
        │   ├── address_provider.dart / order_provider.dart / wishlist_provider.dart
        │   └── theme_provider.dart   ← Persists to SharedPreferences, fetches from GET /api/settings/theme
        ├── widgets/
        │   ├── app_network_image.dart ← Platform-aware: Image.network on web, CachedNetworkImage on mobile
        │   ├── product_card.dart     ← discount badge, Buy Now + Add to Cart, out-of-stock
        │   ├── star_rating.dart / review_card.dart / write_review_form.dart
        │   ├── pro_member_badge.dart  ← Gold gradient PRO badge
        │   ├── section_header.dart / app_card.dart / empty_state.dart
        │   └── maintenance_screen.dart / update_required_screen.dart
        └── screens/                  (28 screens)
            ├── splash_screen.dart        ← maintenance + min-version gate → home
            ├── home_screen.dart          ← 5-tab shell (Home/Reels/Services/Cart/Profile); modern configured home + legacy tabs
            ├── phone_input_screen.dart   ← Phone entry + OTP send + password login toggle
            ├── otp_verify_screen.dart    ← 4-digit OTP input, auto-submit, resend timer
            ├── forgot_password_screen.dart ← OTP + new password reset
            ├── product_detail_screen.dart ← Floating bottom bar, variant selector, gallery, pincode check
            ├── product_image_gallery.dart ← PageView + thumbnails + dots + fullscreen viewer
            ├── product_search_screen.dart / category_products_screen.dart / brand_products_screen.dart
            ├── checkout_screen.dart      ← COD/Razorpay/wallet/partial-wallet, coupon, shipping-rate
            ├── wallet_screen.dart / wallet_topup_screen.dart
            ├── order_detail_screen.dart  ← Cancel (reason + refund method), tracking timeline
            ├── service_detail_screen.dart ← Quote (distance travel charge), availability calendar, booking + Razorpay
            ├── my_bookings_screen.dart   ← booking list + Pay Now
            ├── reels_screen.dart / reels_comments_sheet.dart
            ├── subscription_plans_screen.dart ← upgrade/proration/confirm, Razorpay or Wallet
            ├── subscription_screen.dart / paid_content_detail_screen.dart
            ├── address_screen.dart / address_form_screen.dart (pincode autofill)
            ├── orders_screen.dart / edit_profile_screen.dart / wishlist_screen.dart
            └── login_screen.dart / register_screen.dart (redirect shims → PhoneInputScreen)
```

---

## Routes Summary (160+ total)

### Customer Web Routes (web.php)

| Method | URI | Name | Description |
|--------|-----|------|-------------|
| GET | `/` | `home` | Homepage |
| GET | `/products` | `products.index` | Product listing (search/filter/sort) |
| GET | `/products/{slug}` | `products.show` | Product detail (gallery, variants, composition, pincode check) |
| GET | `/categories` | `categories.index` | Category listing |
| GET | `/categories/{slug}` | `categories.show` | Category detail (products) |
| GET | `/services` | `services.index` | Service listing |
| GET | `/services/{slug}` | `services.show` | Service detail |
| POST | `/services/{slug}/book` | `services.book` | Book a service |
| GET | `/cart` | `cart.index` | Shopping cart |
| POST | `/cart/add` | `cart.add` | Add to cart (variant-aware, session-based) |
| POST | `/cart/buy-now` | `cart.buy-now` | Buy Now (clears cart, adds single item, redirects to checkout) |
| PUT | `/cart/{id}` | `cart.update` | Update cart quantity |
| DELETE | `/cart/{id}` | `cart.remove` | Remove from cart |
| GET | `/checkout` | `checkout` | Checkout (auth + phone verified) |
| POST | `/orders` | `orders.place` | Place order + create Delhivery shipment |
| GET | `/orders/{id}/confirmation` | `order.confirmation` | Order confirmation |
| GET | `/orders/{id}/track` | `orders.track` | Order tracking |
| POST | `/shipping-rate` | `shipping.rate` | AJAX delivery rate |
| POST | `/pincode-check` | `pincode.check` | AJAX pincode serviceability |
| GET | `/dashboard` | `dashboard` | Customer dashboard |
| GET | `/orders-history` | `orders.index` | Customer order history |
| GET | `/orders-history/{id}` | `orders.show` | Customer order detail |
| PATCH | `/orders-history/{id}/cancel` | `orders.cancel` | Cancel pending order |
| GET/POST | `/addresses` | `addresses.index` / `addresses.store` | Address list + create |
| PUT/DELETE | `/addresses/{id}` | `addresses.update` / `addresses.destroy` | Address edit/delete |
| PATCH | `/addresses/{id}/default` | `addresses.setDefault` | Set default address |
| GET | `/my-profile` | `profile.index` | Profile page |
| PUT | `/my-profile` | `profile.update` | Update profile |
| GET | `/my-subscription` | `customer.subscription` | Subscription status + available plans |
| POST | `/subscribe/{plan}` | `customer.subscribe` | Subscribe to a plan (validates via SubscriptionService) |
| GET | `/paid-content` | `customer.paid-content` | Paid content list (tier-gated) |
| GET | `/paid-content/{slug}` | `customer.paid-content.show` | Full content view |

### Phone Gate Routes (public, no auth)

| Method | URI | Name | Description |
|--------|-----|------|-------------|
| GET | `/phone-gate/status` | `phone-gate.status` | Check if phone verified in session |
| POST | `/phone-gate/send-otp` | `phone-gate.send-otp` | Send OTP to phone |
| POST | `/phone-gate/verify` | `phone-gate.verify` | Verify OTP, auto-create account, login |

### Auth Routes (auth.php — customers, phone + OTP)

| Method | URI | Name | Description |
|--------|-----|------|-------------|
| GET | `/register` | `register` | Name + phone input |
| POST | `/register` | — | Send OTP, redirect to verify |
| GET | `/register/verify` | `register.verify` | OTP input form |
| POST | `/register/verify` | — | Verify OTP, create account, login |
| GET | `/login` | `login` | Phone input |
| POST | `/login` | — | Send OTP, redirect to verify |
| GET | `/login/verify` | `login.verify` | OTP input form |
| POST | `/login/verify` | — | Verify OTP, login |
| POST | `/logout` | `logout` | Logout |

### Admin Login Routes (bootstrap/app.php — no auth middleware)

| Method | URI | Name | Description |
|--------|-----|------|-------------|
| GET | `/admin/login` | `admin.login` | Admin login form |
| POST | `/admin/login` | `admin.login.submit` | Admin login action |
| POST | `/admin/logout` | `admin.logout` | Admin logout |

### Admin Protected Routes (admin.php — AdminMiddleware only)

| Resource | Controllers | Notes |
|----------|-------------|-------|
| Dashboard | `DashboardController` | Stats overview |
| Products | `ProductController` | Full CRUD + multi-image + variants |
| Products/{product}/images/{image} | `ProductController@destroyImage` | Delete individual gallery image |
| Categories | `CategoryController` | Full CRUD |
| Services | `ServiceController` | Full CRUD |
| Orders | `OrderController` | Index/show/update |
| Customers | `CustomerController` | Index/show/update |
| Staff | `StaffController` | CRUD + toggle status (Admin model) |
| Roles | `RoleController` | CRUD + permission management |
| Banners | `BannerController` | Full CRUD |
| Coupons | `CouponController` | Full CRUD |
| Pincodes | `PincodeController` | Full CRUD + CSV import/export |
| Couriers | `CourierController` | Full CRUD + API test connection |
| Shipments | `ShipmentController` | Index/show/update/track/cancel/retry |
| Reviews | `ReviewController` | Index/destroy/approve |
| Service Bookings | `ServiceBookingController` | Index/show/update/assign (assigned_staff_id → admins.id) |
| Settings | `SettingController` | Index/update + theme appearance + logo upload |
| Subscription Plans | `SubscriptionPlanController` | Full CRUD + toggle status (delete blocked if has subscribers/content) |
| Paid Content | `PaidContentController` | Full CRUD + toggle status (HTML body with Edit/Preview tabs) |
| Subscribers | `SubscriptionController` | Index with filters (status/plan/search) + show detail |
| Subscription Setup | Closure | Documentation page (cron setup, proration, key files reference) |

### REST API Routes (api.php, prefix `/api`, Sanctum protected)

| Method | URI | Description |
|--------|-----|-------------|
| POST | `api/auth/send-otp` | Send OTP to phone (register or login) |
| POST | `api/auth/verify-otp` | Verify OTP, returns user + Sanctum token |
| POST | `api/register` | Register (legacy email+password) |
| POST | `api/login` | Login (legacy email+password) |
| POST | `api/logout` | Logout |
| GET/PUT | `api/profile` | Get/update profile |
| GET | `api/products` | Product listing (with variants) |
| GET | `api/products/{slug}` | Product detail (with variants, reviews) |
| GET | `api/categories` | Category listing |
| GET | `api/services` | Service listing |
| GET/POST/PUT/DELETE | `api/cart` | Cart CRUD |
| GET/POST | `api/orders` | Orders (variant-aware) |
| GET/POST/PUT/DELETE | `api/addresses` | Address CRUD |
| POST | `api/payment/razorpay/create` | Create Razorpay order |
| POST | `api/payment/razorpay/verify` | Verify payment |
| GET | `api/pincodes/{pincode}/check` | Check pincode serviceability |
| GET/POST | `api/wishlist` | Wishlist |
| POST | `api/coupons/validate` | Validate coupon |
| GET | `api/banners` | Banners |
| POST | `api/products/{id}/reviews` | Add review |
| GET | `api/images/{path}` | Image proxy (serves storage files with CORS headers) |
| GET | `api/subscription-plans` | All active plans (enriched with subscription_action + proration for auth users) |
| GET | `api/subscription-plans/{slug}` | Single plan detail (enriched) |
| POST | `api/subscriptions` | Subscribe to a plan (validates via SubscriptionService) |
| GET | `api/subscriptions` | User's subscription history |
| GET | `api/paid-contents` | User's accessible paid content list |
| GET | `api/paid-contents/{slug}` | Full paid content detail |

---

## Database Schema (34 migrations)

### Core Tables

| Table | Key Columns |
|-------|-------------|
| `users` | id, name, email (nullable), password (nullable), phone, phone_verified_at, avatar, is_active — customers only |
| `admins` | id, name, email, phone, password, avatar, is_active, role (legacy string), email_verified_at, timestamps |
| `addresses` | id, user_id, name, phone, address_line1/2, city, state, pincode, is_default |
| `categories` | id, name, slug, description, image, is_active, sort_order |
| `products` | id, category_id, name, **brand**, slug, sku, description, short_description, **composition**, **dosage**, **classification**, **recommended_crops**, price, compare_price, cost_price, stock_quantity, low_stock_threshold, weight, image, is_active, is_featured |
| `product_images` | id, product_id, image_path, sort_order, is_primary |
| `product_variants` | id, product_id, name, sku, price, **compare_price**, stock_quantity, **image**, attributes (json) |
| `services` | id, category_id, name, slug, description, short_description, base_price, price_unit, duration_value, duration_unit, is_active, is_featured |
| `service_bookings` | id, service_id, user_id, booking_date, address, status, total_amount, notes, assigned_staff_id (→ admins.id) |

### Order & Payment Tables

| Table | Key Columns |
|-------|-------------|
| `orders` | id, user_id, order_number (sequential 5-digit), type (product/service), status, subtotal, tax, shipping_charge, pincode_delivery_charge, discount, total_amount, payment_method, payment_status, billing_address (json), shipping_address (json), notes, delivered_at |
| `order_items` | id, order_id, product_id, name, quantity, price, total |
| `payments` | id, order_id, transaction_id, payment_method, amount, status, gateway_response (json) |

### Delivery & Logistics Tables

| Table | Key Columns |
|-------|-------------|
| `courier_partners` | id, name, slug, api_key, api_secret, api_url, is_active, config (json) |
| `shipments` | id, order_id, courier_partner_id, tracking_number, status, estimated_delivery, actual_delivery, tracking_url, courier_response (json), cost |
| `pincodes` | id, pincode (unique), city, state, is_serviceable, delivery_charge, estimated_days, is_active |

### Roles & Permissions (Spatie — admin guard)

| Table | Key Columns |
|-------|-------------|
| `roles` | id, name, guard_name (`admin`) |
| `permissions` | id, name, guard_name (`admin`) |
| `model_has_roles` | role_id, model_type, model_id |
| `model_has_permissions` | permission_id, model_type, model_id |

### Subscription Tables

| Table | Key Columns |
|-------|-------------|
| `subscription_plans` | id, name, slug (unique), description, tier (1-10), price (decimal), billing_period (monthly/quarterly/yearly), is_active, has_free_delivery, has_fast_support, features (json), sort_order |
| `subscriptions` | id, user_id, subscription_plan_id (restrictOnDelete), status (active/expired/cancelled), start_date, end_date, payment_method, payment_status, razorpay_order_id, razorpay_payment_id, amount_paid (decimal) |
| `paid_contents` | id, title, slug (unique), content_type (spray_schedule/nutrition/custom), custom_type_label, summary, body (longText HTML), image, required_plan_id (restrictOnDelete), is_active, sort_order |
| `user_badges` | id, user_id, badge_type (pro_member), earned_at, expires_at |

### Other Tables

| Table | Key Columns |
|-------|-------------|
| `banners` | id, title, subtitle, image, link, position, is_active, sort_order |
| `coupons` | id, code, type (fixed/percent), value, min_order, max_uses, used_count, expires_at, is_active |
| `reviews` | id, product_id, user_id, rating (1-5), comment, is_approved |
| `wishlists` | id, user_id, product_id |
| `stock_adjustments` | id, product_id, adjustment, type, reason, adjusted_by |
| `notifications_log` | id, user_id, type, channel, subject, body, status |

---

## Models (38 total)

`Admin`, `User`, `Address`, `Category`, `Brand`, `Product`, `ProductImage`, `ProductVariant`, `Service`, `ServiceBooking`, `BookingAvailability`, `Order`, `OrderItem`, `Payment`, `Pincode`, `CourierPartner`, `Shipment`, `Banner`, `Coupon`, `NotificationsLog`, `NotificationTemplate`, `Wishlist`, `Review`, `StockAdjustment`, `SubscriptionPlan`, `Subscription`, `PaidContent`, `UserBadge`, `Wallet`, `WalletTransaction`, `Reel`, `ReelLike`, `ReelComment`, `PosCustomer`, `PosInvoice`, `PosInvoiceItem`, `PosCreditTransaction`, `Setting`

**User model traits:** `HasApiTokens` (Sanctum), `HasFactory`, `Notifiable`, `HasRoles`

**User model subscription methods:** `currentSubscription()`, `hasProMemberBadge()`, `hasFreeDelivery()`, `hasFastSupport()`, `currentPlanName()`, `walletBalance()`

**Product model:** `brand`/`brand_id`, `composition`, `dosage`, `classification`, `recommended_crops` fields + `variants()` HasMany + `images()` HasMany + `reels()` + static `reduceStock`/`restoreStock`/`adjustStock` (with `StockAdjustment` logging)

---

## Customer Auth Flow (Phone + OTP)

### Registration (2 steps)
1. Enter **name** + **10-digit mobile number** (starts with 6-9)
2. Enter OTP (demo: `1234`) → account created + auto-login

### Login (2 steps)
1. Enter **mobile number**
2. Enter OTP (demo: `1234`) → logged in

### Key details
- **No password required** — OTP-only auth for customers
- **Demo OTP is always `1234`** — gateway integration planned later
- **OTP stored in session** (web) / **cache** (API), expires in 5 minutes
- **Phone validation:** 10 digits, starts with 6-9, strips +91/0 prefixes
- **PhoneVerified middleware** — protects checkout, orders, and profile routes
- **Existing email+password login** still works via API (`POST /api/login`)
- Users table: `email` and `password` columns are now **nullable**

---

## Phone Gate Popup

- Every shop page shows a full-screen overlay until the user verifies their phone number
- **Routes:** `GET /phone-gate/status`, `POST /phone-gate/send-otp`, `POST /phone-gate/verify` (all public)
- **Session flags:** `phone_gate_verified`, `phone_gate_phone`
- **Alpine.js `phoneGate()` function** in shop layout — checks status on init, shows overlay if not verified
- **Two screens:** Phone input → OTP input, with loading states and error handling
- **On verify:** `User::firstOrCreate` + `Auth::login()` + session flag set — auto-creates account if needed

---

## Customer Dashboard

- **Controller:** `CustomerDashboardController` — 14 methods (index, orders, orderShow, cancelOrder, addresses, addressStore, addressUpdate, addressDestroy, addressSetDefault, profile, profileUpdate, subscription, subscribe, paidContent, paidContentShow)
- **Layout:** `layouts/customer.blade.php` — extends shop layout, adds sidebar with nav links (Dashboard, My Orders, Addresses, My Subscription [with PRO badge], Paid Content [if pro], Profile, Back to Shop)
- **Views:** dashboard (stats + recent orders), orders (paginated), order-show (detail + cancel), addresses (CRUD with Alpine.js modal), profile (name/phone/email, no password), subscription (current plan + available plans with proration), paid-content (content grid), paid-content-show (full HTML view)
- **Order cancellation:** Only allowed for `pending` status orders
- **Subscription:** Shows current plan status, available plans with upgrade/proration/pricing breakdown, confirm dialog before subscribe
- **Paid Content:** Tier-gated content accessible to users with sufficient plan tier

---

## Product System (BigHaat-Style)

### Product Details

Products include agricultural-specific fields:
- **Brand** — displayed prominently (e.g., "Bayer", "IFFCO")
- **Composition / Technical Content** — shown in a blue highlighted badge (e.g., "Imidacloprid 17.8% SL")
- **Dosage & Usage** — displayed in a dedicated tab with amber styling
- **Classification** — e.g., "Chemical", "Organic", "Bio"
- **Recommended Crops** — displayed as green tags

### Product Variants (Size Options)

Simple size variant system — no multipack grouping:
- **Admin:** Dynamic Alpine.js rows for adding/removing variants with Name, SKU, Price, Compare Price, Stock
- **Shop:** Clickable size buttons with discount % badges
- **Dynamic pricing:** Price, compare price, savings, and stock update via Alpine.js when variant is selected
- **Cart integration:** `variant_id`, `variant_name`, variant-specific price/image stored in session cart
- **Stock:** Deducted from `product_variants.stock_quantity` when variant exists, else from `products.stock_quantity`
- **API:** `variant_id` accepted in order creation endpoint

### Multi-Image Gallery

- **Admin Create:** Featured image upload + multiple additional images with preview
- **Admin Edit:** Grid of existing images with "Set Primary" and "Delete" hover actions + add more images
- **ProductImage model:** `image_path`, `sort_order`, `is_primary` — primary auto-assigned to first image
- **Deletion:** Files removed from storage, primary reassigned if deleted
- **Destroy route:** `DELETE /admin/products/{product}/images/{image}`

### Image Gallery (Shop)

- **Main image** + **scrollable thumbnail strip** below
- **Touch swipe:** Left/right swipe on mobile to navigate between images
- **Arrow buttons:** Desktop hover reveals left/right navigation arrows
- **Dot indicators:** Mobile shows dot indicators at bottom of main image
- **Thumbnail auto-scroll:** Active thumbnail scrolled into view when switching
- **Infinite cycling:** Last image wraps to first, first wraps to last
- All images (base `image` + gallery `product_images`) unified into single array

---

## Cart System

- **Session-based** (`Session::get('cart')`) — no auth required for browsing/adding
- **Auth required** for checkout only
- Cart items store: `product_id`, `variant_id`, `variant_name`, `name` (with variant suffix), `price`, `image`, `quantity`, `slug`
- **Variant-aware deduplication:** Same product with different variants stored as separate cart items
- **Buy Now:** Clears cart, adds single product with variant, redirects to checkout
- Quantity update and remove by array index
- **AJAX delivery rate** on checkout — calls `/shipping-rate` on address/pincode change
- **Pincode check on product page** — AJAX widget shows delivery charge, estimated days, city

### Product Page Buttons (Responsive)

- **Mobile:** Floating bottom bar with quantity selector + Buy Now button (backdrop blur, safe-area support)
- **Desktop:** Floating bottom bar with quantity selector + Buy Now button
- Both include `variant_id` and `quantity` hidden fields

---

## Shipping Rate Calculation (4-tier fallback)

0. **Pro subscriber free delivery** — `hasFreeDelivery()` returns true for active subscription with `has_free_delivery` flag
1. **Delhivery API** rate endpoint (when available — currently returns 404)
2. **Pincode table** `delivery_charge` column
3. **Config fallback** — `max(₹50 default, weight_kg × ₹10/kg)` from `config/shop.php`

---

## Payment Flow

1. User selects Razorpay or COD at checkout (conditionally shown based on admin settings)
2. **Config toggles:** `shop.enable_razorpay` and `shop.enable_cod` control visibility + validation
3. Razorpay: create order via `RazorpayService`, JS checkout popup, verify signature
4. COD: order placed with `payment_status: pending`

---

## Subscription System

### Plans (Tiered Access)

4 seeded plans with tier-based access control:

| Plan | Tier | Price | Period | Free Delivery |
|------|------|-------|--------|---------------|
| Basic | 1 | ₹99 | Monthly | No |
| Pro | 2 | ₹299 | Monthly | Yes |
| Pro Quarterly | 2 | ₹749 | Quarterly | Yes |
| Premium Yearly | 3 | ₹2,499 | Yearly | Yes |

- Higher tiers unlock all content from lower tiers
- Same tier or lower = blocked (no re-subscribe)
- `is_active` flag controls plan visibility

### Proration (Upgrades)

Centralized in `SubscriptionService` — used by both web controllers and API:

```
total_days     = end_date - start_date
remaining_days = end_date - today
credit         = (current_plan_price / total_days) × remaining_days
final_price    = new_plan_price - credit
```

- **Upgrade:** Old subscription cancelled, new one starts immediately with prorated pricing
- **Same/Downgrade:** Blocked, user must wait for expiry
- **First subscription:** Full price, no proration
- **amount_paid:** Stores actual amount charged (prorated for upgrades, full for new)

### Pro Member Benefits

- **Free delivery:** `hasFreeDelivery()` checked in `CartController::shippingRate()` — returns 0 charge
- **Fast support:** `hasFastSupport()` — available for future priority queue
- **Badge:** `UserBadge` with `badge_type = pro_member` — auto-removed when expired

### Expiration (Cron Job)

- **Command:** `php artisan subscriptions:expire`
- **Schedule:** Daily at midnight via `routes/console.php`
- **Logic:** Sets `active` → `expired` for subscriptions past `end_date`, deletes expired pro_member badges
- **Safety net:** `currentSubscription()` also filters by `end_date >= now()` at query time
- **Server setup:** Single cron line on aaPanel: `* * * * * cd /path && php artisan schedule:run`

### Key Files

| File | Purpose |
|------|---------|
| `app/Services/SubscriptionService.php` | Core business logic (canSubscribe, calculateProration, processSubscription, enrichPlan) |
| `app/Console/Commands/ExpireSubscriptions.php` | Daily expiration command |
| `routes/console.php` | Scheduler registration |
| `app/Http/Controllers/Api/SubscriptionApiController.php` | API endpoints (plans, subscribe, paid content) |
| `app/Http/Controllers/CustomerDashboardController.php` | Web subscription routes |
| `app/Http/Controllers/Admin/SubscriptionPlanController.php` | Admin plans CRUD |
| `app/Http/Controllers/Admin/PaidContentController.php` | Admin paid content CRUD |
| `app/Http/Controllers/Admin/SubscriptionController.php` | Admin subscribers list |
| `admin/subscriptions/setup/index.blade.php` | Documentation page in admin panel |

### Database Tables

- `subscription_plans` — Plan definitions with tier, pricing, features
- `subscriptions` — User subscriptions with status, dates, amount_paid
- `paid_contents` — Tier-gated content (spray schedules, nutrition guides, etc.)
- `user_badges` — Pro member badges with expiry

---

## Pincode System

- Admin sets per-pincode delivery charges via `/admin/pincodes`
- CSV import/export for bulk pincode management
- Product page pincode checker widget (AJAX)
- Checkout uses dynamic rate from Delhivery API / pincode table / config

---

## Order Numbering

Sequential 5-digit starting at `10000` (via `Order::boot` creating hook)

---

## Delhivery API Integration Details

| Detail | Value |
|--------|-------|
| API Token | `4d9b35c3769087cef6d80fecb8475ef3b85a35d6` (stored in `courier_partners` table) |
| Base URL | `https://track.delhivery.com` |
| Auth | `Authorization: Token <token>` header |
| HTTP Client | Raw `curl_*` (Laravel Http/Guzzle times out intermittently) |
| CMU Endpoint | `POST /api/cmu/create.json` — `application/x-www-form-urlencoded`, body `format=json&data=<json>`. **`data` must be `{ shipments: [...], pickup_location: { name, city, pin, country, phone, add } }`** — a top-level `pickup_location` OBJECT next to `shipments`. Passing `pickup_location` as a flat string inside a shipment makes Delhivery allocate a waybill but fail to consume it (`Unable to consume <waybill> for <client>`). Order id field is `order` (not `order_number`). `pickup_location.name` must match the registered warehouse name exactly (case-sensitive) |
| CMU Fields | Shipment: `order`, `add`, `city`, `state`, `pin`, `phone`, `name`, `country`, `address_type`, `payment_mode`, `cod_amount`, `total_amount`, `tax_value`, `invoice_number`, `seller_inv`, `seller_gst_tin`, `seller_name`, `seller_add`, `quantity`, `products_desc`, `commodity_value`, `hsn_code`, `shipping_mode`, `weight` (gms), `shipment_length/width/height`, `category_of_goods`, return_* keys |
| Package Details | Current Delhivery CMU API uses **flat fields, not a nested `products[]` array** (the old `products[]` shape is silently dropped → blank item details/quantity in the portal). Send `quantity` (total units), `products_desc` (joined item names), `commodity_value`, `tax_value`, `weight` (`"1200 gm"`), `hsn_code` (comma-joined; per-product `products.hsn_code` column added Aug 04, falls back to `shop.delhivery_hsn_default`). Verified live: `InvoiceAmount` + `Quantity` now populate (order 7 waybill `56223310000372`) |
| Edit / Cancel | `POST /api/p/edit` — **direct JSON body** (`Content-Type: application/json`), NOT `format=json&data=`. Update keys: `waybill`, `gm`, `shipment_length/width/height`, `cod`, `name`, `add`, `product_details`, `pt`. Cancel uses `{ waybill, cancellation: "true" }`; success returns `status: true` + `waybill` |
| Tracking | `GET /api/v1/packages/json/?waybill=<number>` |
| Phone Rule | Must be 10 digits (no `+91` prefix) — `parseAddress()` strips country code |
| Pincode Check | `GET /c/api/pin-codes/json/?filter_codes=<pin>` (header auth) — live API; falls back to local `pincodes` table only if the API errors. Use `filter_codes=`; the `filter[delivery_codes][pincode]=` format hangs the server. Response `postal_code` uses `pin` + `pickup`/`cash`/`pre_paid` flags (no `services` key) |
| Rate API | `GET /api/kinko/v1/invoice/charges.json?md=E&cgm=<grams>&o_pin=<origin>&d_pin=<dest>&ss=Delivered` (header auth) — **requires the `/api` prefix**; the bare `/kinko/v1/invoice/charges.json` returns 404. Returns array with `total_amount` (post-tax). Live-verified (Aug 04): 192124→110001 @600g = ₹237.06, 192124→192301 @600g = ₹74.56. Checkout now uses Delhivery rates (cached per pin/weight-bucket); estimated days still fall back to the pincode table (no EDD in response) |
| Shipment Guard | `createShipment()` skips if order already has tracking number; deletes stale error shipments before retry |

---

## CORS & Image Proxy (Flutter Web)

Flutter web runs on CanvasKit renderer which forces `<img crossOrigin="anonymous">` on all images. Laravel's `php artisan serve` serves static files bypassing CORS middleware, so:

- **`GET /api/images/{path}`** proxy route in `routes/api.php` serves storage files through Laravel middleware with `Access-Control-Allow-Origin: *` header
- **`AppNetworkImage` widget** in `widgets/app_network_image.dart` — platform-aware: uses `Image.network` on web (which triggers the proxy), `CachedNetworkImage` on mobile
- **CORS config** (`config/cors.php`): `paths: ['*']`, `allowed_origins` includes `https://magrayorchards.com`
- **Sanctum stateful domains** (`config/sanctum.php`): includes `magrayorchards.com`

---

## Configuration (.env)

```env
DB_CONNECTION=mysql
DB_DATABASE=magray
DB_USERNAME=root
DB_PASSWORD=

RAZORPAY_KEY=your_razorpay_key
RAZORPAY_SECRET=your_razorpay_secret

DELHIVERY_API_TOKEN=4d9b35c3769087cef6d80fecb8475ef3b85a35d6
DELIVERY_DEFAULT_COURIER=delhivery

SHOP_NAME=Magray Orchards
SHOP_PICKUP_PINCODE=192124
SHOP_PICKUP_STATE=Jammu and Kashmir
SHOP_PICKUP_CITY=Srinagar
SHOP_DEFAULT_SHIPPING_RATE=50
SHOP_PER_KG_SHIPPING_RATE=10

MAIL_MAILER=smtp
SMS_PROVIDER=twilio
```

---

## Flutter App

- Location: `flutter_app/`
- State management: Provider
- **Android package:** `com.magray.orchards`
- **Android app name:** Magray Orchards
- **Web port:** `http://localhost:5555`
- **API URL (dev):** `http://localhost:8000/api`
- **API URL (production):** `https://magrayorchards.com/api`
- **Image URL (production):** `https://magrayorchards.com/api/images/`
- **Web renderer:** CanvasKit (only option in Flutter 3.41)
- Features: Phone+OTP auth, product browsing (featured horizontal scroll), cart, Buy Now, order placement with order number dialog, address management, wishlist, service booking, order cancellation, subscription plans with proration, paid content viewing
- **Safe number parsing:** `_toDouble()` helpers handle Laravel's `decimal:2` String serialization
- **Product detail:** In-page Buy Now/Add to Cart removed; floating bottom bar with quantity + Buy Now retained
- **Home featured products:** Horizontal scrollable list from `featuredProducts` (not `products`)

---

## Running the Server

### Development

```bash
# Laravel backend
cd "D:\ai apps\MagrayOrchards\backend"
php artisan serve --port=8000

# Flutter web
cd "D:\ai apps\MagrayOrchards\flutter_app"
flutter run -d chrome --web-port=5555
```

- **Homepage:** http://localhost:8000
- **Register:** http://localhost:8000/register (phone + OTP)
- **Login:** http://localhost:8000/login (phone + OTP)
- **Admin Login:** http://localhost:8000/admin/login
- **Admin Panel:** http://localhost:8000/admin (after login)
- **API Base:** http://localhost:8000/api
- **Flutter Web:** http://localhost:5555

### Production (aaPanel)

- **Domain:** https://magrayorchards.com
- Deploy Laravel backend with Nginx on aaPanel
- Flutter web build deployed alongside or via CDN
- Production URLs configured in `config/shop.php`, `config/cors.php`, `config/sanctum.php`

---

## Completed Phases

*The following phases (1-54) were added during the original build. Features added after phase 54 are documented below in "Post-Phase 54 Features" and in the sections above.*

| Phase | Status |
|-------|--------|
| 1. Laravel scaffold, auth, DB, models, seeders | ✅ Done |
| 2. Admin panel (16 controllers, 40+ views) | ✅ Done |
| 3. Customer web storefront (homepage, products, categories, services, cart) | ✅ Done |
| 4. REST API for Flutter (29+ endpoints) | ✅ Done |
| 5. Service layer (delivery, payment, notifications) | ✅ Done |
| 6. Flutter app skeleton | ✅ Done |
| 7. Role-based access control (Spatie, 3 roles, ~52 permissions) | ✅ Done |
| 8. Delhivery integration (CMU create, tracking, pincode serviceability) | ✅ Done |
| 9. Product images (10 stock photos from Unsplash) | ✅ Done |
| 10. Pincode CSV import/export, courier CRUD with test connection | ✅ Done |
| 11. Full frontend redesign (brand-* design system, dynamic theme) | ✅ Done |
| 12. Auth pages redesign (split-screen branded layout) | ✅ Done |
| 13. Shipment management (index/show/track/cancel/retry, stats, search) | ✅ Done |
| 14. Pincode delivery check widget on product page | ✅ Done |
| 15. Dynamic shipping rates at checkout (Delhivery API + fallback) | ✅ Done |
| 16. Admin form components (5 shared Blade components) | ✅ Done |
| 17. Theme customization (8 palettes, 4 fonts, 3 sidebar styles, logo upload) | ✅ Done |
| 18. Admin/staff separation (admins table, admin guard, separate login) | ✅ Done |
| 19. Admin routes middleware fix (removed web auth, AdminMiddleware handles guard) | ✅ Done |
| 20. Phone + OTP authentication (register/login via phone, demo OTP 1234, API endpoints) | ✅ Done |
| 21. Phone gate popup (full-screen overlay, auto-create account, session flags) | ✅ Done |
| 22. Customer dashboard (orders, addresses, profile, cancel orders) | ✅ Done |
| 23. Buy Now feature (clears cart, adds single product, redirects to checkout) | ✅ Done |
| 24. Checkout payment methods (conditional on admin config enable_razorpay/enable_cod) | ✅ Done |
| 25. DeliveryManager active courier check (falls back to local if inactive) | ✅ Done |
| 26. Product page responsive design (mobile floating bar, safe-area, backdrop blur) | ✅ Done |
| 27. Product details (brand, composition, dosage, classification, recommended crops) | ✅ Done |
| 28. Product variants (size options with per-variant pricing and stock) | ✅ Done |
| 29. Multi-image gallery (featured image + gallery with primary assignment) | ✅ Done |
| 30. Image gallery with swipe (touch swipe, arrow buttons, dot indicators, thumbnails) | ✅ Done |
| 31. Flutter web CORS fix (image proxy route, AppNetworkImage widget) | ✅ Done |
| 32. Flutter production URLs (api_config.dart, product_image.dart, config files) | ✅ Done |
| 33. Laravel toDouble crash fix (safe _toDouble() helpers for decimal:2 serialization) | ✅ Done |
| 34. Product detail screen cleanup (removed in-page buttons, floating bottom bar only) | ✅ Done |
| 35. Featured products bug fix (pp.featuredProducts, horizontal scroll list) | ✅ Done |
| 36. Home page product card gap fix (Spacer → SizedBox height:4) | ✅ Done |
| 37. Order success dialog (order number display + View Order button) | ✅ Done |
| 38. Android package rename (com.magray.orchards) + app label (Magray Orchards) | ✅ Done |
| 39. Production deployment config (CORS, Sanctum, logo_url env) | ✅ Done |
| 40. Subscription system (plans, proration, badges, free delivery, API + Flutter) | ✅ Done |
| 41. Subscription admin (plans CRUD, paid content CRUD, subscribers list, setup docs) | ✅ Done |
| 42. Subscription expiration cron (daily artisan command + scheduler) | ✅ Done |
| 43. Subscription purchase rules (same plan blocked, downgrade blocked, upgrade with proration) | ✅ Done |
| 44. Subscription setup documentation (admin panel, cron guide, key files reference) | ✅ Done |
| 45. Shipping & parcel overhaul: shared ShippingCalculator, admin free-delivery threshold, courier fixes (Local/Delhivery/Shiprocket), parcel fields, shipments in API orders | ✅ Done |
| 46. Flutter checkout uses `POST /api/shipping-rate`; order detail shows tracking timeline + opens tracking URL | ✅ Done |
| 47. Delhivery API-authoritative pincode + rate checks: cached serviceability/rate/EDD, weight-aware ShippingCalculator (courier + estimated_days), API-driven `/pincode-check` + `/api/pincodes/{pin}/check`, product page (web + Flutter) sends `product_id` | ✅ Done |
| 48. Live Delhivery shipment creation fixed (CMU payload schema per portal docs) — top-level `pickup_location` object + `order` field; verified live on orders 4/5/6 → `56223310000346`/`56223310000350`/`56223310000361` all **manifested** | ✅ Done |
| 49. Delhivery package details fixed: CMU now sends flat `quantity`/`products_desc`/`commodity_value`/`weight`/`hsn_code`/`tax_value` (old nested `products[]` was silently dropped); `products.hsn_code` column + admin field added; `cancelShipment` fixed to send direct JSON body to `/api/p/edit` (was form-encoded). Verified live on waybill `56223310000372` (InvoiceAmount/Quantity now populate); cancel + cleanup verified | ✅ Done |
| 50. Delhivery rate API fixed: correct URL is `/api/kinko/v1/invoice/charges.json` (missing `/api` prefix caused the 404); `getShippingRate` returns real post-tax charges (192124→110001 @600g = ₹237.06, 192124→192301 @600g = ₹74.56); origin pincode corrected to `shop.pickup_pincode`; stale zero-rate caches cleared; checkout now uses live Delhivery rates | ✅ Done |
| 51. Order cancellation requires a reason: `orders.cancellation_reason` (string 255) + `orders.cancelled_at` (timestamp) columns; customer cancel (API + web) validates reason as **required** (dropdown of common reasons); admin cancel records optional reason; reason + cancelled date shown on customer order page, admin order page, and Flutter order detail. Verified live via API (422 without reason, cancel succeeds with reason) | ✅ Done |
| 52. Customer cancel now also cancels the courier shipment: API + web cancel call `DeliveryManager->cancelShipment(waybill)` before cancelling the order (blocks with a clear message if the package was already picked up / courier refuses). Cancel button hidden once the shipment has moved beyond `manifested` (web + Flutter show it only for pending/manifested/created/error, none otherwise). Verified live: waybill `56223310000431` + `56223310000420` cancelled on Delhivery (`status:true, "Shipment has been cancelled."`) | ✅ Done |

---

## Remaining / Future Work

| Task | Priority |
|------|----------|
| Configure Firebase: add service-account JSON + `FIREBASE_PROJECT_ID` to `.env`; create `google-services.json`/`google-services.plist`; build Flutter with `--dart-define=FIREBASE_*` credentials | High |
| Deploy Laravel backend to aaPanel at magrayorchards.com | High |
| Set up aaPanel cron: `* * * * * php artisan schedule:run` | High |
| Install Flutter APK on Infinix phone (APK ready, device needs reconnect) | High |
| Deploy Flutter web build to production (set `--dart-define=API_BASE_URL=https://magrayorchards.com/api`) | High |
| Razorpay integration testing with real keys | High |
| Add `DELHIVERY_API_TOKEN` to `.env` and verify live API rates/serviceability | High |
| Order confirmation emails (template overrides via admin Notification Templates) | Medium |
| SMS gateway credentials (currently `sms_driver: log`) | Medium |
| Merge guest cart with server cart on login (currently server wins) | Medium |
| Reels share button (currently a stub) | Low |
| Search autocomplete | Low |
| Responsive testing on mobile | Low |

---

## Shipping & Parcel System Overhaul (Aug 03, 2026)

- **Consistent rate logic** in `app/Services/Shipping/ShippingCalculator.php` — chain: subscription free delivery → admin `free_delivery_threshold` → courier rate → pincode table → config fallback. Order placement never hard-blocks; the config fallback rate applies to any pincode.
- **Delhivery API-authoritative (Phase 47):** `DelhiveryService::checkServiceability` hits Delhivery pin-codes API (`filter_codes=` param — the old `filter[delivery_codes][pincode]` format hangs the server; verified live, 8s timeout, cached 6h via `shop.delhivery_cache_ttl`), parses `postal_code.pin` + `pickup`/`cash`/`pre_paid` flags, falls back to the local `pincodes` table only on API failure. `getShippingRate` and `getEstimatedDays` (parses `expected_delivery_date`/`edd`/`sla`) are cached per pincode/weight-bucket. `DeliveryServiceInterface` gained `getSlug()` + `getEstimatedDays()`. `ShippingCalculator::calculate()` accepts a `weightOverride` and returns `courier` slug + `estimated_days`. `isServiceable()` is now API-authoritative (display endpoints show "not available" for unserved/unknown pins while actual order placement still falls back to config rates).
- **Endpoints:** `/pincode-check` (web) and `/api/pincodes/{pin}/check` accept `product_id` (uses the product's price/weight so free-delivery threshold + weight-based rates apply) and return `is_serviceable`, `delivery_charge`, `estimated_days`, `courier`, `free_delivery`, `source`, `city`/`state`.
- **UI:** web product page pincode widget sends `product_id` and shows the courier name + free-delivery hint; Flutter `product_detail_screen` sends `product_id` and shows courier label + free-delivery text.
- **Note:** Delhivery rate API was returning 404 because the URL was missing the **`/api` prefix** — correct endpoint is `/api/kinko/v1/invoice/charges.json` (not `/kinko/v1/invoice/charges.json`). **Fixed (Phase 50)** and live-verified (Aug 04): `getShippingRate` now returns real post-tax Delhivery charges, e.g. 192124→110001 @600g = ₹237.06, 192124→192301 @600g = ₹74.56 (full calculator: source `courier`, courier `delhivery`). Stale zero-rate caches cleared; origin pincode corrected to `shop.pickup_pincode` (192124). No EDD in the charges response, so `estimated_days` still falls back to the pincode table / config. Verified serviceability: 110001/110011/560001/400001/700001 serviceable via Delhivery, 999999/111111 not.
- **Order cancellation reason (Phase 51):** `orders.cancellation_reason` (nullable string 255) + `orders.cancelled_at` (timestamp). Customer cancel — `Api\OrderController@cancel` (Flutter) and `CustomerDashboardController@cancelOrder` (web) — now require `cancellation_reason` (max 255). Admin `Admin\OrderController@update` accepts an optional reason and stamps `cancelled_at` on cancel (clears both when un-cancelling). Display: customer order page shows a "Order cancelled / Reason: …" banner; admin order page shows "Cancelled On" + "Cancellation Reason"; Flutter `order_detail_screen` adds a reason dropdown + refund-method choice to the cancel dialog and shows the reason under the Cancelled status. Verified live: API returns 422 when reason missing, cancels with reason when provided.
- **Customer cancel also cancels the courier shipment (Phase 52):** both cancel paths now call `DeliveryManager->cancelShipment(tracking_number)` first (helper `cancelCourierShipment()` in each controller). If the shipment is `picked_up`/`in_transit`/`out_for_delivery`/`delivered` or the courier refuses, the order cancel is blocked with a clear message. The cancel button is now hidden once the shipment has moved past `manifested`: web + Flutter show it only when status is pending **and** shipment is null/`pending`/`created`/`manifested`/`error`. Verified live: customer cancel cancelled waybill `56223310000431` on Delhivery (`status:true, remark:"Shipment has been cancelled."`); also retro-cancelled the user's earlier order 12 waybill `56223310000420`.
- **Admin order page redesigned (Phase 53):** `admin/orders/show.blade.php` fully rewritten into a professional order+shipment management page — order progress stepper (hidden for cancelled/refunded/returned), collapsible Manage Order form (status/payment/cancellation reason), order items table (image/SKU/HSN), inline Shipment card with status badge + edit-shipment collapsible form, shipment actions (Refresh Tracking, Open Tracking, Cancel Shipment, Retry on error), live tracking timeline, tracking-error card, collapsible Courier API Response, and right sidebar with Customer / Shipping Address / Payment / Order Info cards. `Admin\OrderController@show` eager-loads `shipment.courierPartner` + `shipment.order` and fetches tracking via `DeliveryManager->getService($slug)->trackShipment()`. Bug fixed: the tracking-error card never rendered because the view checked `$trackingInfo['error']`/`['not_found']` keys while services return `status => 'error'`/`'not_found'` — conditions now use `in_array($trackingInfo['status'] ?? null, ['error','not_found'], true)`.
- **Delhivery refnum collision retry (Phase 53):** `DelhiveryService::createShipment` now detects Delhivery "Duplicate order id" rejections (order numbers restart at 10000 after an `orders`-table rebuild, so refnums collide with old, un-cancelled waybills) and retries **once** with a unique refnum suffix `{order_number}-{ymdHis}-{rand}` (applied to `order`/`invoice_number`/`seller_inv`). Request/response handling extracted to `attemptShipmentCreation()`. Live-verified: refnum 10003 rejected → retried as `10003-260804013846-421` → manifested (waybill `56223310000486`). Also cancelled orphaned live waybill `56223310000405` (order 10 was cancelled without cancelling its shipment) and deleted the last test orders 10/12/16 — DB now has 0 orders/shipments/items.
- **Delhivery shipping label (Phase 54):** the **correct contract is `GET {api_url}/api/p/packing_slip`** with query params `wbns={waybill}` + `pdf=true` + `pdf_size=A4` (the initial `POST /api/p/label` guess returned 404; contract confirmed from a public Delhivery SDK + the official readme docs — the portal page itself is JS-rendered/login-gated). Response is JSON `{packages:[{pdf_download_link}]}`; the link is a **public signed S3 PDF** (24h expiry), fetchable directly. `DelhiveryService::getShippingLabel(string $trackingNumber): array` now returns `['pdf'=>bytes|null, 'url'=>s3 link|null, 'error'=>string|null]` (helper `downloadPdf()` streams the S3 URL; non-JSON `%PDF` bodies pass through). `DeliveryServiceInterface` gained `getShippingLabel()`; `LocalDeliveryService`/`ShiprocketService` return "labels not available" error arrays. New route `GET admin/shipments/{shipment}/label` → `ShipmentController::downloadLabel()`: streams PDF as `attachment; filename="waybill-<wbn>.pdf"` (Content-Type `application/pdf`, `Cache-Control: no-store`), redirects to the S3 URL if only a url is returned, 403-style flash when no waybill / cancelled / error shipment. **Download Label buttons added on all 3 pages** — `admin/orders/show.blade.php` (header action row + shipment action row, 2 buttons), `admin/shipments/show.blade.php` (header actions), `admin/shipments/index.blade.php` (Actions cell chip) — all gated on `tracking_number` present and status not `cancelled`/`error`. Live-verified: waybill `56223310000501` → 55,899-byte `%PDF-1.7` label; HTTP route returned 200 `application/pdf` with correct `Content-Disposition`; unknown waybill → error array. All test orders/shipments deleted after verification (DB back to 0 orders/shipments/items); test waybills cancelled on Delhivery.
- **Free delivery threshold** configurable in admin settings (Shipping tab, `shop.free_delivery_threshold`, default 999).
- **Courier services fixed:** `LocalDeliveryService` (writes `carrier='local'`, manifested status, pincode overrides), `ShiprocketService` (DB-backed via `CourierPartner`), `DelhiveryService` (weight/dimensions/GST from config), `DeliveryManager` falls back to `shop.default_courier_id`.
- **Live Delhivery shipment creation fixed (Phase 48):** `createShipment` now sends the CMU payload per the Delhivery portal OpenAPI spec — `pickup_location` is a **top-level object** `{ name, city, pin, country, phone, add }` (was a flat string inside the shipment → Delhivery allocated a waybill but never consumed it into a valid manifest: "Unable to consume … for b19cbd-MagrayOrchards-do"), and the order id field is **`order`** (was `order_number` → `refnum: ""`). Warehouse name must match Delhivery exactly (`Magray Orchards`, from `shop.pickup_location`). Verified live: orders 4/5/6 → waybills `56223310000346`/`56223310000350`/`56223310000361`, all **manifested**. Old stuck waybills `56223310000335`/`56223310000302` are no longer reused and do not block new shipments (contact `client.support@delhivery.com` only if you want them cleaned up).
- **Parcel columns** added to `orders` (`parcel_weight_kg`, `parcel_length/width/height_cm`, `parcel_volumetric_weight_kg`, `parcel_charge`) and stored on order creation; shipments store `carrier`, `current_location`, `cancelled_at`.
- **API:** `POST /api/shipping-rate` (`Api\ShippingController@rate`, auth) used by Flutter; `Api\OrderController@store` computes rates + auto-creates shipment.
- **Admin:** pincode rate overrides (base/per-kg) + CSV import/template; `OrderController@update` auto-creates shipments and fires shipping/order notifications; shipments index courier filter + Parcel column + stats; retry reuses original courier.
- **Flutter:** `checkout_screen.dart` calls `/shipping-rate` (items + pincode + subtotal), shows "Free" shipping state, fetches on initial address load; `order_detail_screen.dart` renders `courier_response` timeline and opens `tracking_url` via `url_launcher`.
- **Note:** `orders` table was rebuilt from scratch (was corrupt); `order_items`, `shipments`, `payments`, `wallet_transactions` preserved; historical order rows unrecoverable.

---

## Post-Phase 54 Features (Aug 2026)

> These features were built after the original phase log. See the section tables above for the directory tree; this section documents the capabilities.

### Wallet System
- **Web:** `/wallet`, `POST /wallet/topup`, `POST /wallet/topup/verify` (`CustomerWalletController`); **API:** `GET /wallet`, `GET /wallet/transactions`, `POST /wallet/topup`, `POST /wallet/topup/verify` (`Api\WalletController`); **Admin:** `AdminWalletController` (credit/debit + balance API) under `wallet.*` permissions.
- `Wallet` model has atomic `credit()`/`debit()`/`refund()` (row-lock + `WalletTransaction` ledger with `balance_after`). `WalletService` handles Razorpay top-up (₹1–₹50,000), signature verification, idempotency (never double-credits a payment id), order deduction (`wallet`/`partial_wallet` payment methods), subscription deduction, refunds on cancellation, and admin credit/debit.
- **Checkout** (web + Flutter) supports full-wallet and partial-wallet + Razorpay for the remainder. Order cancellation refunds wallet portion (`refund_method: wallet|original`).
- **Flutter:** `wallet_screen.dart` (balance card + filter chips) + `wallet_topup_screen.dart` (preset amounts + Razorpay).

### Point of Sale (Admin)
- `Admin\PosController` + `PosService`: product search/SKU (barcode) lookup, checkout (`pos.store`), printable invoice (`pos/invoice/{invoice}`), invoice list, POS customers + **credit ledger** (credit limit enforcement, sale/payment/adjustment transactions), reports.
- Permissions: `pos.view`, `pos.sell`, `pos.credit`, `pos.reports`. Stock is deducted (variant-aware) with GST computed from `shop.tax_rate`.
- Models: `PosCustomer` (credit_limit/credit_balance), `PosInvoice` (auto `POS-1000+` numbering), `PosInvoiceItem` (variant support), `PosCreditTransaction`.

### Reels (Short Video Feed)
- **API:** `GET /api/reels`, `GET /api/reels/{id}`, `POST /api/reels/{reel}/like`, `GET/POST /api/reels/{reel}/comments` (`Api\ReelController`); **Admin CRUD:** `Admin\ReelController` + status toggle.
- `Reel` supports `youtube` or `uploaded` video (served via image proxy), optional linked `product_id`, like/comment counts.
- **Flutter:** `reels_screen.dart` (vertical PageView, YouTube/video playback, like rail, product Buy Now) + `reels_comments_sheet.dart` + `ReelsProvider`. Reels is the 2nd tab in the 5-tab home shell.

### Brands
- **API:** `GET /api/brands`, `GET /api/brands/{slug}`; **Web:** `/brands`, `/brands/{slug}`; **Admin CRUD:** `Admin\BrandController`.
- `Brand` model (auto-slug, `hasMany products`); `Product` gained `brand_id` relation + `brand_info` append.

### Configurable Home Layout (Flutter)
- Admin `MobileAppController::updateHomeLayout` stores a JSON `home_layout` in `shop.mobile_app_home_layout`; exposed publicly at `GET /api/config` (`home_layout` key).
- Flutter `ShopConfig.homeSections` → `HomeLayout`/`HomeSection` drives the modern home tab order: announcement, delivery bar, banner carousel, categories, brands, promo, subscription, services, and product sections (source: offers/featured/newest/category/brand; layout: grid/carousel; rows/limit configurable).
- The home shell is a **5-tab NavigationBar** (Home/Reels/Services/Cart/Profile). The modern configured home is implemented for the Home tab; the other tabs still use legacy widgets (`_legacyBuild`).

### Mobile App Version / Maintenance Gating
- Admin `MobileAppController` (permissions `mobile-app.view/edit`): Android/iOS latest + min version, store URLs, update notes, maintenance mode (+ message/until).
- `GET /api/config` exposes all of these. Flutter `splash_screen` gates on `maintenanceEnabled` → `MaintenanceScreen`, and `< minVersion` → `UpdateRequiredScreen` (soft-update banner when `>= min && < latest`).

### Service Bookings with Distance Pricing
- **Travel services** (`services.service_type` = `physical`) charge a travel fee: `BookingPricingService::quote` = base price + travel charge (`booking_per_km_rate` ₹15/km, `booking_free_km` 5, `booking_min_travel_charge` ₹100, origin from `shop.booking_base_lat/lng`). Distance via `DistanceService` (Google Distance Matrix → haversine×fallback).
- `BookingAvailability` (date + max_bookings) with daily capacity checks + range lookup; admin bulk management (`Admin\BookingAvailabilityController`).
- **API:** `GET /api/services/{slug}/quote`, `GET /api/bookings/availability`, `POST /api/services/{slug}/book`, `GET /api/bookings`, `POST /api/bookings/{id}/payment/create|verify` (`Api\ServiceBookingController`); **Web:** `/services/{slug}/quote`, `/services/{slug}/book`, `/geocode/reverse`, `/my-bookings`, `POST /bookings/{booking}/verify-payment`.
- **Flutter:** `service_detail_screen.dart` (GPS/address location, quote card, availability calendar, time slots, Razorpay via `booking_payment.dart`) + `my_bookings_screen.dart` (Pay Now for unpaid).

### Settings Table + ShopSettingsService
- `settings` KV table (JSON values); `ShopSettingsService::mergeIntoConfig()` loads all DB settings into `config('shop.*')` at boot (called from `AppServiceProvider`); `set()` normalizes booleans/numbers and persists.
- `Admin\SettingController` (8-tab settings page: General, Authentication, Email & SMS, Shipping & Pickup, Bookings, Notifications, Appearance, Social/SEO) + test email/SMS; `PaymentSettingsController` (GST, gateways, transactions ledger); `MarketingController` (hero/promo content); `NotificationTemplateController` (editable email/SMS templates via `TemplateRegistry::DEFAULTS`).

### Notification Templates
- `NotificationTemplate` model + `TemplateRegistry` (11 default triggers: order placed/confirmed/shipped/delivered, password reset, OTP, account created, etc.) with `{{placeholder}}` substitution, per-channel enable flags, 1h cache. `EmailService`/`SmsService` log all sends to `NotificationsLog`.

### Auth: Password + Forgot/Reset
- Customers now have an optional **password** (password login, `login/password` + `/api/auth/password-login`), **forgot-password** OTP flow (web + `/api/auth/forgot-password`, `/api/auth/reset-password`). `users.password`/`email` remain nullable. OTP expiry is **5 min**, 5 attempts, 15-min lockout, resend support.

### Push Notifications (Firebase FCM)
- **Backend FCM client** — `app/Services/Notification/FcmService.php` implements the **FCM HTTP v1 API** with dependency-free RS256 JWT auth (service-account JSON → OAuth2 token → `fcm.googleapis.com/v1/projects/{id}/messages:send`). Config via `FIREBASE_CREDENTIALS` (path to service-account JSON) + `FIREBASE_PROJECT_ID` in `.env`/`config/services.php`.
- **Orchestration** — `PushNotificationService` sends transactional pushes (rendered from `TemplateRegistry` push templates), records every message into the per-user **in-app inbox** (`push_notifications` table) so users see notifications even without a registered device, resolves device tokens, and runs promotional **campaigns** (`push_campaigns` table) with audience segments.
- **Triggers wired up:** order placed/confirmed/processing/shipped/out-for-delivery/delivered/cancelled/refunded/returned, service-booking confirmed/cancelled, subscription activated/cancelled, wallet credited. Wired through `NotificationService` (email+SMS+push fan-out) at order placement (web + API), admin status updates, customer cancellation, booking admin updates, and subscription subscribe/verify/cancel.
- **API (Sanctum):** `POST /api/notifications/device-token` (register), `DELETE /api/notifications/device-token` (unregister), `GET /api/notifications` (inbox), `GET /api/notifications/unread-count`, `POST /api/notifications/{id}/read`, `POST /api/notifications/read-all`.
- **Admin customization:** Notification Templates page now edits **push title + body** per trigger with an on/off toggle (in addition to email/SMS). New **Push Notifications** admin section (`admin/marketing/push`) sends promotional campaigns with audience filters (active accounts, min orders, min spend, active subscription, specific plan/tier, state/city, registration date, wallet balance) — preview audience count before sending; campaign history logged.
- **Global toggle:** Settings → Notifications tab → "Enable Push Notifications" (`shop.enable_push_notifications`, exposed at `GET /api/config`).
- **Firebase config in Settings:** Settings → **"Firebase & Push" tab** manages everything: backend service-account JSON upload (stored at `storage/app/firebase/firebase-credentials.json`), project ID, database URL, the Flutter app config (API key, app ID, messaging sender ID, auth domain, storage bucket), a "Test Connection" button (validates the service-account JWT → OAuth2 token), and a status indicator. Values persist under the `services.firebase` namespace (like payment-gateway creds) and are exposed to the app at `GET /api/config` (the app reads them at startup — no rebuild needed when using the server-provided values).
- **Permissions:** `push.view`, `push.send` (Super Admin + Manager get them via the seeder; Staff does not).
- **Flutter:** `firebase_core` + `firebase_messaging`; `PushService` initializes Firebase from `--dart-define` credentials (gracefully disabled when unset), registers/rotates the device token on login, shows an **in-app banner** for foreground messages, **deep-links** tapped notifications (order/booking/subscription/notifications), and syncs the unread badge. **Notifications screen** (bell icon in home header + Profile menu) lists the inbox with read/unread states, mark-read, mark-all-read, and pull-to-refresh. Android manifest adds `POST_NOTIFICATIONS` permission + default FCM channel; `minSdk = 23`.
- **Tests:** `tests/Feature/NotificationApiTest.php` (device-token register/unregister/re-auth revoke, inbox, mark-read, unread count, admin campaign preview).

### Reports (Admin)
- **Route:** `GET /admin/reports` (`ReportsController@index`) under the new `reports.view` permission; sidebar menu item under Dashboard. Export routes: `GET /admin/reports/export-excel`, `GET /admin/reports/export-pdf` (same tab + date filters).
- **Tabs:** Orders, Revenue, Stock, POS, Subscriptions, Wallets, Bookings, Customers — with a **date-range filter** (from/to, defaults to last 30 days) preserved across tabs and exports.
- **`ReportDataService`** (`app/Services/Reports/ReportDataService.php`) builds each report as an ordered list of **sections** (title, columns, rows) — shared by the HTML view, Excel and PDF so all three always match. Each report includes a summary section (money/int formatted) plus detail tables (order list, status distribution, payment methods, top products, invoice list, plan/status breakdown, wallet transaction list, booking list, customer list).
- **Exports:** Excel via **`phpoffice/phpspreadsheet`** (`Xlsx` writer, styled section headers, auto-size columns, streamed download) and PDF via **`barryvdh/laravel-dompdf`** (A4 landscape, branded header, styled tables). Filenames: `report-<tab>-<timestamp>.xlsx/.pdf`.
- **Tests:** `tests/Feature/ReportsTest.php` (page loads, tab+date filter, Excel download, PDF download, permission gate).

---

## Recent Bug Fixes & Cleanup (Aug 21, 2026)

| # | Fix |
|---|-----|
| 55 | **Flutter compile error** — `razorpay_web_impl.dart` was failing to build on web (stale `debugPrint` error). Verified `flutter build web` compiles cleanly; web impl works via injected checkout.js. |
| 56 | **`SettingController::update()` dropped the Google Maps API key** — it wrote then immediately `unset` the value so it was never persisted. Now kept in the persisted `shop.*` settings. |
| 57 | **`RoleController` created roles with the `web` guard** — `Role::create()` now passes `guard_name => 'admin'`; `index`/`create`/`edit` filter permissions/roles to the admin guard. |
| 58 | **`default_shipping_rate` was `''` → ₹0 fallback** — config now defaults to 50, and `ShippingCalculator`/`LocalDeliveryService` guard against empty overrides so checkout never silently charges ₹0. |
| 59 | **`Admin\OrderController::update()` never set `delivered_at`** — now stamps `now()` on delivered and clears on un-deliver (matching the ShipmentController path). |
| 60 | **`mapDelhiveryStatus()` unreachable `rto` branch** — `rto` was caught by the `in transit` branch first; moved so RTO statuses map to `cancelled`. |
| 61 | **Flutter `ApiConfig.baseUrl` hardcoded to localhost** — now overridable via `--dart-define=API_BASE_URL=...` / `API_IMAGE_BASE_URL=...` (defaults to localhost for dev). |
| 62 | **Flutter `_onUnauthorized` never wired** — `AuthProvider` now registers the callback and clears the session on 401 (with a recursion guard so it doesn't call the logout API). |
| 63 | **Flutter theme fonts not bundled** — added `google_fonts` package; `buildThemeData()` wraps the base theme with `GoogleFonts.<family>TextTheme()` so Inter/Poppins/Roboto/Playfair Display actually render. |
| 64 | **Push notifications via Firebase FCM** — `FcmService` (HTTP v1, RS256 JWT), `PushNotificationService` (inbox + campaigns), push fields on all notification templates, device-token API, admin promotional push with audience segments, global toggle, Flutter inbox/banner/deep-links. See "Push Notifications" section above. |
| 65 | **Admin Reports** — new `Reports` section (`admin/reports`) with tabs for Orders/Revenue/Stock/POS/Subscriptions/Wallets/Bookings/Customers, date-range filters, and Excel (`phpspreadsheet`) + PDF (`dompdf`) downloads via `ReportDataService`. See "Reports" section above. |
| 66 | **Flutter Razorpay multiplatform compile & runtime typing** — `razorpay_factory.dart` switched to `dart.library.html` so Dart 3.11 analyzer on native targets never imports web js libraries; `razorpay_native_impl.dart` normalizes `PaymentSuccessResponse` and error callbacks into standardized `Map<String, String>` matching web, preventing runtime type casting crashes on Android/iOS. |
| 67 | **Currency IEEE 754 float precision** — `intval($amount * 100)` replaced with `(int) round($amount * 100)` across `PaymentController`, `WalletService`, and `RazorpayService` to prevent 1-paisa rounding errors. |
| 68 | **Restored Laravel automated test suite** — `TestCase.php`, `Unit/ExampleTest.php`, `Feature/PhoneAuthTest.php`, `Feature/WalletServiceTest.php`, `Feature/SubscriptionTest.php`, and `Feature/ShippingCalculatorTest.php` added. 13 tests, 39 assertions passing. |
| 69 | **Added Flutter test suite** — `test/models_test.dart` added covering `User`, `ProductVariant`, and `HomeSection` JSON serialization and safe decimal-to-double conversions. |
| 70 | **Storefront front-page UI/UX enhancements (ui-ux-pro-max)** — upgraded `welcome.blade.php` and `layouts/shop.blade.php`: added 4-pillar trust strip (Free Delivery ₹999+, 100% Genuine, Agronomist Advisory, COD/UPI), quick search chips in hero, dual-action product cards ("Cart" + "Buy Now"), trusted brand showcase, polished service cards with "Book Visit" CTA, and floating agronomist support FAB with one-tap WhatsApp and phone dialing. |

---

*Last updated: Nov 01, 2026*
