/*
# [Fix] Create user_role type and Recreate Team Management Functions
This migration fixes an error where the 'public.user_role' type was not defined before being used in database functions. It creates the required ENUM type and safely recreates the functions for team management.

## Query Description: [This operation defines a new data type and recreates several functions to ensure the team management feature works correctly. It is a safe, structural change and does not affect existing data.]

## Metadata:
- Schema-Category: ["Structural"]
- Impact-Level: ["Low"]
- Requires-Backup: [false]
- Reversible: [false]

## Structure Details:
- Creates ENUM type: `public.user_role`
- Recreates function: `public.create_organization_and_assign_admin`
- Recreates function: `public.invite_organization_member`
- Recreates function: `public.update_organization_member_role`
- Recreates function: `public.remove_organization_member`

## Security Implications:
- RLS Status: [No change]
- Policy Changes: [No]
- Auth Requirements: [Functions require authenticated user context]
- Hardens functions against search path attacks by setting `search_path = 'public'`.

## Performance Impact:
- Indexes: [None]
- Triggers: [None]
- Estimated Impact: [Negligible performance impact.]
*/

-- Step 1: Create the user_role ENUM type if it doesn't exist.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
    CREATE TYPE public.user_role AS ENUM ('admin', 'editor', 'viewer');
  END IF;
END$$;

-- Step 2: Recreate organization creation function with security hardening.
DROP FUNCTION IF EXISTS public.create_organization_and_assign_admin(TEXT, TEXT);
CREATE OR REPLACE FUNCTION public.create_organization_and_assign_admin(
  org_name TEXT,
  org_description TEXT
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
  -- Create the organization
  INSERT INTO public.organizations (name, description, created_by)
  VALUES (org_name, org_description, user_id)
  RETURNING id INTO new_org_id;

  -- Assign the creator as an admin
  INSERT INTO public.organization_members (organization_id, user_id, role)
  VALUES (new_org_id, user_id, 'admin');

  RETURN new_org_id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.create_organization_and_assign_admin(TEXT, TEXT) TO authenticated;


-- Step 3: Recreate team management functions with the correct type and security hardening.
DROP FUNCTION IF EXISTS public.invite_organization_member(uuid, text, public.user_role);
CREATE OR REPLACE FUNCTION public.invite_organization_member(
  org_id uuid,
  invitee_email text,
  invitee_role public.user_role
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  invitee_user_id uuid;
  current_user_role public.user_role;
BEGIN
  -- Check if the current user is an admin of the organization
  SELECT role INTO current_user_role
  FROM public.organization_members
  WHERE organization_id = org_id AND user_id = auth.uid();

  IF current_user_role != 'admin' THEN
    RAISE EXCEPTION 'Only admins can invite new members.';
  END IF;

  -- Find the user to invite by email
  SELECT id INTO invitee_user_id FROM auth.users WHERE email = invitee_email;

  IF invitee_user_id IS NULL THEN
    RAISE EXCEPTION 'User with email % not found.', invitee_email;
  END IF;
  
  -- Check if user is already a member
  IF EXISTS (
    SELECT 1 FROM public.organization_members 
    WHERE organization_id = org_id AND user_id = invitee_user_id
  ) THEN
    RAISE EXCEPTION 'User is already a member of this organization.';
  END IF;

  -- Insert the new member
  INSERT INTO public.organization_members (organization_id, user_id, role)
  VALUES (org_id, invitee_user_id, invitee_role);
END;
$$;
GRANT EXECUTE ON FUNCTION public.invite_organization_member(uuid, text, public.user_role) TO authenticated;


DROP FUNCTION IF EXISTS public.update_organization_member_role(uuid, public.user_role);
CREATE OR REPLACE FUNCTION public.update_organization_member_role(
  member_id uuid,
  new_role public.user_role
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  org_id uuid;
  current_user_role public.user_role;
BEGIN
  -- Get organization_id for the member being updated
  SELECT organization_id INTO org_id FROM public.organization_members WHERE id = member_id;

  -- Check if the current user is an admin of that organization
  SELECT role INTO current_user_role
  FROM public.organization_members
  WHERE organization_id = org_id AND user_id = auth.uid();

  IF current_user_role != 'admin' THEN
    RAISE EXCEPTION 'Only admins can update member roles.';
  END IF;

  -- Update the role
  UPDATE public.organization_members
  SET role = new_role
  WHERE id = member_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.update_organization_member_role(uuid, public.user_role) TO authenticated;


DROP FUNCTION IF EXISTS public.remove_organization_member(uuid);
CREATE OR REPLACE FUNCTION public.remove_organization_member(
  member_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  org_id uuid;
  member_user_id uuid;
  current_user_role public.user_role;
BEGIN
  -- Get organization_id and user_id for the member being removed
  SELECT organization_id, user_id INTO org_id, member_user_id FROM public.organization_members WHERE id = member_id;

  -- Check if the current user is an admin of that organization
  SELECT role INTO current_user_role
  FROM public.organization_members
  WHERE organization_id = org_id AND user_id = auth.uid();

  IF current_user_role != 'admin' THEN
    RAISE EXCEPTION 'Only admins can remove members.';
  END IF;

  -- Prevent admin from removing themselves if they are the last admin
  IF (SELECT count(*) FROM public.organization_members WHERE organization_id = org_id AND role = 'admin') = 1 AND member_user_id = auth.uid() THEN
    RAISE EXCEPTION 'You cannot remove yourself as you are the last admin.';
  END IF;

  -- Remove the member
  DELETE FROM public.organization_members
  WHERE id = member_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.remove_organization_member(uuid) TO authenticated;
