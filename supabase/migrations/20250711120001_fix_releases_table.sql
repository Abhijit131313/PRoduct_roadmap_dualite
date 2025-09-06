/*
# [Fix] Correct Releases Table Schema
This migration script corrects the schema for the `releases` table, which was missing the `target_date` column in a previous version. It safely drops the existing table if it exists and recreates it with the correct structure and policies.

## Query Description:
- **DROP TABLE public.releases**: This will remove the existing `releases` table and any dependent objects. This is necessary to ensure a clean state, but it will delete any data currently in the `releases`table. Since the table was created incorrectly, it's unlikely to hold valuable data.
- **CREATE TABLE public.releases**: This recreates the table with all required columns, including `target_date`.
- **Row Level Security**: Enables RLS and defines policies to ensure users can only access releases within their organization.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "High" (as it drops and recreates a table)
- Requires-Backup: true (Best practice before running any structural change)
- Reversible: false (Data in the old table will be lost)

## Structure Details:
- **Table Dropped**: `public.releases`
- **Table Created**: `public.releases`
- **Columns Added**: `id`, `roadmap_id`, `name`, `description`, `status`, `target_date`, `created_at`, `updated_at`, `created_by`
- **RLS Policies**: `releases_select_policy`, `releases_insert_policy`, `releases_update_policy`, `releases_delete_policy`

## Security Implications:
- RLS Status: Enabled
- Policy Changes: Yes, policies for the `releases` table are created.
- Auth Requirements: Policies are tied to the authenticated user's organization membership.

## Performance Impact:
- Indexes: Primary key and foreign key indexes are created.
- Triggers: None in this script.
- Estimated Impact: Low. Recreating a likely empty table is fast.
*/

-- Drop the existing table to ensure a clean slate, as the previous migration failed.
-- The CASCADE will remove any dependent objects like policies.
DROP TABLE IF EXISTS public.releases CASCADE;

-- Recreate the releases table with the correct schema
CREATE TABLE public.releases (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    roadmap_id uuid NOT NULL,
    name text NOT NULL,
    description text NULL,
    status text NOT NULL DEFAULT 'planned'::text,
    target_date timestamp with time zone NULL, -- The missing column
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    created_by uuid NULL,
    CONSTRAINT releases_pkey PRIMARY KEY (id),
    CONSTRAINT releases_roadmap_id_fkey FOREIGN KEY (roadmap_id) REFERENCES public.roadmaps(id) ON DELETE CASCADE,
    CONSTRAINT releases_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Add comments to the table and columns
COMMENT ON TABLE public.releases IS 'Stores release milestones for a roadmap.';
COMMENT ON COLUMN public.releases.target_date IS 'The planned release date for the milestone.';

-- Enable Row Level Security
ALTER TABLE public.releases ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for the releases table
-- Users can see releases if they are part of the organization that owns the roadmap.
CREATE POLICY "releases_select_policy" ON public.releases
FOR SELECT USING (
  EXISTS (
    SELECT 1
    FROM public.roadmaps r
    JOIN public.projects p ON r.project_id = p.id
    JOIN public.organization_members om ON p.organization_id = om.organization_id
    WHERE r.id = releases.roadmap_id AND om.user_id = auth.uid()
  )
);

-- Users can insert releases if they are an admin or editor in the organization.
CREATE POLICY "releases_insert_policy" ON public.releases
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.roadmaps r
    JOIN public.projects p ON r.project_id = p.id
    JOIN public.organization_members om ON p.organization_id = om.organization_id
    WHERE r.id = releases.roadmap_id AND om.user_id = auth.uid() AND (om.role = 'admin' OR om.role = 'editor')
  )
);

-- Users can update releases if they are an admin or editor in the organization.
CREATE POLICY "releases_update_policy" ON public.releases
FOR UPDATE USING (
  EXISTS (
    SELECT 1
    FROM public.roadmaps r
    JOIN public.projects p ON r.project_id = p.id
    JOIN public.organization_members om ON p.organization_id = om.organization_id
    WHERE r.id = releases.roadmap_id AND om.user_id = auth.uid() AND (om.role = 'admin' OR om.role = 'editor')
  )
);

-- Users can delete releases if they are an admin in the organization.
CREATE POLICY "releases_delete_policy" ON public.releases
FOR DELETE USING (
  EXISTS (
    SELECT 1
    FROM public.roadmaps r
    JOIN public.projects p ON r.project_id = p.id
    JOIN public.organization_members om ON p.organization_id = om.organization_id
    WHERE r.id = releases.roadmap_id AND om.user_id = auth.uid() AND om.role = 'admin'
  )
);
