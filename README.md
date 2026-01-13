# Manda.AI - Digital Menu System

This is the monorepo for the Manda.AI application.

## Directory Structure

- **`app_flutter/`**: The mobile application for customers (and potentially kitchen/admin in the future). Built with Flutter.
- **`server_python/`**: The backend API for business logic, order processing, and payments. Built with Python (FastAPI).
- **`web_nextjs/`**: The web dashboard for Restaurant Admin and Kitchen Display System (KDS). Built with Next.js.

## Getting Started

### 1. Database (Supabase)
Run the SQL script `supabase_schema.sql` in your Supabase SQL Editor.

### 2. Backend (Python)
```bash
cd server_python
pip install -r requirements.txt
# Create .env file with SUPABASE_URL and SUPABASE_KEY
uvicorn main:app --reload
```

### 3. Mobile App (Flutter)
```bash
cd app_flutter
flutter run
```

### 4. Web Panels (Next.js)
```bash
cd web_nextjs
npm run dev
```
