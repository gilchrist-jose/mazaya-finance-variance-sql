Schema -

CREATE TABLE departments (
    dept_id SERIAL PRIMARY KEY,
    Dept_name VARCHAR(100) NOT NULL
);

CREATE TABLE gl_accounts (
    account_id SERIAL PRIMARY KEY,
    account_code VARCHAR(20)  NOT NULL,
    account_name VARCHAR(100) NOT NULL,
    Account_type VARCHAR(10)  NOT NULL CHECK (account_type IN ('EXPENSE', 'REVENUE'))
);

CREATE TABLE budget (
    budget_id SERIAL PRIMARY KEY,
    dept_id INT NOT NULL REFERENCES departments(dept_id),
    account_id INT NOT NULL REFERENCES gl_accounts(account_id),
    month DATE NOT NULL,
    budget_amount NUMERIC(15, 2) NOT NULL
);

CREATE TABLE actuals (
    actual_id SERIAL PRIMARY KEY,
    dept_id INT NOT NULL REFERENCES departments(dept_id),
    account_id INT NOT NULL REFERENCES gl_accounts(account_id),
    month   DATE    NOT NULL,
    actual_amount   NUMERIC(15, 2) NOT NULL
);


---- this is to categorize the performance of ALL the accounts within a department on a monthly basis ----

SELECT 
	b.dept_id,
	d.dept_name,
	b.account_id,
	g.account_name,
	g.account_type,
	b.month,
	a.actual_amount,
	b.budget_amount,
	(a.actual_amount-b.budget_amount) AS variance,
	ROUND(((a.actual_amount-b.budget_amount)/NULLIF(b.budget_amount,0))*100,2) AS variance_pct,
CASE
	WHEN g.account_type = 'EXPENSE' AND (a.actual_amount-b.budget_amount) > 0 THEN 'OVER BUDGET'
	WHEN g.account_type = 'EXPENSE' AND (a.actual_amount-b.budget_amount) < 0 THEN 'UNDER BUDGET'
	WHEN g.account_type = 'REVENUE' AND (a.actual_amount-b.budget_amount) > 0 THEN 'OVER TARGET'
	WHEN g.account_type = 'REVENUE' AND (a.actual_amount-b.budget_amount) < 0 THEN 'UNDER TARGET'
	ELSE 'ON TARGET'
END	AS status
FROM budget AS b
JOIN actuals AS a
ON b.dept_id = a.dept_id AND b.account_id = a.account_id AND b.month = a.month
	JOIN departments AS d
	ON b.dept_id = d.dept_id
		JOIN gl_account AS g
		ON b.account_id = g.account_id		
ORDER BY variance DESC;


---- this is to categorize the performance of the EXPENSE accounts within a department on a monthly basis ----

SELECT 
	b.dept_id,
	d.dept_name,
	b.account_id,
	g.account_name,
	g.account_type,
	b.month,
	a.actual_amount,
	b.budget_amount,
	(a.actual_amount-b.budget_amount) AS variance,
	ROUND(((a.actual_amount-b.budget_amount)/NULLIF(b.budget_amount,0))*100,2) AS variance_pct,
CASE
	WHEN g.account_type = 'EXPENSE' AND (a.actual_amount-b.budget_amount) > 0 THEN 'OVER BUDGET'
	WHEN g.account_type = 'EXPENSE' AND (a.actual_amount-b.budget_amount) < 0 THEN 'UNDER BUDGET'
	ELSE 'ON BUDGET'
END	AS status
FROM budget AS b
JOIN actuals AS a
ON b.dept_id = a.dept_id AND b.account_id = a.account_id AND b.month = a.month
	JOIN departments AS d
	ON b.dept_id = d.dept_id
		JOIN gl_account AS g
		ON b.account_id = g.account_id
WHERE g.account_type = 'EXPENSE'		
ORDER BY variance DESC;


---- this is to categorize the performance of the EXPENSE accounts within a department on an annual scale ----

SELECT 
	d.dept_name,
	g.account_name,
	SUM(a.actual_amount) AS annual_actual,
	SUM(b.budget_amount) AS annual_budget,
	SUM((a.actual_amount-b.budget_amount)) AS variance,
	ROUND((SUM((a.actual_amount-b.budget_amount))/NULLIF(SUM(b.budget_amount),0))*100,2) AS variance_pct,
CASE
	WHEN SUM((a.actual_amount-b.budget_amount)) > 0 THEN 'OVER BUDGET'
	WHEN SUM((a.actual_amount-b.budget_amount)) < 0 THEN 'UNDER BUDGET'
	ELSE 'ON BUDGET'
END	AS status
FROM budget AS b
JOIN actuals AS a
ON b.dept_id = a.dept_id AND b.account_id = a.account_id AND b.month = a.month
	JOIN departments AS d
	ON b.dept_id = d.dept_id
		JOIN gl_account AS g
		ON b.account_id = g.account_id
WHERE g.account_type = 'EXPENSE'		
GROUP BY d.dept_name, g.account_name
ORDER BY variance_pct DESC;



---- this is to separate the EXPENSE accounts within the departments that are OVER BUDGET BY 5% or more annually ----

SELECT 
	d.dept_name,
	g.account_name,
	SUM(a.actual_amount) AS annual_actual,
	SUM(b.budget_amount) AS annual_budget,
	SUM((a.actual_amount-b.budget_amount)) AS variance,
	ROUND((SUM((a.actual_amount-b.budget_amount))/NULLIF(SUM(b.budget_amount),0))*100,2) AS variance_pct,
CASE
	WHEN SUM((a.actual_amount-b.budget_amount)) > 0 THEN 'OVER BUDGET'
	WHEN SUM((a.actual_amount-b.budget_amount)) < 0 THEN 'UNDER BUDGET'
	ELSE 'ON BUDGET'
END	AS status
FROM budget AS b
JOIN actuals AS a
ON b.dept_id = a.dept_id AND b.account_id = a.account_id AND b.month = a.month
	JOIN departments AS d
	ON b.dept_id = d.dept_id
		JOIN gl_account AS g
		ON b.account_id = g.account_id
WHERE g.account_type = 'EXPENSE'		
GROUP BY d.dept_name, g.account_name
HAVING ROUND((SUM((a.actual_amount-b.budget_amount))/NULLIF(SUM(b.budget_amount),0))*100,2) >= 5
ORDER BY variance DESC;



---- this is to ZOOM IN MONTH WISE on the EXPENSE accounts within the departments that are OVER BUDGET BY 5% or more annually ----

WITH over_budget_accounts AS (
SELECT
	b.dept_id,
	b.account_id
FROM budget AS b
JOIN actuals AS a 
ON b.dept_id = a.dept_id AND b.account_id = a.account_id AND b.month = a.month
	JOIN gl_account AS g
	ON b.account_id = g.account_id
WHERE g.account_type = 'EXPENSE'
GROUP BY b.dept_id, b.account_id
HAVING ROUND((SUM((a.actual_amount-b.budget_amount))/NULLIF(SUM(b.budget_amount),0))*100,2) >= 5
)
SELECT 
	b.dept_id,
	d.dept_name,
	b.account_id,
	g.account_name,
	g.account_type,
	b.month,
	(a.actual_amount - b.budget_amount) AS variance,
	ROUND(((a.actual_amount - b.budget_amount) / NULLIF(b.budget_amount, 0)) * 100, 2) AS variance_pct
FROM budget AS b
JOIN over_budget_accounts AS oba
ON b.dept_id = oba.dept_id AND b.account_id = oba.account_id
	JOIN actuals AS a
	ON b.dept_id = a.dept_id AND b.account_id = a.account_id AND b.month = a.month
		JOIN departments AS d
		ON b.dept_id = d.dept_id
			JOIN gl_account AS g
			ON b.account_id = g.account_id
ORDER BY d.dept_name, b.month;