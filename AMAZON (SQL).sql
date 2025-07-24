-- OBJECTIVES 
-- 14.	Identify the top 5 most valuable customers using a composite score that combines three key metrics: (SQL)
-- a.	Total Revenue (50% weight): The total amount of money spent by the customer.
-- b.	Order Frequency (30% weight): The number of orders placed by the customer, indicating their loyalty and engagement.
-- c.	Average Order Value (20% weight): The average value of each order placed by the customer, reflecting the typical transaction size.

WITH CustomerMetrics AS (
    SELECT 
        CustomerID,
        SUM(SalePrice) AS Total_Revenue,
        COUNT(OrderID) AS Order_Frequency,
        COALESCE(AVG(SalePrice), 0) AS Avg_Order_Value
    FROM Orders
    GROUP BY CustomerID
),
CustomerRanks AS (
    SELECT 
        CustomerID,
        -- Assign Ranks (Higher Values Get Higher Ranks)
        RANK() OVER (ORDER BY Total_Revenue DESC) AS Revenue_Rank,
        RANK() OVER (ORDER BY Order_Frequency DESC) AS Frequency_Rank,
        RANK() OVER (ORDER BY Avg_Order_Value DESC) AS AOV_Rank,

        -- Get Maximum Ranks for Normalization
        COUNT(*) OVER () AS Max_Rank
    FROM CustomerMetrics
)
SELECT 
    CustomerID,
    -- Normalize ranks between 0 and 1
    (
        (Revenue_Rank * 1.0 / Max_Rank) * 0.5 + 
        (Frequency_Rank * 1.0 / Max_Rank) * 0.3 + 
        (AOV_Rank * 1.0 / Max_Rank) * 0.2
    ) AS Composite_Score
FROM CustomerRanks
ORDER BY Composite_Score DESC
LIMIT 5;

-- 15.	Calculate the month-over-month growth rate in total revenue across the entire dataset. (SQL)

WITH MonthlyRevenue AS (
SELECT
DATE_FORMAT(OrderDate, '%Y-%m') AS MonthYear, 
SUM(SalePrice) AS TotalRevenue
FROM Orders
GROUP BY DATE_FORMAT(OrderDate, '%Y-%m')
),
RevenueWithLag AS (
SELECT MonthYear, TotalRevenue,
LAG(TotalRevenue) OVER (ORDER BY MonthYear) AS PrevMonthRevenue
FROM MonthlyRevenue
)
SELECT
MonthYear, TotalRevenue, PrevMonthRevenue,
ROUND(((TotalRevenue - PrevMonthRevenue) / NULLIF(PrevMonthRevenue, 0)) * 100, 2) AS MoM_Growth_Percentage
FROM RevenueWithLag
ORDER BY MonthYear;

-- 16.	Calculate the rolling 3-month average revenue for each product category. (SQL) 

WITH MonthlyCategoryRevenue AS (
SELECT DATE_FORMAT(OrderDate, '%Y-%m') AS MonthYear,
ProductCategory, SUM(SalePrice) AS TotalRevenue
FROM Orders
GROUP BY DATE_FORMAT(OrderDate, '%Y-%m'), ProductCategory
),
RollingRevenue AS (
SELECT MonthYear, ProductCategory,TotalRevenue,
ROUND(AVG(TotalRevenue) OVER (PARTITION BY ProductCategory ORDER BY MonthYear ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS Rolling3MonthAvg
FROM MonthlyCategoryRevenue
)
SELECT MonthYear,ProductCategory,TotalRevenue,Rolling3MonthAvg
FROM RollingRevenue
ORDER BY ProductCategory, MonthYear;

-- 17.	Update the orders table to apply a 15% discount on the `Sale Price` for orders placed by customers who have made at least 10 orders. (SQL)

UPDATE Orders
JOIN (
    SELECT o.OrderID
    FROM Orders o
    JOIN (
        SELECT CustomerID
        FROM Orders
        GROUP BY CustomerID
        HAVING COUNT(OrderID) >= 10
    ) fc ON o.CustomerID = fc.CustomerID
) AS EligibleOrders ON Orders.OrderID = EligibleOrders.OrderID
SET Orders.SalePrice = Orders.SalePrice * 0.85;

-- 18.	Calculate the average number of days between consecutive orders for customers who have placed at least five orders. (SQL)

WITH CustomerOrders AS (
SELECT CustomerID, OrderID, OrderDate,
LAG(OrderDate) OVER (PARTITION BY CustomerID ORDER BY OrderDate) AS PrevOrderDate
FROM Orders
),
OrderDifferences AS (
SELECT CustomerID,
DATEDIFF(OrderDate, PrevOrderDate) AS DaysBetweenOrders
FROM CustomerOrders
WHERE PrevOrderDate IS NOT NULL
),
FrequentCustomers AS (
SELECT CustomerID
FROM Orders
GROUP BY CustomerID
HAVING COUNT(OrderID) >= 5
)
SELECT
o.CustomerID,
ROUND(AVG(o.DaysBetweenOrders), 2) AS AvgDaysBetweenOrders
FROM OrderDifferences o
JOIN FrequentCustomers fc ON o.CustomerID = fc.CustomerID
GROUP BY o.CustomerID
ORDER BY AvgDaysBetweenOrders ASC;

-- 19.	Identify customers who have generated revenue that is more than 30% higher than the average revenue per customer. (SQL)

WITH CustomerRevenue AS (
SELECT CustomerID, SUM(SalePrice) AS TotalRevenue
FROM Orders
GROUP BY CustomerID
),
AvgRevenue AS (
SELECT AVG(TotalRevenue) AS AvgRevenuePerCustomer
FROM CustomerRevenue
)
SELECT cr.CustomerID, cr.TotalRevenue, a.AvgRevenuePerCustomer,
ROUND(((cr.TotalRevenue - a.AvgRevenuePerCustomer) / a.AvgRevenuePerCustomer) * 100, 2) AS RevenueIncreasePercentage
FROM CustomerRevenue cr
JOIN AvgRevenue a ON 1=1
WHERE cr.TotalRevenue > a.AvgRevenuePerCustomer * 1.3
ORDER BY cr.TotalRevenue DESC;

-- 20.	Determine the top 3 product categories that have shown the highest increase in sales over the past year compared to the previous year. (SQL)

WITH YearlySales AS (
SELECT ProductCategory, YEAR(OrderDate) AS OrderYear,
SUM(SalePrice) AS TotalRevenue
FROM Orders
GROUP BY ProductCategory, YEAR(OrderDate)
),
SalesGrowth AS (
SELECT y1.ProductCategory, y1.OrderYear AS CurrentYear,
y1.TotalRevenue AS CurrentYearRevenue, 
y2.TotalRevenue AS PreviousYearRevenue,
ROUND(((y1.TotalRevenue - y2.TotalRevenue) / NULLIF(y2.TotalRevenue, 0)) * 100, 2) AS RevenueGrowthPercentage
FROM YearlySales y1
LEFT JOIN YearlySales y2
ON y1.ProductCategory = y2.ProductCategory AND y1.OrderYear = y2.OrderYear + 1
)
SELECT ProductCategory, CurrentYear, CurrentYearRevenue, PreviousYearRevenue, RevenueGrowthPercentage
FROM SalesGrowth
ORDER BY RevenueGrowthPercentage DESC
LIMIT 3;










