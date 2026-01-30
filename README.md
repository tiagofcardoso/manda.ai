# Manda.AI - Digital Menu & Delivery System

Manda.AI is a comprehensive **Order Management and Delivery Platform** (similar to a white-label food delivery app) designed to streamline operations between customers, the kitchen, and delivery drivers. It features real-time synchronization, role-based security, and a multi-platform architecture.

## 🚀 Key Features

### 📱 1. Consumer App (Flutter)
The customer-facing mobile application focused on ordering and self-service.
*   **Digital Menu:** Browse products with categories, photos, and prices.
*   **Table Ordering (Scan & Order):** Customers scan a QR Code at their table to place orders directly to the kitchen (bypassing waiters).
*   **Delivery Flow:** Traditional cart and checkout process for delivery orders.
*   **Order Tracking:** Real-time status updates (Preparing, Out for Delivery, Delivered).

### 🛵 2. Driver App (Flutter)
Dedicated interface for delivery logistics.
*   **Driver Dashboard:** View available deliveries and accept runs.
*   **Delivery Management:** Access delivery details, customer address, and update status to "Delivered".
*   **Smart Filtering:** Row-Level Security (RLS) ensures drivers only see orders relevant to them or the open pool.

### 👨‍🍳 3. Kitchen Display System (KDS)
Operational dashboard for the kitchen staff.
*   **Real-Time Orders:** Orders appear instantly as they are placed.
*   **Production Flow:** Update status to "Preparing" and "Ready", automatically notifying the customer and driver.

### 👔 4. Admin Dashboard (Web/Flutter)
Management control panel for business owners.
*   **Overview:** Macro view of sales, active orders, and drivers.
*   **Access Control:** Full access to manage products, users, and system settings.

---

## 🛠️ Technology Stack

*   **Frontend (Mobile & Web):** [Flutter](https://flutter.dev) (Single codebase for Android, iOS, and Web).
*   **Backend & Database:** [Supabase](https://supabase.com) (PostgreSQL) for authentication, database, and real-time subscriptions.
*   **API Layer:** [Python (FastAPI)](https://fastapi.tiangolo.com) for business logic, payment processing, and complex validations.
*   **Web Admin (Legacy/Alternative):** [Next.js](https://nextjs.org) (Dashboard components).

## 🔒 Security & Architecture

The application implements **Row-Level Security (RLS)** in PostgreSQL to strictly control data access:
*   **Clients:** Can ONLY view and edit their own profile and orders.
*   **Drivers:** Can ONLY view assigned deliveries or available order pools.
*   **Admins:** Have full access to all system data.

---

## 🏁 Getting Started

### 1. Database (Supabase)
Run the provided SQL scripts in your Supabase SQL Editor to set up tables and security policies:
- `server_python/sql/supabase_schema.sql` (Structure)
- `server_python/sql/auth_schema.sql` (Triggers)
- `server_python/sql/security_hardening.sql` (Policies)

### 2. Backend (Python API)
The Python server handles specific business logic and integrations.
```bash
cd server_python
pip install -r requirements.txt
# Create a .env file with SUPABASE_URL and SUPABASE_KEY
uvicorn main:app --reload --host 0.0.0.0
```

### 3. Mobile/Web App (Flutter)
Run the main application for any role (Client/Driver/Admin).
```bash
cd app_flutter
flutter run
```

### 4. Admin Web Panel (Next.js)
*Optional: If using the Next.js specific dashboard.*
```bash
cd web_nextjs
npm run dev
```
