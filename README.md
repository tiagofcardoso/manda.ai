# Manda.AI - Digital Menu & Ordering Platform

Manda.AI is a comprehensive **Order Management and Delivery Platform** designed to streamline operations between customers, the kitchen, and delivery drivers. It features real-time synchronization, role-based security, a Progressive Web App (PWA) experience, and QR-code-based table ordering.

🌐 **Live App:** [mandaai-c52e9.web.app](https://mandaai-c52e9.web.app)

---

## 🚀 Key Features

### 📱 1. Customer Experience (PWA / Mobile)

- **Digital Menu:** Browse products with categories, photos, and prices.
- **QR Code Table Ordering:** Customer scans a QR code at the table → opens the web app → automatically linked to that table → places order directly to the kitchen (no waiter needed).
- **PWA Install Prompt:** When scanning a QR code, customers are invited to install the app on their home screen.
- **Smart PWA Routing:** When the PWA is opened on a mobile device, it routes directly to the "Scan QR / Deliver at Home" choice screen (not the marketing landing page).
- **Delivery Flow:** Traditional cart and checkout for delivery orders.
- **Order Tracking:** Real-time status updates (Preparing → Out for Delivery → Delivered).

### 🍽️ 2. Table QR Code Management (Admin)

- **Table CRUD:** Admins can create/delete tables for their establishment.
- **QR Code Generation:** Each table gets a QR code encoding a URL (`https://mandaai-c52e9.web.app/#/?est=X&table=Y`) that can be scanned by any smartphone camera.
- **PDF Export & Print:** Each table's QR code can be exported as a printable A5 PDF, including the establishment name and optional logo.
- **Establishment Isolation:** Tables are scoped per establishment using `establishment_id` and Supabase RLS.
- **Sorted Display:** Cards are displayed in ascending numeric order.

### 🖨️ 3. Thermal Printer / Receipt Printing

- **Print Receipts:** Admin and Kitchen screens have a "Print" button on each order card.
- **PDF-based Printing:** Uses the `printing` Flutter package to generate and display a print dialog — works across Web, Android, and iOS.
- **Cross-Platform:** Designed with a PDF fallback to ensure compatibility without requiring direct hardware access (ESC/POS reserved for future native integration).

### 🛵 4. Driver App (Flutter)

- **Driver Dashboard:** View available deliveries and accept runs.
- **Delivery Management:** Access delivery details, customer address, and update status.
- **Smart Filtering:** RLS ensures drivers only see relevant orders.

### 👨‍🍳 5. Kitchen Display System (KDS)

- **Real-Time Orders:** Orders appear instantly as placed.
- **Production Flow:** Update status "Preparing" → "Ready", automatically notifying the customer and driver.
- **Print Button:** Print order tickets directly from the kitchen screen.

### 👔 6. Admin Dashboard

- **Overview:** Macro view of sales, active orders, and drivers.
- **Product & Menu Management:** Full CRUD for products and categories.
- **Table Management:** Manage restaurant tables and print QR codes.
- **Order Management:** View, filter, and print orders.
- **Multi-Establishment Support:** Super admins can manage multiple venues.
- **Printer Settings:** Configure receipt printer type and paper width.

---

## 🛠️ Technology Stack

| Layer | Technology |
|---|---|
| Frontend (Mobile & Web) | [Flutter](https://flutter.dev) — single codebase for Android, iOS, and Web (PWA) |
| Backend & Database | [Supabase](https://supabase.com) (PostgreSQL) — auth, DB, realtime, storage |
| API Layer | [Python (FastAPI)](https://fastapi.tiangolo.com) — business logic, admin creation |
| QR Code | `qr_flutter` — in-app QR rendering |
| PDF & Printing | `pdf` + `printing` — receipt and QR export |
| Hosting | [Firebase Hosting](https://firebase.google.com/products/hosting) |

---

## 🔒 Security & Architecture

- **Row-Level Security (RLS):** All Supabase tables enforce per-role access policies.
- **Clients:** Can only view/edit their own profile and orders.
- **Drivers:** Can only view assigned or open-pool deliveries.
- **Admins:** Full access to their establishment's data.
- **Establishment Scoping:** All admin features are tied to `establishment_id` from the admin's profile.

---

## 📲 QR Code Customer Flow

```
[Admin prints QR PDF] 
       ↓
[Customer scans QR at table]
       ↓
[Browser opens: mandaai-c52e9.web.app/#/?est=X&table=Y]
       ↓
[App detects parameters → sets table session → shows PWA install prompt]
       ↓
[Customer taps "Continuar" → goes directly to restaurant menu]
       ↓
[Customer orders → Kitchen receives order in real-time]
```

---

## 🏁 Getting Started

### 1. Database (Supabase)
Run the provided SQL scripts in your Supabase SQL Editor:
- `server_python/sql/supabase_schema.sql` (Structure)
- `server_python/sql/auth_schema.sql` (Triggers)
- `server_python/sql/security_hardening.sql` (Policies)

### 2. Backend (Python API)
```bash
cd server_python
pip install -r requirements.txt
# Create a .env file with SUPABASE_URL and SUPABASE_KEY
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### 3. Run Locally (Web)
```bash
cd app_flutter
flutter run -d chrome
```

### 4. Run on Mobile
```bash
cd app_flutter
flutter run
# Select your Android/iOS device from the list
```

### 5. Build & Deploy to Firebase
```bash
cd app_flutter
flutter build web
firebase deploy --only hosting
```

### 6. Admin Web Panel (Legacy/Next.js) *(optional)*
```bash
cd web_nextjs
npm run dev
```
