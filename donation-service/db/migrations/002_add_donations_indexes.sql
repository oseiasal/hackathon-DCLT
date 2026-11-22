CREATE INDEX IF NOT EXISTS idx_donations_ngo_id ON donations (ngo_id);
CREATE INDEX IF NOT EXISTS idx_donations_created_at ON donations (created_at DESC);
