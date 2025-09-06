/*
          # [Definitive Fix for Organization Creation]
          This migration completely resets and correctly configures the database function and Row Level Security (RLS) policies for creating and managing organizations. It resolves persistent errors preventing users from creating new organizations.

          ## Query Description: [This operation will drop and recreate several security policies and a database function. It is designed to be a safe, definitive fix for a recurring permission issue. There is no risk of data loss for existing organizations, but it will correct the creation process for new ones.]
          
          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Medium"
          - Requires-Backup: false
          - Reversible: false
          
          ## Structure Details:
          - Drops and recreates the `create_organization_and_assign_admin` function.
          - Drops and recreates all RLS policies on `public.organizations` and `public.organization_members`.
          
          ## Security Implications:
          - RLS Status: Enabled
          - Policy Changes: Yes
          - Auth Requirements: This fix ensures that authenticated users can create organizations and that only authorized members can access or manage them.
          
          ## Performance Impact:
          - Indexes: None
          - Triggers: None
          - Estimated Impact: Low. This change affects security rules, not query performance.
          */

-- Step 1: Drop existing (potentially faulty) policies and function to ensure a clean slate.
DROP POLICY IF EXISTS "Allow authenticated users to create organizations" ON public.organizations;
DROP POLICY IF EXISTS "Allow members to view their organizations" ON public.organizations;
DROP POLICY IF EXISTS "Allow admins to update their organizations" ON public.organizations;
DROP POLICY IF EXISTS "Allow admins to delete their organizations" ON public.organizations;

DROP POLICY IF EXISTS "Allow members to view other members of their org" ON public.organization_members;
DROP POLICY IF EXISTS "Allow admins to add new members" ON public.organization_members;
DROP POLICY IF EXISTS "Allow admins to update member roles" ON public.organization_members;
DROP POLICY IF EXISTS "Allow admins to remove members" ON public.organization_members;

DROP FUNCTION IF EXISTS public.create_organization_and_assign_admin(text, text);

-- Step 2: Recreate the function to create an organization and assign the creator as admin.
-- This function runs with the permissions of the user who created it, bypassing RLS for this specific, safe operation.
CREATE OR REPLACE FUNCTION public.create_organization_and_assign_admin(
  org_name text,
  org_description text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_org_id uuid;
  user_id uuid := auth.uid();
BEGIN
  -- Insert the new organization
  INSERT INTO public.organizations (name, description, created_by)
  VALUES (org_name, org_description, user_id)
  RETURNING id INTO new_org_id;

  -- Assign the creator as an admin of the new organization
  INSERT INTO public.organization_members (organization_id, user_id, role)
  VALUES (new_org_id, user_id, 'admin');

  RETURN new_org_id;
END;
$$;

-- Step 3: Re-create all RLS policies with correct logic and explicit type casting.

-- Policies for 'organizations' table
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow members to view their organizations"
ON public.organizations
FOR SELECT
USING (is_org_member(id, auth.uid()));

CREATE POLICY "Disallow direct organization creation"
ON public.organizations
FOR INSERT
WITH CHECK (false); -- Force creation through the RPC function

CREATE POLICY "Allow admins to update their organizations"
ON public.organizations
FOR UPDATE
USING (is_org_member(id, auth.uid(), 'admin'::public.user_role))
WITH CHECK (is_org_member(id, auth.uid(), 'admin'::public.user_role));

CREATE POLICY "Allow admins to delete their organizations"
ON public.organizations
FOR DELETE
USING (is_org_member(id, auth.uid(), 'admin'::public.user_role));

-- Policies for 'organization_members' table
ALTER TABLE public.organization_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow members to view other members of their org"
ON public.organization_members
FOR SELECT
USING (is_org_member(organization_id, auth.uid()));

CREATE POLICY "Allow admins to add new members"
ON public.organization_members
FOR INSERT
WITH CHECK (is_org_member(organization_id, auth.uid(), 'admin'::public.user_role));

CREATE POLICY "Allow admins to update member roles"
ON public.organization_members
FOR UPDATE
USING (is_org_member(organization_id, auth.uid(), 'admin'::public.user_role))
WITH CHECK (is_org_member(organization_id, auth.uid(), 'admin'::public.user_role));

CREATE POLICY "Allow admins to remove members"
ON public.organization_members
FOR DELETE
USING (is_org_member(organization_id, auth.uid(), 'admin'::public.user_role));
