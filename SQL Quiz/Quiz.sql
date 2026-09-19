-- JOINS
-- Task 1:  List every order with the customer's full name, store name, and the full name of the staff member who handled it.
SELECT o.order_id,
       c.first_name + ' ' + c.last_name AS customer_name,
       s.store_name,
       st.first_name + ' ' + st.last_name AS staff_name
FROM   sales.orders AS o
       INNER JOIN
       sales.customers AS c
       ON o.customer_id = c.customer_id
       INNER JOIN
       sales.stores AS s
       ON o.store_id = s.store_id
       INNER JOIN
       sales.staffs AS st
       ON o.staff_id = st.staff_id;

-- Task 2: Show each product with its brand name and category name. Include products even if they have no brand or category assigned.
SELECT p.product_id,
       p.product_name,
       b.brand_name,
       c.category_name
FROM   production.products AS p
       LEFT OUTER JOIN
       production.brands AS b
       ON p.brand_id = b.brand_id
       LEFT OUTER JOIN
       production.categories AS c
       ON p.category_id = c.category_id;

-- Task 3:  Find all customers who have never placed an order. Return their name, city, and email.
SELECT c.first_name + ' ' + c.last_name AS Customer_name,
       c.city,
       c.email
FROM   sales.customers AS c
       LEFT OUTER JOIN
       sales.orders AS o
       ON c.customer_id = o.customer_id
WHERE  o.order_id IS NULL;

-- GROUP BY
-- Task 4:  Calculate total revenue per store. Revenue = quantity * list_price * (1 - discount). Sort from highest to lowest.
SELECT   s.store_id,
         s.store_name,
         SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_revenue
FROM     sales.stores AS s
         INNER JOIN
         sales.orders AS o
         ON s.store_id = o.store_id
         INNER JOIN
         sales.order_items AS oi
         ON o.order_id = oi.order_id
GROUP BY s.store_id, s.store_name
ORDER BY total_revenue DESC;

-- Task 5:  For each brand, show the number of products, the average list price, and the highest list price. Only include brands with more than 5 products.
SELECT   b.brand_id,
         b.brand_name,
         COUNT(p.product_id) AS product_count,
         AVG(p.list_price) AS average_list_price,
         MAX(p.list_price) AS highest_list_price
FROM     production.brands AS b
         INNER JOIN
         production.products AS p
         ON b.brand_id = p.brand_id
GROUP BY b.brand_id, b.brand_name
HAVING   COUNT(p.product_id) > 5
ORDER BY product_count DESC;

-- Task 6:  Show the number of orders and total revenue per month for the year 2017, ordered chronologically.
SELECT   MONTH(o.order_date) AS order_month,
         COUNT(DISTINCT o.order_id) AS order_count,
         SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_revenue
FROM     sales.orders AS o
         INNER JOIN
         sales.order_items AS oi
         ON o.order_id = oi.order_id
WHERE    YEAR(o.order_date) = 2017
GROUP BY MONTH(o.order_date)
ORDER BY order_month;

-- SUB QUERIES  
-- Task 7:  Find all products priced above the average list price of their own category.
--          Hint: Use a correlated subquery.
SELECT p.product_id,
       p.product_name,
       p.category_id,
       p.list_price
FROM   production.products AS p
WHERE  p.list_price > (SELECT AVG(p2.list_price)
                       FROM   production.products AS p2
                       WHERE  p2.category_id = p.category_id);

-- Task 8:  List the customers who have placed more orders than the average number of orders per customer.
SELECT   c.customer_id,
         c.first_name,
         c.last_name,
         COUNT(o.order_id) AS order_count
FROM     sales.customers AS c
         INNER JOIN
         sales.orders AS o
         ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING   COUNT(o.order_id) > (SELECT AVG(order_count)
                              FROM   (SELECT   customer_id,
                                               COUNT(*) AS order_count
                                      FROM     sales.orders
                                      GROUP BY customer_id) AS customer_orders)
ORDER BY order_count DESC;

-- CTEs (Common Table Expressions)
-- Task 9:  Using a CTE, calculate each customer's total spend, then return the top 10 customers with their spend and rank. Add a second CTE that labels each customer as "High" (above the overall average spend) or "Regular".
WITH     CustomerSpend
AS       (SELECT   c.customer_id,
                   c.first_name,
                   c.last_name,
                   SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_spend
          FROM     sales.customers AS c
                   INNER JOIN
                   sales.orders AS o
                   ON c.customer_id = o.customer_id
                   INNER JOIN
                   sales.order_items AS oi
                   ON o.order_id = oi.order_id
          GROUP BY c.customer_id, c.first_name, c.last_name),
         CustomerLabels
AS       (SELECT customer_id,
                 first_name,
                 last_name,
                 total_spend,
                 CASE WHEN total_spend > (SELECT AVG(total_spend)
                                          FROM   CustomerSpend) THEN 'High' ELSE 'Regular' END AS customer_level
          FROM   CustomerSpend),
         RankedCustomers
AS       (SELECT customer_id,
                 first_name,
                 last_name,
                 total_spend,
                 customer_level,
                 RANK() OVER (ORDER BY total_spend DESC) AS spend_rank
          FROM   CustomerLabels)
SELECT   customer_id,
         first_name,
         last_name,
         total_spend,
         spend_rank,
         customer_level
FROM     RankedCustomers
WHERE    spend_rank <= 10
ORDER BY spend_rank;

-- Task 10:  Using CTEs, find the best-selling product (by quantity) in each category, and show how much of that product's stock is currently available across all stores.
--           Hint: Use ROW_NUMBER() or RANK() partitioned by category, then join to production.stocks.
WITH     ProductSales
AS       (SELECT   p.product_id,
                   p.product_name,
                   p.category_id,
                   SUM(oi.quantity) AS total_quantity_sold
          FROM     production.products AS p
                   INNER JOIN
                   sales.order_items AS oi
                   ON p.product_id = oi.product_id
          GROUP BY p.product_id, p.product_name, p.category_id),
         RankedProducts
AS       (SELECT product_id,
                 product_name,
                 category_id,
                 total_quantity_sold,
                 ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY total_quantity_sold DESC) AS product_rank
          FROM   ProductSales),
         StockTotals
AS       (SELECT   product_id,
                   SUM(quantity) AS total_stock
          FROM     production.stocks
          GROUP BY product_id)
SELECT   c.category_id,
         c.category_name,
         rp.product_id,
         rp.product_name,
         rp.total_quantity_sold,
         COALESCE (st.total_stock, 0) AS total_stock
FROM     RankedProducts AS rp
         INNER JOIN
         production.categories AS c
         ON rp.category_id = c.category_id
         LEFT OUTER JOIN
         StockTotals AS st
         ON rp.product_id = st.product_id
WHERE    rp.product_rank = 1
ORDER BY c.category_id;

-- BONUS CHALLANGES
-- 	Rewrite Q8 using a CTE instead of a subquery and compare readability.
WITH     CustomerOrderCounts
AS       (SELECT   customer_id,
                   COUNT(*) AS order_count
          FROM     sales.orders
          GROUP BY customer_id),
         AverageOrders
AS       (SELECT AVG(order_count) AS avg_order_count
          FROM   CustomerOrderCounts)
SELECT   c.customer_id,
         c.first_name,
         c.last_name,
         coc.order_count
FROM     CustomerOrderCounts AS coc
         INNER JOIN
         sales.customers AS c
         ON coc.customer_id = c.customer_id CROSS JOIN AverageOrders AS ao
WHERE    coc.order_count > ao.avg_order_count
ORDER BY coc.order_count DESC;

--	For Q4, add a column showing each store's percentage share of total company revenue.
WITH     StoreRevenue
AS       (SELECT   s.store_id,
                   s.store_name,
                   SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_revenue
          FROM     sales.stores AS s
                   INNER JOIN
                   sales.orders AS o
                   ON s.store_id = o.store_id
                   INNER JOIN
                   sales.order_items AS oi
                   ON o.order_id = oi.order_id
          GROUP BY s.store_id, s.store_name)
SELECT   store_id,
         store_name,
         total_revenue,
         ROUND(total_revenue * 100.0 / SUM(total_revenue) OVER (), 2) AS revenue_percentage
FROM     StoreRevenue
ORDER BY total_revenue DESC;