-- ============================================================
-- MIGRATION: Add missing notes column to assets table
-- Run this if you already have a deployed database without notes column
-- ============================================================
ALTER TABLE assets ADD COLUMN IF NOT EXISTS notes TEXT;
