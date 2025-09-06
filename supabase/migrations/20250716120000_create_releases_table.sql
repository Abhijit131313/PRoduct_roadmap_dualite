/*
# [Create Releases Table and Add Foreign Key]
This migration creates the `releases` table for managing product release cycles and establishes a foreign key relationship from the `features` table to it.

## Query Description: [This is a non-destructive operation that adds a new `releases` table and a foreign key constraint. It is safe to run on existing databases as it checks for the existence of objects before creating them.]

## Metadata:
- Schema-Category: ["Structural"]
- Impact-Level: ["Low"]
- Requires-Backup: [false]
- Reversible: [true]

## Structure Details:
- Table Created: `releases`
- Table Altered: `features` (adds foreign key `features_release_id_fkey`)

## Security Implications:
- RLS Status: [Enabled on `releases`]
- Policy Changes: [Yes, adds policies for `releases` table]
- Auth Requirements: [Users can manage releases based on their organization role.]

## Performance Impact:
- Indexes: [Added on `roadmap_id`, `status`, `target_date` for the `releases` table]
- Estimated Impact: [Low]
*/

-- 1. Create releases table
CREATE TABLE IF NOT EXISTS public.releases (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    roadmap_id uuid NOT NULL REFERENCES public.roadmaps(id) ON DELETE CASCADE,
    name character varying NOT NULL,
    description text,
    status character varying DEFAULT 'planned'::character varying NOT NULL,
    target_date timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid REFERENCES auth.users(id)
);

-- 2. Add indexes for performance
CREATE INDEX IF NOT EXISTS releases_roadmap_id_idx ON public.releases(roadmap_id);
CREATE INDEX IF NOT EXISTS releases_status_idx ON public.releases(status);
CREATE INDEX IF NOT EXISTS releases_target_date_idx ON public.releases(target_date);

-- 3. Add foreign key from features to releases if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'features_release_id_fkey' AND conrelid = 'public.features'::regclass
  ) THEN
    ALTER TABLE public.features
    ADD CONSTRAINT features_release_id_fkey
    FOREIGN KEY (release_id)
    REFERENCES public.releases(id)
    ON DELETE SET NULL;
  END IF;
END;
$$;

-- 4. Enable RLS on releases table
ALTER TABLE public.releases ENABLE ROW LEVEL SECURITY;

-- 5. Create RLS policies for releases
DROP POLICY IF EXISTS "Allow members to view releases" ON public.releases;
CREATE POLICY "Allow members to view releases"
ON public.releases
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.roadmaps r
    JOIN public.projects p ON r.project_id = p.id
    JOIN public.organization_members om ON p.organization_id = om.organization_id
    WHERE r.id = releases.roadmap_id AND om.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Allow editors and admins to create releases" ON public.releases;
CREATE POLICY "Allow editors and admins to create releases"
ON public.releases
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.roadmaps r
    JOIN public.projects p ON r.project_id = p.id
    JOIN public.organization_members om ON p.organization_id = om.organization_id
    WHERE r.id = releases.roadmap_id
      AND om.user_id = auth.uid()
      AND (om.role = 'admin' OR om.role = 'editor')
  )
);

DROP POLICY IF EXISTS "Allow editors and admins to update releases" ON public.releases;
CREATE POLICY "Allow editors and admins to update releases"
ON public.releases
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.roadmaps r
    JOIN public.projects p ON r.project_id = p.id
    JOIN public.organization_members om ON p.organization_id = om.organization_id
    WHERE r.id = releases.roadmap_id
      AND om.user_id = auth.uid()
      AND (om.role = 'admin' OR om.role = 'editor')
  )
);

DROP POLICY IF EXISTS "Allow admins to delete releases" ON public.releases;
CREATE POLICY "Allow admins to delete releases"
ON public.releases
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.roadmaps r
    JOIN public.projects p ON r.project_id = p.id
    JOIN public.organization_members om ON p.organization_id = om.organization_id
    WHERE r.id = releases.roadmap_id
      AND om.user_id = auth.uid()
      AND om.role = 'admin'
  )
);
