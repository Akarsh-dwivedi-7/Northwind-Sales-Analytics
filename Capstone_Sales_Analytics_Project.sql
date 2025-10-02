Create Database Capstone;
use Capstone;

Select * from Categories;
Select * from Customers;
Select * from employees_ready_for_sql;
Select * from order_details;
Select * from orders;
Select * from Products;
Select * from shippers;
Select * from suppliers;

-- What is the average number of orders per customer? Are there high-value repeat customers?
select
count(distinct OrderID) * 1.0 / count(distinct CustomerID) as avg_orders_per_customer
from orders;
select o.CustomerID,
count(o.OrderID) as total_orders,
sum(od.UnitPrice * od.Quantity - od.Discount) as total_spent,
avg(od.UnitPrice * od.Quantity - od.Discount) as avg_order_value
from orders o
join order_details od on o.OrderID = od.OrderID
group by o.CustomerID
having count(o.OrderID) > 1 and sum(od.UnitPrice * od.Quantity - od.Discount) > 1000
order by total_spent desc
limit 10;

-- How do customer order patterns vary by city or country?
select o.ShipCountry,
count( distinct o.CustomerID) as num_customers,
count(Distinct o.OrderID) as total_orders,
sum(od.UnitPrice * od.Quantity) as total_spent,
sum(od.UnitPrice * od.Quantity) / count(Distinct o.OrderID) as avg_order_value
from orders o
join order_details od on o.OrderID = od.OrderId
group by o.ShipCountry
order by total_spent desc;

-- Can we cluster customers based on total spend, order count, and preferred categories?
with CustomerSpend as
(select o.CustomerID,
sum(od.UnitPrice * od.Quantity) as total_spent
from orders o
 join order_details od on o.OrderID = od.OrderID
group by o.CustomerID),
CustomerOrderCount as(
select CustomerID,
count(OrderID) as order_count
from orders
group by CustomerID
),
CategorySpendPerCustomer as (
select o.CustomerID,
c.CategoryName,
sum(od.UnitPrice * od.Quantity) as CategoryTotalSpent
from orders o
join order_details od on o.OrderID = od.OrderId
join products p on od.ProductID = p.ProductID
join categories c on p.CategoryID = c.CategoryID
group by o.CustomerID,
c.CategoryName
),
RankedCategorySpend as (
select CustomerID,
CategoryName,
CategoryTotalSpent,
row_number() over(partition by CustomerID order by CategoryTotalSpent desc) as rn
from CategorySpendPerCustomer
)
select cs.CustomerID,
cs.total_spent,
coc.order_count,
rcs.CategoryName as PreferredCategory
from CustomerSpend as cs
join CustomerOrderCount as coc on cs.CustomerID = coc.CustomerId
left join RankedCategorySpend rcs on cs.CustomerID = rcs.CustomerID and rcs.rn = 1
order by cs.CustomerID asc;

-- Which product categories or products contribute most to order revenue? 
select p.ProductID,
p.ProductName,
c.CategoryName,
sum(od.UnitPrice * od.Quantity - od.Discount) as order_revenue
from order_details od
join products p on od.ProductID = p.ProductID
join categories c on p.CategoryID = c.CategoryID
group by p.ProductID,p.ProductName,c.CategoryName
order by order_revenue desc;

 -- Are there any correlations between orders and customer location or product category?
select ShipCountry,
ShipCity,
count(OrderID) as total_orders
from orders
group by ShipCountry,ShipCity
order by total_orders desc;

-- How frequently do different customer segments place orders?
select ShipVia,
count(OrderID) as total_order
from orders
group by ShipVia
order by total_order desc;

select
 extract(month from OrderDate) as order_month,
count(OrderID) as total_order
from orders
group by order_month
order by order_month;

select ShipVia,
extract(month from OrderDate) as order_month,
count(OrderID) as total_order,
count(distinct CustomerID) as unique_customer,
round(count(OrderID) * 1.0 / count(distinct CustomerID),2) as avg_orders_per_customer
from orders
group by ShipVia,order_month
order by total_order desc;

-- What is the geographic and title-wise distribution of employees?
select Country,
City,
Title,
count(EmployeeID) as count_employee
from employees
group by Country,City,Title
order by count_employee desc;

-- What trends can we observe in hire dates across employee titles?
select
Title,
extract(year from HireDate) as hire_year,
count(*) as hires
from employees
group by hire_year,Title
order by hire_year,Title;

-- What patterns exist in employee title and courtesy title distributions?
SELECT    Title,   
TitleOfCourtesy,  
 COUNT(*) AS count_of_employees
FROM    employees
GROUP BY    Title, TitleOfCourtesy
ORDER BY    Title, count_of_employees DESC;

-- Are there correlations between product pricing, stock levels, and sales performance?
select p.ProductName,
p.UnitPrice,
p.UnitsInStock,
round(sum(od.UnitPrice * od.Quantity - od.Discount),2) as TotalSales,
round(sum(od.Quantity),2) as TotalUnitsSold
from products p join order_details od on p.ProductID = od.ProductID
group by p.ProductName,p.UnitPrice,p.UnitsInStock
order by TotalSales desc;

-- How does product demand change over months or seasons?
select od.ProductID,
extract(month from o.OrderDate) as order_month,
sum(od.Quantity) as total_quantity
from order_details od
join orders o on od.OrderID = o.OrderID
group by od.ProductID,
extract(month from o.OrderDate)
order by od.ProductID,order_month;

-- Can we identify anomalies in product sales or revenue performance?
with stats as(
select ProductID,
sum(UnitPrice * Quantity) as revenue,
avg(UnitPrice * Quantity) as avg_revenue,
stddev(UnitPrice * Quantity) as stddev_revenue
from order_details
group by ProductID
)
select o.OrderDate,
od.ProductID,
s.revenue,
s.avg_revenue,
s.stddev_revenue,
case    
when s.revenue > s.avg_revenue + 2 * s.stddev_revenue then 'High Revenue' when s.revenue < s.avg_revenue - 2 * s.stddev_revenue then 'Low Revenue' else 'Normal'
end as anomaly_status
from orders o
join order_details od on o.OrderID = od.OrderID
 join stats s on od.ProductID = s.ProductID
order by s.ProductID,o.OrderDate;

-- Are there any regional trends in supplier distribution and pricing?
with SupplierCounts as(
select Country,
count(*) as NumSupplier
from suppliers
 group by Country
),
PricingbyCountry as(
select s.Country,
round(avg(p.UnitPrice),2) as AvgProductPrice
from products p
join suppliers s on p.SupplierID = s.SupplierID
group by s.Country
)
select
sc.Country,
sc.NumSupplier,
pc.AvgProductPrice
from SupplierCounts sc
join PricingByCountry pc on sc.Country = pc.Country
order by pc.AvgProductPrice desc;

-- How are suppliers distributed across different product categories?
select  s.Country,
c.CategoryName,
round(avg(p.UnitPrice),2) as avg_price,
count(p.ProductID) as NumProducts
from suppliers s
join products p on s.SupplierID = p.SupplierID
join categories c on p.CategoryID = c.CategoryID
group by s.Country,c.CategoryName
order by s.Country,avg_price desc;

-- How do supplier pricing and categories relate across different regions?
select  s.Country,
c.CategoryName,
round(avg(p.UnitPrice),2) as avg_price,count(p.ProductID) as NumProducts from suppliers s
join products p on s.SupplierID = p.SupplierID
join categories c on p.CategoryID = c.CategoryID
group by s.Country,c.CategoryName
order by s.Country,avg_price desc;














