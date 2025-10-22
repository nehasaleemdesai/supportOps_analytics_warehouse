
\copy stg_orgs FROM '/mnt/data/supportops_staging/stg_orgs.csv' WITH (FORMAT csv, HEADER true);
\copy stg_users FROM '/mnt/data/supportops_staging/stg_users.csv' WITH (FORMAT csv, HEADER true);
\copy stg_articles FROM '/mnt/data/supportops_staging/stg_articles.csv' WITH (FORMAT csv, HEADER true);
\copy stg_releases FROM '/mnt/data/supportops_staging/stg_releases.csv' WITH (FORMAT csv, HEADER true);
\copy stg_tickets FROM '/mnt/data/supportops_staging/stg_tickets.csv' WITH (FORMAT csv, HEADER true);
\copy stg_web_events FROM '/mnt/data/supportops_staging/stg_web_events.csv' WITH (FORMAT csv, HEADER true);
