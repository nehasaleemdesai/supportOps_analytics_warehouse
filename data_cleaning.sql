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

// CREATING FACT TABLE THROUGH DATA cleaning

SELECT * FROM stg_tickets;
DROP TABLE IF EXISTS fact_tickets;

CREATE TABLE fact_tickets AS
SELECT DISTINCT ON (ticket_id)
	ticket_id,
	requester_id,
	assignee_id,
	org_id,
	NULLIF(TRIM(subject), ' ') AS subject,
	CASE LOWER(TRIM(status))
		WHEN 'solved' THEN 'solved'
		WHEN 'open' THEN 'open'
		WHEN 'pending' THEN 'pending'
		WHEN 'on_hold' THEN 'on_hold'
		WHEN 'open' THEN 'open'
		ELSE 'open'
		END AS status,
	CASE LOWER(TRIM(priority))
		WHEN 'urgent' THEN 'urgent'
		WHEN 'high' THEN 'high'
		WHEN 'low' THEN 'low'
		ELSE 'normal'
		END AS priority,
	CASE LOWER(TRIM(channel))
		WHEN 'email' THEN 'email'
		WHEN 'chat' THEN 'chat'
		WHEN 'api' THEN 'api'
		ELSE 'web'
		END AS channel,
	REGEXP_SPLIT_TO_ARRAY(LOWER(TRIM(tags)), ';') AS tags,
	created_at,
	GREATEST(first_response_at, created_at) AS  first_response_at,
	CASE 
		WHEN resolved_at IS NOT NULL
		AND resolved_at >= created_at 
		THEN resolved_at
		ELSE NULL
		END AS resolved_at,
	updated_at,
	EXTRACT(EPOCH FROM (GREATEST(first_response_at, created_at) - created_at))::INT
    AS first_response_seconds,
	EXTRACT(EPOCH FROM (
		CASE
			WHEN resolved_at IS NOT NULL
			AND resolved_at >= created_at 
			THEN resolved_at - created_at 
			ELSE NULL END))::INT 
			AS resolution_seconds
FROM stg_tickets
WHERE requester_id IN (SELECT user_id FROM dim_user)
AND assignee_id IN (SELECT user_id FROM dim_user)
AND org_id IN (SELECT org_id FROM dim_org)
ORDER BY ticket_id,
COALESCE(updated_at, resolved_at, first_response_at, created_at)
DESC NULLS LAST;

// QA Checks

-- row count
SELECT COUNT(*) FROM fact_tickets;

-- status/priority/channel distributions
SELECT status,   COUNT(*) FROM fact_tickets GROUP BY 1 ORDER BY 2 DESC;
SELECT priority, COUNT(*) FROM fact_tickets GROUP BY 1 ORDER BY 2 DESC;
SELECT channel,  COUNT(*) FROM fact_tickets GROUP BY 1 ORDER BY 2 DESC;

-- durations sanity
SELECT
  MIN(first_response_seconds) AS min_fr,
  MAX(first_response_seconds) AS max_fr,
  MIN(resolution_seconds)     AS min_res,
  MAX(resolution_seconds)     AS max_res
FROM fact_tickets;

-- date sanity (should be 0)
SELECT COUNT(*) AS bad_dates
FROM fact_tickets
WHERE first_response_at < created_at
   OR (resolved_at IS NOT NULL AND resolved_at < created_at);

-- FK sanity (should be 0)
SELECT COUNT(*) AS bad_requesters
FROM fact_tickets t LEFT JOIN dim_user u ON t.requester_id = u.user_id
WHERE u.user_id IS NULL;

SELECT COUNT(*) AS bad_assignees
FROM fact_tickets t LEFT JOIN dim_user u ON t.assignee_id = u.user_id
WHERE u.user_id IS NULL;

SELECT COUNT(*) AS bad_orgs
FROM fact_tickets t LEFT JOIN dim_org o ON t.org_id = o.org_id
WHERE o.org_id IS NULL;
		