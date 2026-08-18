--- migration:up
CREATE TABLE stats_samples (
    sampled_at timestamptz PRIMARY KEY,
    cpu_load double precision NOT NULL,
    ram_load double precision NOT NULL,
    ram_used_bytes bigint NOT NULL,
    ram_total_bytes bigint NOT NULL
);

CREATE INDEX stats_samples_sampled_at_idx
   ON stats_samples (sampled_at);

CREATE TABLE users (
    id INT NOT NULL PRIMARY KEY,
    ip_address inet NOT NULL,
    login_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

--- migration:down
DROP TABLE stats_samples;
DROP TABLE users;
DROP INDEX stats_samples_sampled_at_idx;
--- migration:end
