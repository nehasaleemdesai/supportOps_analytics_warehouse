// creating new dimension table, by cleaning and taking data from existing table

SELECT * FROM stg_orgs;
DROP TABLE IF EXISTS dim_org;
CREATE TABLE dim_org AS
SELECT DISTINCT ON(org_id)
	org_id,
	TRIM(org_name) AS org_name,
	INITCAP(TRIM(industry)) AS industry,
	CASE LOWER(plan)
		WHEN 'free' THEN 'Free'
		WHEN 'standard' THEN 'Standard'
		WHEN 'pro' THEN 'Pro'
		WHEN 'enterprise' THEN 'Enterprise'
		ELSE 'Unknown'
	END AS plan,
	UPPER(TRIM(country)) AS country
FROM stg_orgs
ORDER BY org_id, updated_at DESC NULLS LAST;

// CREATING USER DIMENSION TABLE
SELECT * FROM stg_users;

DROP TABLE IF EXISTS dim_user;
CREATE TABLE dim_user AS
SELECT DISTINCT ON (user_id)
	user_id,
	INITCAP(TRIM(full_name)) AS full_name,
	CASE WHEN LOWER(TRIM(role)) IN ('agent', 'requester')
		 THEN LOWER(TRIM(role)) 
		 ELSE 'unknown'
		 END AS role,
	LOWER(TRIM(email)) AS email,
	org_id,
	UPPER(TRIM(region)) AS region
FROM stg_users
WHERE org_id IN (SELECT org_id FROM dim_org)
ORDER BY user_id,
		COALESCE(updated_at, created_at) DESC NULLS LAST;