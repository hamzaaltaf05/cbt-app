# Honour Shop — Project State & Continuation Guide

> **Created:** 10/15/2026
> **Last updated:** 10/22/2026
> **Purpose:** Pick up work in a new chat. Read this file first.
> **Latest work (10/22/2026):** **Facility Issues screen built** and wired into `HomeScreen`; **app title → "CBT"** (`MaterialApp`); **app icon generated** via `flutter_launcher_icons`; **theme system** added (`app_theme.dart` — full light + dark palettes, `ThemeMode.system`). `dart analyze` → **No issues found**.

---

## 1. Project Overview

Flutter app (`cbt_app`) that integrates with **Supabase** (Postgres + Auth + Storage).
Features:
- **Shop Items** — add / view / **edit** / delete honour shop items (name, price, category, image). Edit UI added 10/20/2026.
- **User Roles** — `admin`, `shop_manager`, `employee` (stored as Postgres ENUM `user_role`)
- **Facility Issues** — report / track / resolve facility issues (schema + screen built 10/22/2026)
- **User Management** — admin can view/change roles (screen exists: `user_management_screen.dart`)
- **Auth** — Supabase email/password auth with profile auto-creation via trigger

### Project structure
```
lib/
  main.dart
  models/
    facility_issue.dart
    shop_item.dart
    user_profile.dart
  screens/
    facility_issues_screen.dart   ← NEW (10/22/2026)
    home_screen.dart
    login_screen.dart
    shop_items_screen.dart
    user_management_screen.dart
  utils/
    app_theme.dart                ← NEW (10/22/2026)
    env.dart
    supabase_client.dart

assets/
  app_icon.png                    ← NEW (10/22/2026)

supabase/
  migrations/
    04_patch_existing_schema.sql
```

---

## 2. Supabase SQL Files (run in this order in SQL Editor)

### ✅ Already in Supabase (ran before this session)

#### `01_schema_and_rls`
Creates ENUMs (`user_role`, `issue_status`), tables (`profiles`, `shop_items`, `facility_issues`), `get_user_role()` function, and all RLS policies.

#### `02_user_profile_trigger`
`handle_new_user()` trigger on `auth.users` — auto-creates profile row on signup.

#### `03_storage_policies`
`facility-photos` bucket: SELECT public, INSERT authenticated.

### ⬜ NOT yet in Supabase — needs to be run

#### `04_patch_existing_schema`  ← `supabase/migrations/04_patch_existing_schema.sql`

| # | What it does |
|---|---|
| 1 | `ALTER TABLE shop_items` — adds `category TEXT DEFAULT 'Other'`, `is_available BOOLEAN DEFAULT true`, `created_at TIMESTAMPTZ DEFAULT now()` |
| 2 | `CREATE OR REPLACE handle_new_user()` — **first user = admin**, everyone else = employee |
| 3 | `prevent_role_self_change()` trigger — blocks non-admins from changing any role |
| 4 | `update_shop_items_updated_at()` trigger — auto-sets `updated_at` on update |
| 5 | `profiles_admin_update` RLS policy — admin can UPDATE any profile (for role assignment) |
| 6 | Indexes on `shop_items(category)`, `shop_items(is_available)`, `shop_items(created_at DESC)` |

> **`001_initial_setup.sql` was intentionally deleted** — it would have created a conflicting `items` table, a duplicate `get_my_role()` function, and a second auth trigger.

---

## 3. Changes Made This Session (Flutter code)

### `lib/models/user_profile.dart`
| Line | Before | After | Why |
|---|---|---|---|
| 11 | `return 'simple_user';` | `return 'employee';` | DB ENUM value is `employee`, not `simple_user` |
| 32 | `case 'simple_user':` | `case 'employee':` | `fromLabel` must match DB value |

> The Dart enum constant name is still `UserRole.simpleUser`. Its `.label` now maps to `'employee'` (DB value). `displayName` still shows `'Simple User'` in UI.

### `lib/screens/shop_items_screen.dart`
| Line | Before | After | Why |
|---|---|---|---|
| 57 | `.from('items').select()` — **no `.execute()`** | `.from('shop_items').select().order('created_at', ascending: false).execute()` | Table name was wrong; missing `.execute()` meant query never ran |
| 141 | `.from('items').insert(...)` — **no `.execute()`** | `.from('shop_items').insert({...}).execute()` | Same fixes |
| 190 | `.from('items').delete(...)` — **no `.execute()`** | `.from('shop_items').delete().eq('id', item.id).execute()` | Same fixes |

> `shop_item.dart` model was already correct — expects `category`, `is_available`, `image_url` which the new DB columns (added in 04) provide.

---

## 4. DB Schema (final expected state after running file 04)

### `public.profiles`
| Column | Type | Notes |
|---|---|---|
| id | UUID | PK, FK → auth.users, ON DELETE CASCADE |
| full_name | TEXT | |
| role | user_role | DEFAULT `'employee'`, ENUM: admin / shop_manager / employee |

### `public.shop_items`
| Column | Type | Notes |
|---|---|---|
| id | UUID | PK, DEFAULT gen_random_uuid() |
| name | TEXT | |
| price | NUMERIC(10,2) | |
| image_url | TEXT | nullable |
| category | TEXT | DEFAULT 'Other' ← **added in 04** |
| is_available | BOOLEAN | DEFAULT true ← **added in 04** |
| created_at | TIMESTAMPTZ | DEFAULT now() ← **added in 04** |
| updated_at | TIMESTAMPTZ | DEFAULT now(), auto-updated by trigger |
| updated_by | UUID | FK → profiles(id) |

### `public.facility_issues`
| Column | Type | Notes |
|---|---|---|
| id | UUID | PK |
| title | TEXT | |
| description | TEXT | |
| image_url | TEXT | nullable |
| status | issue_status | DEFAULT 'pending', ENUM: pending / in_progress / resolved |
| reported_by | UUID | FK → profiles(id) |
| assigned_to | UUID | FK → profiles(id) |
| admin_response | TEXT | |
| created_at | TIMESTAMPTZ | DEFAULT now() |

---

## 5. RLS Policy Summary

| Table | Policy | Who | What |
|---|---|---|---|
| profiles | "viewable by auth users" | authenticated | SELECT |
| profiles | "updateable by self" | owner | UPDATE |
| profiles | "profiles_admin_update" ← 04 | admin | UPDATE (any row) |
| shop_items | "viewable by auth users" | authenticated | SELECT |
| shop_items | "manageable by admins/managers" | admin, shop_manager | ALL |
| facility_issues | "viewable by auth users" | authenticated | SELECT |
| facility_issues | "creatable by auth users" | authenticated | INSERT |
| facility_issues | "updatable by admins" | admin | UPDATE |
| storage: facility-photos | "view access" | public | SELECT |
| storage: facility-photos | "upload access" | authenticated | INSERT |

---

## 6. Triggers

| Trigger | Table | Fires | What |
|---|---|---|---|
| handle_new_user | auth.users | AFTER INSERT | Creates profile; **first user = admin**, rest = employee (replaced in 04) |
| trg_prevent_role_self_change | profiles | BEFORE UPDATE | Blocks non-admins from changing roles (added in 04) |
| trg_shop_items_updated_at | shop_items | BEFORE UPDATE | Sets `updated_at = now()` (added in 04) |

---

## 7. What's Still TODO

- [ ] **Run `04_patch_existing_schema.sql`** in Supabase SQL Editor
- [ ] **E2E test the Shop Items screen** — as **admin/shop_manager**: add → tap the pencil → change name/price/category → save (verify the list refreshes **and** the Supabase Table Editor row updates) → swipe-delete. As **employee/simpleUser**: confirm view-only (no add/edit/delete; DB also blocks writes).
- [ ] **Test role enforcement** — employee cannot add/delete; non-admin cannot change roles
- [x] **Facility Issues screen** — ✅ **DONE 10/22/2026**: full `FacilityIssuesScreen` built + wired into `HomeScreen` (§13)
- [ ] **User Management screen** — verify it works with the new admin-update RLS policy
- [ ] **Image upload** for shop items (only `facility-photos` bucket policies exist; need a second bucket or folder)
- [x] **Item editing** — ✅ **DONE 10/20/2026**: edit pencil on each item tile + `_showEditItemDialog` (name/price/category) via `.update()`. `is_available` toggle **intentionally NOT added** (user decision — view-only for now).
- [ ] **Search / filter** by category on shop items screen
- [ ] **Logout** button / user info display on home screen
- [ ] **Error handling** — some catch blocks are minimal

---

## 8. Key Gotchas / Reminders

1. **`UserRole.simpleUser`** is the Dart enum name; its `.label` is `'employee'` (matches DB). Don't rename the constant — it's used in `shop_items_screen.dart` and `user_management_screen.dart`.
2. **No `.execute()` needed.** This project uses `supabase_flutter: ^2.18.0` (supabase_dart 2.x), where `await client.from('t').select()` **is** the `Future` — it fires the HTTP call directly. `.execute()` is a legacy/v1 pattern and is **not** required here. (The earlier "missing `.execute()`" hypothesis was a red herring — see §10.)
3. **Table name is `shop_items`** (not `items`). All Flutter code now references `shop_items`.
4. **`001_initial_setup.sql` was deleted.** Do NOT recreate it — it conflicts with the existing schema.
5. The trigger name in the DB is `handle_new_user` (from file 02). File 04 only replaces the **function body**, not the trigger. The trigger continues to work.
6. **Storage bucket `facility-photos`** is for facility issue images. A separate bucket (or folder convention) will be needed for shop item images.
7. **Shop Items permission model = `admin` OR `shopManager`.** `simpleUser` (DB role `employee`) is **view-only** — the app hides add/edit/delete for them *and* the RLS policy blocks their writes. Don't gate on `simpleUser` again (that was the earlier mismatch fixed on 10/20).
8. **No UPDATE migration is needed for Shop Items edit.** The `shop_items` policy "manageable by admins/managers" (`admin`, `shop_manager`) is `ALL` — it already includes UPDATE and DELETE. Verified against live RLS on 10/20/2026.

---

## 9. How to Run / Test

```bash
# Flutter
flutter pub get
flutter run

# Supabase local (if using local dev)
supabase start
supabase db reset   # runs all migrations in supabase/migrations/

# Supabase cloud
# Open https://supabase.com/dashboard → SQL Editor
# Paste contents of 04_patch_existing_schema.sql and Run
```

---

## 10. Fix Applied — Infinite Loading on Shop Items & User Management (10/16/2026)

**Symptom:** Shop Items and User Management screens stayed frozen on the loading spinner forever.

**Real root cause:** After `await`-ing the Supabase query, `_items`/`_users` and `_isLoading` were assigned **without `setState`**, so Flutter never scheduled a new frame and the widget never left the spinner state.

> ⚠️ The earlier `.execute()` hypothesis was a **red herring** (see corrected §8.2). The query was always being sent; the UI just never re-rendered.

**Fix** (matches the already-working `home_screen.dart` & `facility_issues_screen.dart`): wrap every post-`await` state mutation in `if (mounted) setState(() { ... })`.

| File | Method | Change |
|---|---|---|
| `lib/screens/shop_items_screen.dart` | `_loadItems()` | success + catch state now in `if (mounted) setState(...)` |
| `lib/screens/shop_items_screen.dart` | `_loadProfileAndItems()` | catch state now in `if (mounted) setState(...)` |
| `lib/screens/user_management_screen.dart` | `_loadUsers()` | success + catch state now in `if (mounted) setState(...)` |

The `mounted` guard also prevents a "setState called after dispose" crash if the user navigates away mid-request.

**Verified:** `flutter analyze` on both files → **0 errors, 0 warnings** (4 pre-existing `info` lints in unrelated dialog handlers).

> ⚠️ Superseded: those remaining `info` lints were resolved by 10/20/2026 — see §11 (current analyze is fully clean).

---

## 11. Shop Items Edit Feature + Role Alignment (10/20/2026) ← LATEST

**Goal:** Align the Shop Items screen's permission checks with live Supabase RLS (`admin` + `shop_manager`) and add an edit (update) capability.

### Decisions
- **Permission model aligned to the DB:** manage rights = `admin` **or** `shop_manager` (matches the `shop_items` policy "manageable by admins/managers", granted to exactly `admin, shop_manager`).
- `simpleUser` (DB role `employee`) is **view-only**: the app hides add/edit/delete for them, and the DB blocks their writes regardless.
- **No migration needed for editing** — the `ALL` policy on `shop_items` already grants UPDATE + DELETE (confirmed via live RLS).
- **`is_available` toggle intentionally NOT added** (explicit user decision). The DB column + model field exist; only the edit dialog omits it for now.

### Code changes — `lib/screens/shop_items_screen.dart`
| What | Change |
|---|---|
| `kShopCategories` | New shared `const` list of 7 categories, reused by **both** the add and edit dialogs |
| `_canManageItems` | Now `UserRole.admin \|\| UserRole.shopManager` (was `admin \|\| simpleUser`) — gates the **add button, the edit pencil, AND swipe-to-delete** |
| `_buildItemTile` | Added a **pencil `IconButton`** (right side, shown only when `_canManageItems`) that opens the edit dialog |

> ⚠️ Superseded (10/21/2026): the item card was later simplified — the `isAvailable` status chip was removed and the price now shows an **`Rs`** prefix. See §12.
| `_showEditItemDialog` | **New method** — pre-fills name/price/category, saves via `.from('shop_items').update({...}).eq('id', item.id)`, then `_loadItems()` |

### `lib/models/user_profile.dart` (current shape)
- `enum UserRole { admin, shopManager, simpleUser }`
- `extension UserRoleLabel`: `.label` → `'admin'` / `'shop_manager'` / `'employee'`; `UserRoleLabel.fromLabel(String)` maps DB strings back (unknown → `simpleUser`).
- `UserProfile.fromMap` reads `row['role'] as String?` and resolves via `fromLabel`.

### Verified
- `flutter analyze` on `shop_items_screen.dart`, `user_profile.dart`, `shop_item.dart` → **No issues found** (0 errors / 0 warnings / 0 info).
- The earlier `use_build_context_synchronously` lints in the dialog `catch` blocks are fixed (`mounted` / `context.mounted` guards).

### Next up (immediate)
- [ ] **E2E test edit end-to-end**: `flutter run` → log in as **admin** or **shop_manager** → tap the pencil on an item → change name/price/category → save → confirm the list refreshes **and** the Supabase row updated. Then swipe-delete and confirm removal.
- [ ] Confirm a **simpleUser/employee** login sees **no** add/edit/delete controls (view-only).

### Known open items (updated 10/22/2026)
- ~~Facility Issues UI screen~~ → **Built** (§13, 10/22/2026)
- Image upload for shop items (needs its own bucket/folder)
- Category search/filter on the Shop Items screen
- Logout button / user info on home screen

---

## 12. Shop Items Card UI Refinement (10/21/2026) ← LATEST

**Goal:** Simplify the Shop Items card in `_buildItemTile` — drop the redundant availability chip and show the price as a proper currency value.

### Code changes — `lib/screens/shop_items_screen.dart` (`_buildItemTile`)
| What | Change |
|---|---|
| `isAvailable` chip | **Removed** the `isAvailable` / "Available" / "Unavailable" status chip from the card |
| Name | Simplified to a single `Text` (was `Column` of name + chip) |
| Price | Now renders as **`'Rs ${item.price.toStringAsFixed(2)}'`** (added the `Rs` currency prefix) |

The card now shows, top to bottom: **Category chip → Name → `Rs` price → Edit pencil** (edit pencil only when `_canManageItems`).

### Decisions / scope
- **`is_available` left in the model & DB.** Only the UI display of it was removed. The `ShopItem` model field and the `shop_items.is_available` column (added in `04_patch_existing_schema`) are unchanged, so nothing else breaks.
- This is a display-only change — no Supabase migration, no new permissions.

### Verified
- `dart analyze lib/screens/shop_items_screen.dart` → **No issues found** (0 errors / 0 warnings / 0 info).
- (Along the way, `flutter analyze` flagged one real issue at line 374: `unnecessary_string_escapes` from a stray backslash in `'\Rs ...'`; removed so the price line is now a clean `'Rs ${item.price.toStringAsFixed(2)}'`.)

### Next up (immediate)
- [ ] Visual check on device/emulator: confirm each card shows **category chip, name, `Rs`-prefixed price** and (for `admin` / `shop_manager`) the **edit pencil** — and that no availability chip remains.
- [ ] (Optional) If the `is_available` field is now unused everywhere, consider removing it from `shop_item.dart` + the DB column to keep the schema lean.

### Known open items (updated 10/22/2026)
- ~~Facility Issues UI screen~~ → **Built** (§13, 10/22/2026)
- Image upload for shop items (needs its own bucket/folder)
- Category search/filter on the Shop Items screen
- Logout button / user info on home screen

---

## 13. Facility Issues Screen — Built (10/22/2026)

**Goal:** Provide a full Facility Issues screen for reporting and tracking issues, wired into the home-screen navigation.

### What was built
| Item | Detail |
|---|---|
| File | `lib/screens/facility_issues_screen.dart` (new) |
| Home screen nav | `home_screen.dart` — added **Facility Issues** tile (icon: `Icons.report_problem`, subtitle: "Report & track facility issues") with `Navigator.push` to `FacilityIssuesScreen` |
| Auth guard | `StreamBuilder` on `Supabase.instance.client.auth.onAuthStateChange` — unauthenticated users redirected to `LoginScreen` (same pattern as other screens) |
| `mounted` guards | All post-`await` state mutations wrapped in `if (mounted) setState(...)` to prevent `use_build_context_synchronously` lints |

### Verified
- `dart analyze` → **No issues found** (0 errors / 0 warnings / 0 info).
- Facility Issues tile appears on the home screen for all authenticated roles.

### Superseded
- §7 TODO and §11/§12 "Known open items" listed *"Facility Issues UI screen (schema + model exist, no screen yet)"* — **now resolved**.

---

## 14. App Branding — Title & Icon (10/22/2026)

**Goal:** Establish the "CBT" brand in the app title and generate a custom launcher icon.

### Changes

#### `lib/main.dart`
| What | Before | After |
|---|---|---|
| `MaterialApp` title | (previous value) | `'CBT App'` |

> `lib/screens/home_screen.dart` — `AppBar` title remains **`Text('Convergent')`** (unchanged, confirmed in screenshot).

#### `pubspec.yaml`
| What | Change |
|---|---|
| `dev_dependencies` | Added `flutter_launcher_icons: ^0.14.3` |
| End of file | Added `flutter_launcher_icons:` config block — `android: true`, `ios: false`, `image_path: "assets/app_icon.png"` |

#### App icon
| What | Detail |
|---|---|
| Icon source | `assets/app_icon.png` (generated) |
| Generation command | `dart run flutter_launcher_icons` |
| Platform | Android enabled, iOS disabled |

### Verified
- `assets/app_icon.png` present in the project.
- `dart analyze` → **No issues found**.

---

## 15. Theme System — Light & Dark (10/22/2026)

**Goal:** Introduce a full brand-aligned light + dark theme and wire it into `MaterialApp`.

### Files

#### `lib/utils/app_theme.dart` (new)
| Section | What it provides |
|---|---|
| `AppColors` | Static color constants — greens (`#00994D` primary, `#0A6C3B` secondary), amber accent (`#F5A623`), green-tinted neutrals, and full dark-mode variants (bg `#0B1612`, surface `#15221C`, dark primary `#22C55E`) |
| `AppTheme` | `static ThemeData get light` / `static ThemeData get dark` — complete `ThemeData` for both modes: `colorScheme`, `appBarTheme`, `cardTheme`, `inputDecorationTheme`, `bottomSheetTheme`, `dialogTheme`, `dividerTheme`, `progressIndicatorTheme`, `switchTheme`, `radioTheme`, `checkboxTheme`, `searchBarTheme`, `tabBarTheme`, `textSelectionTheme`, `floatingActionButtonTheme` |

#### `lib/main.dart`
| What | Value |
|---|---|
| `theme` | `AppTheme.light` |
| `darkTheme` | `AppTheme.dark` |
| `themeMode` | `ThemeMode.system` — app follows the device OS brightness setting |
| `debugShowCheckedModeBanner` | `false` |

### Decision: No in-app dark mode toggle
- The app has **no** `SharedPreferences`-backed toggle or time-based logic.
- Dark mode is **purely OS-driven** (`ThemeMode.system`).
- **User confirmed (10/22/2026): keep as-is** — no code change needed.
- If a toggle is added later: swap `ThemeMode.system` for `ThemeMode.light` / `ThemeMode.dark` and persist the choice via `SharedPreferences`.

### Verified
- `dart analyze lib/utils/app_theme.dart` → **No issues found**.
- **Light mode**: white background, green-tinted surfaces, emerald primary (`#00994D`).
- **Dark mode**: deep green-black background (`#0B1612`), green-tinted surfaces, bright green primary (`#22C55E`).