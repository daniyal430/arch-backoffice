# Arch View — WhatsApp Orders back office

Static web app (GitHub Pages) + Supabase (database, login, live updates).
Records WhatsApp orders for Arch View Restaurant & Cafe and shows the manager dashboards.
The POS / ZATCA process is untouched.

## Setup (once, about 15 minutes)

1. **Supabase project** — supabase.com → New project (any region; Frankfurt is closest to KSA).
2. **Database** — Supabase → SQL Editor → paste `schema.sql` → Run.
3. **Your login** — Authentication → Users → *Add user* → email + password (tick "auto confirm").
   The first user created becomes the manager automatically.
4. **Keys** — Project Settings → API → copy *Project URL* and *anon public* key into `config.js`.
5. **GitHub** — create repo `arch-backoffice`, upload `index.html`, `config.js`, `README.md`, `schema.sql`.
   Settings → Pages → Source: *Deploy from a branch* → `main` / root → Save.
   The app is then at `https://daniyal430.github.io/arch-backoffice/`.
6. **Staff logins** — Authentication → Users → Add user for each staff member. They appear in
   the app under Settings → Users & roles as *Staff*; switch anyone to *Manager* there.
7. **Menu site** — the arch-menu `index.html` already points its staff link at the URL above.

## Roles

| | Staff | Manager |
|---|---|---|
| New order, Orders list | ✔ | ✔ |
| Dashboard, Items, Customers | | ✔ |
| Void an order | | ✔ |
| POS Z-report total, roles | | ✔ |

Enforced by Row Level Security in the database, not only by the screen.

## How a WhatsApp order gets in

Customer taps *Send order on WhatsApp* in the menu → message to 0554312474 ends with a
staff link → staff tap it → the app opens with the order prefilled → add the customer's
number → *Confirm*. Orders logged by phone/voice are entered with *New order*.

## Data

Tables `orders`, `z_totals`, `profiles` in Supabase (Postgres). Export CSV from Settings,
or query with SQL in Supabase. Free tier is enough for a restaurant (500 MB, 50k monthly users).
