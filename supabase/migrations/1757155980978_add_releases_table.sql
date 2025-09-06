/*
# Add Releases Table for Release Management

This migration adds the releases table to support release planning and management functionality in the roadmap application.

## Query Description: 
This operation adds a new table for managing product releases. This is a safe additive change that does not affect existing data or functionality.

## Metadata:
- Schema-Category: "Safe"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- New table: releases
- Columns: id, roadmap_id, name, description, version, target_date, actual_date, status, created_at, updated_at, created_by
- Foreign key relationship with roadmaps table
- RLS policies for organization-based access

## Security Implications:
- RLS Status: Enabled
- Policy Changes: Yes (new policies for releases table)
- Auth Requirements: User must be member of organization that owns the roadmap

## Performance Impact:
- Indexes: Added on roadmap_id and target_date for query performance
- Triggers: None
- Estimated Impact: Minimal - new table with proper indexing
*/

-- Create releases table
CREATE TABLE IF NOT EXISTS releases (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  roadmap_id UUID NOT NULL REFERENCES roadmaps(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  version VARCHAR(50),
  target_date DATE,
  actual_date DATE,
  status VARCHAR(50) DEFAULT 'planned' CHECK (status IN ('planned', 'in_progress', 'released', 'cancelled')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  created_by UUID REFERENCES auth.users(id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_releases_roadmap_id ON releases(roadmap_id);
CREATE INDEX IF NOT EXISTS idx_releases_target_date ON releases(target_date);
CREATE INDEX IF NOT EXISTS idx_releases_status ON releases(status);

-- Enable RLS
ALTER TABLE releases ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for releases
CREATE POLICY "Users can view releases in their organization roadmaps" ON releases
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM roadmaps r
      JOIN projects p ON r.project_id = p.id
      JOIN organization_members om ON p.organization_id = om.organization_id
      WHERE r.id = releases.roadmap_id
      AND om.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert releases in their organization roadmaps" ON releases
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM roadmaps r
      JOIN projects p ON r.project_id = p.id
      JOIN organization_members om ON p.organization_id = om.organization_id
      WHERE r.id = releases.roadmap_id
      AND om.user_id = auth.uid()
      AND om.role IN ('admin', 'editor')
    )
  );

CREATE POLICY "Users can update releases in their organization roadmaps" ON releases
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM roadmaps r
      JOIN projects p ON r.project_id = p.id
      JOIN organization_members om ON p.organization_id = om.organization_id
      WHERE r.id = releases.roadmap_id
      AND om.user_id = auth.uid()
      AND om.role IN ('admin', 'editor')
    )
  );

CREATE POLICY "Users can delete releases in their organization roadmaps" ON releases
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM roadmaps r
      JOIN projects p ON r.project_id = p.id
      JOIN organization_members om ON p.organization_id = om.organization_id
      WHERE r.id = releases.roadmap_id
      AND om.user_id = auth.uid()
      AND om.role IN ('admin', 'editor')
    )
  );

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for releases table
DROP TRIGGER IF EXISTS update_releases_updated_at ON releases;
CREATE TRIGGER update_releases_updated_at
    BEFORE UPDATE ON releases
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
