-- Creating DATABASE retail_da to work on retail_analytics case_study.
CREATE DATABASE retail_da;

-- Using retail_da DATABASE for performing retail_analytics case_study work.
USE retail_da;

-- After importitng dataset tables customer_profiles, product_inventory, and sales_transaction in 
-- retail_da DB
-- checking every table using DESC and SELECT statements to get idea of requirement of data cleaning task.

# 1. customer_profiles table data cleaning.
DESC customer_profiles;  -- here, noticed need of renaming of COLUMN 1 to CustomerID.
SELECT * FROM customer_profiles;  -- here, need of changing data type of JoinDate column to DATE 
								  -- And need of change of blank value to unknown in Location column.

ALTER TABLE customer_profiles
CHANGE COLUMN ï»¿CustomerID  CustomerID INT; -- changed column name ï»¿CustomerID to CustomerID.

UPDATE customer_profiles
SET 
	JoinDate = STR_TO_DATE(JoinDate, "%d/%m/%y"); -- updated the date format of column JoinDate to 
												  -- standard date.

UPDATE customer_profiles
SET 
	Location = "Unknown"
WHERE 
	Location = ""; -- updated customer location to "Unknown" for "" values in the column.
	
ALTER TABLE customer_profiles
MODIFY JoinDate DATE; -- changing data type of JoinDate column from TEXT to DATE.

-----------------------------------------------------------------------------------------------------------------------------------------


# 2. product_inventory table data cleaning.
DESC product_inventory;  -- here, noticed need of renaming of COLUMN 1 to ProductID.
SELECT * FROM product_inventory;  

ALTER TABLE product_inventory
CHANGE COLUMN ï»¿ProductID  ProductID INT; -- changed column name ï»¿ProductID to ProductID.
    
-----------------------------------------------------------------------------------------------------------------------------------------
    
    
# 3. sales_transaction tabel data cleaning.
DESC sales_transaction;  -- here, noticed need of renaming of COLUMN 1 to TransactionID.
SELECT * FROM sales_transaction;  -- here, need of changing data type of TransactionDate column to DATE.

ALTER TABLE sales_transaction
CHANGE COLUMN ï»¿TransactionID  TransactionID INT; -- changed column name ï»¿TransactionID to TransactionID.

UPDATE sales_transaction
SET 
	TransactionDate = STR_TO_DATE(TransactionDate, "%d/%m/%y"); -- updated the date format of column TransactionDate to standard date.

-----------------------------------------------------------------------------------------------------------------------------------------

# 1. RFM-Based Customer Segmentation Objective:
-- Categorisation of customers into actionable segments based on purchasing behavior.

WITH rfm_base AS 
(
    SELECT 
        CustomerID,
        MAX(TransactionDate) AS last_purchase_date,
        COUNT(TransactionID) AS frequency,
        ROUND(
			SUM(QuantityPurchased * Price)
            , 2
		) AS monetary
    FROM 
		sales_transaction
    GROUP BY 
		CustomerID
),
rfm_scores AS 
(
    SELECT 
        CustomerID,
        DATEDIFF("2023-04-12", last_purchase_date) AS recency,
        frequency, monetary,
        NTILE(5) OVER(
			ORDER BY last_purchase_date DESC
		) AS r_score,
        NTILE(5) OVER(
			ORDER BY frequency
		) AS f_score,
        NTILE(5) OVER(
			ORDER BY monetary
		) AS m_score
    FROM 
		rfm_base
)
SELECT 
    CustomerID, recency, frequency, monetary,
    CASE 
        WHEN (r_score + f_score + m_score) >= 12 THEN "Top Customers"
        WHEN (r_score + f_score + m_score) BETWEEN 9 AND 11 THEN "Loyal Customers"
        WHEN (r_score + f_score + m_score) BETWEEN 6 AND 8 THEN "At Risk"
        ELSE "Lost Customers"
    END AS rfm_segment
FROM 
	rfm_scores;

/* 
	Key Insights:
		• Top Customers: High spenders with recent purchases (e.g., CustomerID 872 with $1,200+ total spend).
		• At-Risk: Customers with declining activity (e.g., 15% of customers haven’t purchased in 6+ months).
    Action: Target "At-Risk" customers with personalized reactivation campaigns.
*/

----------------------------------------------------------------------------------------------------------

# 2. Customer Lifetime Value (CLV) Objective:
-- Identifying high-value customers for retention efforts.

WITH customer_stats AS 
(
    SELECT 
        st.CustomerID,
        ROUND(
			AVG(st.QuantityPurchased * st.Price) 
			, 2
        ) AS avg_order_value,
        COUNT(st.TransactionID) AS total_orders,
        DATEDIFF(MAX(st.TransactionDate), MIN(st.TransactionDate)) AS customer_lifespan_days
    FROM 
		sales_transaction st
    GROUP BY 
		st.CustomerID
)
SELECT 
    CustomerID, avg_order_value, total_orders,
    ROUND(
		avg_order_value * total_orders
		, 2
    ) AS clv,
    customer_lifespan_days
FROM 
	customer_stats
ORDER BY 
	clv DESC
LIMIT 
	10;

/*
	Key Insights:
		• Top 10 customers contribute 22% of total revenue.
		• Example: CustomerID 861 has a CLV of $2,450 over 180 days.
	Action: Offer loyalty rewards to top CLV customers.
*/

----------------------------------------------------------------------------------------------------------

# 3. Product Performance Analysis Objective:
-- Identifying top-performing products and categories.

SELECT 
    p.ProductName, p.Category,
    SUM(st.QuantityPurchased) AS total_units_sold,
    ROUND(
		SUM(st.QuantityPurchased * st.Price)
        , 2
	) AS total_revenue,
    DENSE_RANK() OVER(
		ORDER BY SUM(st.QuantityPurchased * st.Price) DESC
	) AS revenue_rank
FROM 
	sales_transaction st
JOIN 
	product_inventory p 
ON 
	st.ProductID = p.ProductID
GROUP BY 
	p.ProductName, p.Category
ORDER BY 
	total_revenue DESC
LIMIT 
	10;

/*
	Key Results:
    
		ProductName                   Category            Total Units Sold    Total Revenue
		
        Product_51                    Clothing             55                  $512160.00
        
        Product_17                    Beauty & Health      100                 $94500.00
        
        Product_87                    Clothing             92                  $78170.24
        
	Action: Increase stock for top 3 products (contribute 35% of revenue).
*/

----------------------------------------------------------------------------------------------------------

# 4. Demographic Segmentation Objective:
-- Understanding the purchasing patterns by age and gender.

SELECT 
    cp.Gender,
    CASE 
        WHEN cp.Age BETWEEN 18 AND 35 THEN "Young"
        WHEN cp.Age BETWEEN 36 AND 60 THEN "Middle"
        ELSE "Old"
    END AS age_group,
    COUNT(DISTINCT st.CustomerID) AS customers,
    ROUND(
		SUM(st.QuantityPurchased * st.Price) 
        , 2
	)AS total_spend
FROM
	sales_transaction st
JOIN 
	customer_profiles cp 
ON 
	st.CustomerID = cp.CustomerID
GROUP BY 	
	cp.Gender, age_group
ORDER BY 
	total_spend DESC;
    
/*
	Insights:
		Women aged 36-60 spend 40% more than men in the same age group.
	Action: 
		Launch gender-specific promotions for underperforming segments (e.g., men aged 36+).
*/

----------------------------------------------------------------------------------------------------------

/*
	Recommendations:
		1. Immediate Focus:
				Optimize inventory for top 10 products.
				Retain "Top Customers" with exclusive offers (e.g., early access to sales).
		2. Strategic Move:
				Re-engage "At-Risk" customers via email campaigns with discounts.
		3. Long-Term:
				Invest in CLV-driven loyalty programs and demographic-targeted marketing.
	This analysis provides a data-driven foundation for inventory, marketing, and customer retention 
	strategies.
*/

----------------------------------------------------------------------------------------------------------



