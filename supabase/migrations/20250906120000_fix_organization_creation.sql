/*
          # [Fix] Organization Creation
          This migration fixes the organization creation flow by adding the necessary RLS policies and creating a dedicated RPC function for atomic creation.

          ## Query Description:
          - Adds INSERT policies to `organizations` and `organization_members` tables, allowing authenticated users to create organizations and add themselves as members.
          - Creates a new function `create_organization_and_assign_admin` that transactionally creates an organization and assigns the creator as an admin. This prevents orphaned data if one of the steps fails.
          - This is a non-destructive operation but essential for the application's core functionality to work as intended.

          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Low"
          - Requires-Backup: false
          - Reversible: true (policies and function can be dropped)
          
          ## Structure Details:
          - Tables affected: `public.organizations`, `public.organization_members`
          - Functions created: `public.create_organization_and_assign_admin`
          
          ## Security Implications:
          - RLS Status: Enabled
          - Policy Changes: Yes (Adds INSERT policies)
          - Auth Requirements: Authenticated user
          
          ## Performance Impact:
          - Indexes: None
          - Triggers: None
          - Estimated Impact: Negligible. Improves data integrity.
          */

-- Drop existing policies if they exist to ensure idempotency
DROP POLICY IF EXISTS "Allow authenticated users to create organizations" ON public.organizations;
DROP POLICY IF EXISTS "Allow users to add themselves to organizations" ON public.organization_members;

-- 1. RLS Policy for inserting into organizations
-- Allows any authenticated user to create an organization.
CREATE POLICY "Allow authenticated users to create organizations"
ON public.organizations
FOR INSERT
TO authenticated
WITH CHECK (auth.role() = 'authenticated');

-- 2. RLS Policy for inserting into organization_members
-- Allows a user to insert a membership record for themselves into an organization.
CREATE POLICY "Allow users to add themselves to organizations"
ON public.organization_members
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- 3. Create the RPC function for atomic creation
-- This function creates an organization and assigns the current user as an admin in a single transaction.
CREATE OR REPLACE FUNCTION public.create_organization_and_assign_admin(
    org_name text,
    org_description text
)
RETURNS public.organizations -- Returns the newly created organization record
LANGUAGE plpgsql
SECURITY INVOKER -- Enforces the RLS policies of the user calling the function
AS $$
DECLARE
    new_org public.organizations;
BEGIN
    -- Insert the new organization and return the full row into the 'new_org' variable
    INSERT INTO public.organizations (name, description, created_by)
    VALUES (org_name, org_description, auth.uid())
    RETURNING * INTO new_org;

    -- Insert the creator as an admin member of the new organization
    INSERT INTO public.organization_members (organization_id, user_id, role)
    VALUES (new_org.id, auth.uid(), 'admin');

    -- Return the complete organization record
    RETURN new_org;
END;
$$;
