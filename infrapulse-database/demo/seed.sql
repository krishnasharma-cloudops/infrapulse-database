BEGIN;
INSERT INTO servers(hostname,region) VALUES ('demo-web-01','eastus'),('demo-api-01','eastus'),('demo-db-01','centralindia') ON CONFLICT DO NOTHING;
INSERT INTO metrics(server_id,collected_at,cpu,memory,disk)
SELECT s.id, now()-i*interval '5 minutes',
round((CASE WHEN s.hostname='demo-db-01' THEN 86 ELSE 37 END + 8*sin(i*0.4+s.id))::numeric,1),
round((55+12*cos(i*0.3+s.id))::numeric,1),
CASE WHEN s.hostname='demo-db-01' THEN 91 ELSE 48 END
FROM servers s CROSS JOIN generate_series(0,47) i WHERE s.hostname IN ('demo-web-01','demo-api-01','demo-db-01');
INSERT INTO alerts(server_id,metric,value) SELECT id,'disk',91 FROM servers WHERE hostname='demo-db-01' ON CONFLICT DO NOTHING;
COMMIT;
