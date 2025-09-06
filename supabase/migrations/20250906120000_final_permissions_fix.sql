/*
          # [CRITICAL] Complete Reset of Core Access Policies
          This migration completely DROPS and RECREATES all Row Level Security (RLS) policies and the core 'is_org_member' function. This is a definitive fix for the recurring "function does not exist" error caused by incorrect type casting in previous migrations.

          ## Query Description:
          - **IMPACT:** This script will temporarily remove all access controls on projects, roadmaps, initiatives, features, and releases before immediately reapplying them correctly. There is a very brief window during the script's execution where RLS is not active on these tables.
          - **RISK:** Low. The script is designed to be atomic and run within a single transaction. No data will be lost.
          - **REASON:** To fix a persistent bug where database policies were calling a function with the wrong data type signature, causing all permission checks to fail. This reset ensures a clean and correct state.
          
          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "High"
          - Requires-Backup: false
          - Reversible: false
          
          ## Structure Details:
          - **DROPS:** All RLS policies on tables: projects, roadmaps, initiatives, features, releases.
          - **DROPS:** The function 'is_org_member'.
          - **CREATES:** The function 'is_org_member' with the correct signature and logic.
          - **CREATES:** All RLS policies on the above tables with explicit type casting ('viewer'::public.user_role) to resolve the error permanently.
          
          ## Security Implications:
          - RLS Status: Re-enabled and corrected.
          - Policy Changes: Yes, all core policies are reset.
          - Auth Requirements: Fixes auth-related permission checks.
          
          ## Performance Impact:
          - Indexes: None
          - Triggers: None
          - Estimated Impact: Negligible.
          */

-- Step 1: Drop all existing policies that depend on the function to avoid dependency errors.
-- We use IF EXISTS to ensure the script doesn't fail if a policy was already removed.
DROP POLICY IF EXISTS "Members can view projects" ON public.projects;
DROP POLICY IF EXISTS "Editors and Admins can create projects" ON public.projects;
DROP POLICY IF EXISTS "Editors and Admins can update projects" ON public.projects;
DROP POLICY IF EXISTS "Admins can delete projects" ON public.projects;

DROP POLICY IF EXISTS "Members can view roadmaps" ON public.roadmaps;
DROP POLICY IF EXISTS "Editors and Admins can create roadmaps" ON public.roadmaps;
DROP POLICY IF EXISTS "Editors and Admins can update roadmaps" ON public.roadmaps;
DROP POLICY IF EXISTS "Admins can delete roadmaps" ON public.roadmaps;

DROP POLICY IF EXISTS "Members can view initiatives" ON public.initiatives;
DROP POLICY IF EXISTS "Editors and Admins can create initiatives" ON public.initiatives;
DROP POLICY IF EXISTS "Editors and Admins can update initiatives" ON public.initiatives;
DROP POLICY IF EXISTS "Admins can delete initiatives" ON public.initiatives;

DROP POLICY IF EXISTS "Members can view features" ON public.features;
DROP POLICY IF EXISTS "Editors and Admins can create features" ON public.features;
DROP POLICY IF EXISTS "Editors and Admins can update features" ON public.features;
DROP POLICY IF EXISTS "Admins can delete features" ON public.features;

DROP POLICY IF EXISTS "Members can view releases" ON public.releases;
DROP POLICY IF EXISTS "Editors and Admins can create releases" ON public.releases;
DROP POLICY IF EXISTS "Editors and Admins can update releases" ON public.releases;
DROP POLICY IF EXISTS "Admins can delete releases" ON public.releases;

-- Step 2: Drop the problematic function.
DROP FUNCTION IF EXISTS public.is_org_member(uuid, uuid, public.user_role);
DROP FUNCTION IF EXISTS public.is_org_member(uuid, uuid); -- Drop older versions if they exist

-- Step 3: Recreate the function with the correct signature and robust logic.
CREATE OR REPLACE FUNCTION public.is_org_member(
  org_id uuid,
  user_id uuid,
  min_role public.user_role
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_role_level int;
  min_role_level int;
BEGIN
  -- Get the numeric level of the user's role in the specified organization
  SELECT
    CASE role
      WHEN 'viewer' THEN 1
      WHEN 'editor' THEN 2
      WHEN 'admin' THEN 3
      ELSE 0
    END
  INTO user_role_level
  FROM organization_members
  WHERE organization_members.organization_id = org_id
    AND organization_members.user_id = user_id;

  -- If the user is not a member, they have no access.
  IF user_role_level IS NULL THEN
    RETURN FALSE;
  END IF;

  -- Get the numeric level of the minimum role required for the action
  SELECT
    CASE min_role
      WHEN 'viewer' THEN 1
      WHEN 'editor' THEN 2
      WHEN 'admin' THEN 3
      ELSE 0
    END
  INTO min_role_level;

  -- Return true if the user's role level is greater than or equal to the minimum required level
  RETURN user_role_level >= min_role_level;
END;
$$;

-- Step 4: Recreate all policies with explicit type casting. This is the critical fix.

-- Policies for 'projects' table
CREATE POLICY "Members can view projects"
ON public.projects FOR SELECT
USING ( is_org_member(organization_id, auth.uid(), 'viewer'::public.user_role) );

CREATE POLICY "Editors and Admins can create projects"
ON public.projects FOR INSERT
WITH CHECK ( is_org_member(organization_id, auth.uid(), 'editor'::public.user_role) );

CREATE POLICY "Editors and Admins can update projects"
ON public.projects FOR UPDATE
USING ( is_org_member(organization_id, auth.uid(), 'editor'::public.user_role) );

CREATE POLICY "Admins can delete projects"
ON public.projects FOR DELETE
USING ( is_org_member(organization_id, auth.uid(), 'admin'::public.user_role) );

-- Policies for 'roadmaps' table
CREATE POLICY "Members can view roadmaps"
ON public.roadmaps FOR SELECT
USING ( is_org_member(project_id, auth.uid(), 'viewer'::public.user_role) );

CREATE POLICY "Editors and Admins can create roadmaps"
ON public.roadmaps FOR INSERT
WITH CHECK ( is_org_member(project_id, auth.uid(), 'editor'::public.user_role) );

CREATE POLICY "Editors and Admins can update roadmaps"
ON public.roadmaps FOR UPDATE
USING ( is_org_member(project_id, auth.uid(), 'editor'::public.user_role) );

CREATE POLICY "Admins can delete roadmaps"
ON public.roadmaps FOR DELETE
USING ( is_org_member(project_id, auth.uid(), 'admin'::public.user_role) );

-- Policies for 'initiatives' table
CREATE POLICY "Members can view initiatives"
ON public.initiatives FOR SELECT
USING ( is_org_member((SELECT organization_id FROM projects WHERE id = (SELECT project_id FROM roadmaps WHERE id = roadmap_id)), auth.uid(), 'viewer'::public.user_role) );

CREATE POLICY "Editors and Admins can create initiatives"
ON public.initiatives FOR INSERT
WITH CHECK ( is_org_member((SELECT organization_id FROM projects WHERE id = (SELECT project_id FROM roadmaps WHERE id = roadmap_id)), auth.uid(), 'editor'::public.user_role) );

CREATE POLICY "Editors and Admins can update initiatives"
ON public.initiatives FOR UPDATE
USING ( is_org_member((SELECT organization_id FROM projects WHERE id = (SELECT project_id FROM roadmaps WHERE id = roadmap_id)), auth.uid(), 'editor'::public.user_role) );

CREATE POLICY "Admins can delete initiatives"
ON public.initiatives FOR DELETE
USING ( is_org_member((SELECT organization_id FROM projects WHERE id = (SELECT project_id FROM roadmaps WHERE id = roadmap_id)), auth.uid(), 'admin'::public.user_role) );

-- Policies for 'features' table
CREATE POLICY "Members can view features"
ON public.features FOR SELECT
USING ( is_org_member((SELECT organization_id FROM projects WHERE id = (SELECT project_id FROM roadmaps WHERE id = roadmap_id)), auth.uid(), 'viewer'::public.user_role) );

CREATE POLICY "Editors and Admins can create features"
ON public.features FOR INSERT
WITH CHECK ( is_org_member((SELECT organization_id FROM projects WHERE id = (SELECT project_id FROM roadmaps WHERE id = roadmap_id)), auth.uid(), 'editor'::public.user_role) );

CREATE POLICY "Editors and Admins can update features"
ON public.features FOR UPDATE
USING ( is_org_member((SELECT organization_id FROM projects WHERE id = (SELECT project_id FROM roadmaps WHERE id = roadmap_id)), auth.uid(), 'editor'::public.user_role) );

CREATE POLICY "Admins can delete features"
ON public.features FOR DELETE
USING ( is_org_member((SELECT organization_id FROM projects WHERE id = (SELECT project_id FROM roadmaps WHERE id = roadmap_id)), auth.uid(), 'admin'::public.user_role) );

-- Policies for 'releases' table
CREATE POLICY "Members can view releases"
ON public.releases FOR SELECT
USING ( is_org_member((SELECT organization_id FROM projects WHERE id = (SELECT project_id FROM roadmaps WHERE id = roadmap_id)), auth.uid(), 'viewer'::public.user_role) );

CREATE POLICY "Editors and Admins can create releases"
ON public.releases FOR INSERT
WITH CHECK ( is_org_member((SELECT organization_id FROM projects WHERE id = (SELECT project_id FROM roadmaps WHERE id = roadmap_id)), auth.uid(), 'editor'::public.user_role) );

CREATE POLICY "Editors and Admins can update releases"
ON public.releases FOR UPDATE
USING ( is_org_member((SELECT organization_id FROM projects WHERE id = (SELECT project_id FROM roadmaps WHERE id = roadmap_id)), auth.uid(), 'editor'::public.user_role) );

CREATE POLICY "Admins can delete releases"
ON public.releases FOR DELETE
USING ( is_org_member((SELECT organization_id FROM projects WHERE id = (SELECT project_id FROM roadmaps WHERE id = roadmap_id)), auth.uid(), 'admin'::public.user_role) );
