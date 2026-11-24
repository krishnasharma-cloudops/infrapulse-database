CREATE TABLE servers (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  hostname text NOT NULL UNIQUE CHECK (length(hostname) BETWEEN 1 AND 120),
  region text NOT NULL DEFAULT 'local',
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE metrics (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  server_id bigint NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  collected_at timestamptz NOT NULL DEFAULT now(),
  cpu double precision NOT NULL CHECK (cpu BETWEEN 0 AND 100),
  memory double precision NOT NULL CHECK (memory BETWEEN 0 AND 100),
  disk double precision NOT NULL CHECK (disk BETWEEN 0 AND 100)
);
CREATE INDEX metrics_server_time_idx ON metrics(server_id, collected_at DESC, id DESC);
CREATE INDEX metrics_time_idx ON metrics(collected_at);
CREATE TABLE alerts (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  server_id bigint NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  metric text NOT NULL CHECK (metric IN ('cpu','memory','disk')),
  value double precision NOT NULL CHECK (value BETWEEN 0 AND 100),
  opened_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  CHECK (resolved_at IS NULL OR resolved_at >= opened_at)
);
CREATE UNIQUE INDEX alerts_one_open_idx ON alerts(server_id, metric) WHERE resolved_at IS NULL;
