Нижче — **підвідні (розігрівальні) завдання** для групового заняття на простій БД `oiaz_train`. Кожне завдання: **мета → що відпрацьовуємо → пояснення логіки → готовий SQL**. Поступово готує до “дорослої” практики, але без перевантаження.

---

## 0) Орієнтація в середовищі

**Мета:** переконатися, що працюємо в потрібній схемі і бачимо таблиці.
**Відпрацьовуємо:** `search_path`, перелік таблиць.

**Пояснення:** у Postgres схема — як “папка”. Якщо не встановити `search_path`, можна випадково звертатись до іншої таблиці з таким самим ім’ям.

```sql
SET search_path = oiaz_train, public;

SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema = 'oiaz_train'
ORDER BY table_name;
```

---

## 1) Перевірка заповнення даних

**Мета:** швидко оцінити “масштаб” даних і часовий діапазон.
**Відпрацьовуємо:** `count`, `min/max`.

**Пояснення:** це перший крок будь-якого аналітика — “скільки даних і за який період”.

```sql
SET search_path = oiaz_train, public;

SELECT 'unit' AS t, count(*) FROM unit
UNION ALL
SELECT 'report', count(*) FROM report
UNION ALL
SELECT 'report_item', count(*) FROM report_item;

SELECT min(report_date) AS min_date, max(report_date) AS max_date
FROM report;
```

---

## 2) Перший фільтр: останні 7 днів

**Мета:** навчитися відбирати “актуальне”.
**Відпрацьовуємо:** `WHERE`, робота з датою.

**Пояснення:** `report_date` — це DATE. Для відбору останніх 7 днів зручно порівнювати з `current_date - 7`.

```sql
SET search_path = oiaz_train, public;

SELECT *
FROM report
WHERE report_date >= current_date - 7
ORDER BY report_date DESC, report_id DESC
LIMIT 50;
```

---

## 3) Сортування і “ТОП”

**Мета:** знайти найкритичніші звіти.
**Відпрацьовуємо:** `ORDER BY`, `LIMIT`.

**Пояснення:** коли даних багато, ми часто шукаємо “крайні” значення: найбільша критичність, найновіші звіти.

```sql
SET search_path = oiaz_train, public;

SELECT report_date, report_type, severity, unit_id
FROM report
ORDER BY severity DESC, report_date DESC
LIMIT 20;
```

---

## 4) Підключення довідника підрозділів (JOIN)

**Мета:** замість `unit_id` бачити `unit_code`.
**Відпрацьовуємо:** `JOIN`.

**Пояснення:** `report.unit_id` — зовнішній ключ (_foreign key_ /ˈfɔːrən kiː/). Він посилається на `unit.unit_id`. JOIN “підтягує” назву.

```sql
SET search_path = oiaz_train, public;

SELECT r.report_date, u.unit_code, r.report_type, r.severity
FROM report r
JOIN unit u ON u.unit_id = r.unit_id
ORDER BY r.report_date DESC
LIMIT 50;
```

---

## 5) Агрегація: скільки звітів на підрозділ

**Мета:** побачити активність підрозділів.
**Відпрацьовуємо:** `GROUP BY`, `COUNT`.

**Пояснення:** групуємо по підрозділу і рахуємо кількість звітів.

```sql
SET search_path = oiaz_train, public;

SELECT u.unit_code, count(*) AS reports_cnt
FROM report r
JOIN unit u ON u.unit_id = r.unit_id
GROUP BY u.unit_code
ORDER BY reports_cnt DESC;
```

---

## 6) Агрегація: середня критичність по підрозділу

**Мета:** оцінити “середній рівень напруги”.
**Відпрацьовуємо:** `AVG`, округлення.

**Пояснення:** `avg(severity)` повертає числове середнє. `round(...,2)` робить результат читабельним.

```sql
SET search_path = oiaz_train, public;

SELECT u.unit_code, round(avg(r.severity)::numeric, 2) AS avg_severity
FROM report r
JOIN unit u ON u.unit_id = r.unit_id
GROUP BY u.unit_code
ORDER BY avg_severity DESC;
```

---

## 7) Перший контакт з метриками (JOIN на третю таблицю)

**Мета:** дістати engagements та enemy_kia.
**Відпрацьовуємо:** JOIN + фільтр по `metric`.

**Пояснення:** `report_item` зберігає “показники”. Один звіт має 2 рядки метрик. Ми фільтруємо потрібну метрику.

```sql
SET search_path = oiaz_train, public;

SELECT r.report_date, u.unit_code, ri.metric, ri.value
FROM report r
JOIN unit u ON u.unit_id = r.unit_id
JOIN report_item ri ON ri.report_id = r.report_id
WHERE r.report_date >= current_date - 7
ORDER BY r.report_date DESC, u.unit_code, ri.metric;
```

---

## 8) Сума engagements за днями

**Мета:** побачити “піки активності” по датах.
**Відпрацьовуємо:** `SUM`, `GROUP BY` по даті.

**Пояснення:** беремо тільки `metric='engagements'`, групуємо по дню.

```sql
SET search_path = oiaz_train, public;

SELECT r.report_date, sum(ri.value) AS engagements_sum
FROM report r
JOIN report_item ri ON ri.report_id = r.report_id
WHERE ri.metric = 'engagements'
GROUP BY r.report_date
ORDER BY r.report_date;
```

---

## 9) “Зріз дня” по підрозділах: engagements + enemy_kia в одному рядку

**Мета:** навчитися робити “широкий” результат з “довгих” метрик.
**Відпрацьовуємо:** умовну агрегацію `CASE WHEN`.

**Пояснення:** в таблиці метрик показники лежать “рядками”. Щоб вивести їх “колонками”, робимо:

- `sum(CASE WHEN metric='engagements' THEN value ELSE 0 END)`.

```sql
SET search_path = oiaz_train, public;

SELECT
  r.report_date,
  u.unit_code,
  sum(CASE WHEN ri.metric='engagements' THEN ri.value ELSE 0 END) AS engagements,
  sum(CASE WHEN ri.metric='enemy_kia'   THEN ri.value ELSE 0 END) AS enemy_kia
FROM report r
JOIN unit u ON u.unit_id = r.unit_id
JOIN report_item ri ON ri.report_id = r.report_id
WHERE r.report_date >= current_date - 7
GROUP BY r.report_date, u.unit_code
ORDER BY r.report_date DESC, u.unit_code;
```

---

## 10) Рейтинг підрозділів за engagements за 30 днів

**Мета:** “хто найактивніший”.
**Відпрацьовуємо:** підсумки + сортування.

**Пояснення:** зводимо engagements за період, сортуємо спадно.

```sql
SET search_path = oiaz_train, public;

SELECT u.unit_code, sum(ri.value) AS engagements_sum
FROM report r
JOIN unit u ON u.unit_id = r.unit_id
JOIN report_item ri ON ri.report_id = r.report_id
WHERE r.report_date >= current_date - 30
  AND ri.metric = 'engagements'
GROUP BY u.unit_code
ORDER BY engagements_sum DESC;
```

---

## 11) Віконні функції “вхід з мінімальним порогом”

**Мета:** показати “місце звіту” в межах підрозділу за severity.
**Відпрацьовуємо:** `ROW_NUMBER() OVER (PARTITION BY ...)`

**Пояснення:** віконні функції рахують “по рядках”, не згортаючи їх у групи.
Тут: для кожного підрозділу нумеруємо звіти від найкритичнішого.

```sql
SET search_path = oiaz_train, public;

SELECT
  r.report_id,
  u.unit_code,
  r.report_date,
  r.severity,
  row_number() OVER (PARTITION BY r.unit_id ORDER BY r.severity DESC, r.report_date DESC) AS rn_in_unit
FROM report r
JOIN unit u ON u.unit_id = r.unit_id
ORDER BY u.unit_code, rn_in_unit
LIMIT 100;
```

---

## 12) “Піковий день” за engagements (одним запитом)

**Мета:** отримати відповідь “який день був найінтенсивніший”.
**Відпрацьовуємо:** агрегація + `ORDER BY` по результату.

**Пояснення:** спершу рахуємо engagements по днях, потім беремо максимум.

```sql
SET search_path = oiaz_train, public;

WITH daily AS (
  SELECT r.report_date, sum(ri.value) AS engagements_sum
  FROM report r
  JOIN report_item ri ON ri.report_id = r.report_id
  WHERE ri.metric = 'engagements'
  GROUP BY r.report_date
)
SELECT *
FROM daily
ORDER BY engagements_sum DESC
LIMIT 1;
```
