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

--- migration:down
DROP TABLE stats_samples;
DROP TABLE users;
--- migration:end
