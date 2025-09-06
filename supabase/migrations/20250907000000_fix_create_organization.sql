/*
          # [Operation Name]
          Definitive Fix for Organization Creation

          ## Query Description: [This migration completely resets and correctly re-implements the database logic for creating organizations. It drops all previous, potentially conflicting policies and functions related to organization creation and rebuilds them from scratch. This ensures that the process is atomic and has the correct permissions, resolving the persistent "unable to add organization" error.]
          
          ## Metadata:
          - Schema-Category: ["Structural", "Security"]
          - Impact-Level: ["Medium"]
          - Requires-Backup: false
          - Reversible: false
          
          ## Structure Details:
          - Drops and recreates the `create_organization_and_assign_admin` function.
          - Drops and recreates RLS policies for `INSERT` on `organizations` and `organization_members`.
          
          ## Security Implications:
          - RLS Status: [Enabled]
          - Policy Changes: [Yes]
          - Auth Requirements: [Authenticated User]
          
          ## Performance Impact:
          - Indexes: [No Change]
          - Triggers: [No Change]
          - Estimated Impact: [Low]
          */

-- Drop existing, potentially faulty, policies and functions to ensure a clean slate.
DROP POLICY IF EXISTS "Authenticated users can create organizations." ON public.organizations;
DROP POLICY IF EXISTS "Admins can add new members." ON public.organization_members;
DROP FUNCTION IF EXISTS public.create_organization_and_assign_admin(text, text);

-- Re-create the function to create an organization and assign the creator as admin.
-- Using SECURITY DEFINER allows this function to bypass RLS policies that would otherwise
-- prevent the initial member from being inserted.
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
  -- Insert the new organization and get its ID
  INSERT INTO public.organizations (name, description, created_by)
  VALUES (org_name, org_description, user_id)
  RETURNING id INTO new_org_id;

  -- Insert the creator as the first member with an 'admin' role
  INSERT INTO public.organization_members (organization_id, user_id, role)
  VALUES (new_org_id, user_id, 'admin');

  RETURN new_org_id;
END;
$$;

-- Grant execute permission on the function to authenticated users.
GRANT EXECUTE ON FUNCTION public.create_organization_and_assign_admin(text, text) TO authenticated;

-- Create a simple policy allowing any authenticated user to insert into the organizations table.
-- The actual creation logic and security is handled by the trusted RPC function above.
CREATE POLICY "Authenticated users can create organizations."
ON public.organizations
FOR INSERT TO authenticated
WITH CHECK (true);

-- Create the policy for adding new members. This is for inviting members later.
-- It requires the user to be an admin of the organization.
-- The initial creation bypasses this check thanks to the SECURITY DEFINER function.
CREATE POLICY "Admins can add new members."
ON public.organization_members
FOR INSERT
WITH CHECK (is_org_member(organization_id, auth.uid(), 'admin'::public.user_role));
