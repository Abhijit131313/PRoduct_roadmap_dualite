/*
          # [Migration] Team Management & Security Hardening
          This migration introduces team management functionality and hardens database security.

          ## Query Description: 
          1.  **Security Hardening**: Alters existing database functions to set a secure `search_path`. This resolves the "Function Search Path Mutable" security warnings by preventing potential unauthorized schema manipulation.
          2.  **Team Management Policies**: Adds new Row Level Security (RLS) policies to the `organization_members` table. These policies empower organization admins to invite, update, and remove team members while restricting these actions from other roles.
          3.  **RPC Functions for Team Management**: Creates new `SECURITY DEFINER` functions (`invite_organization_member`, `update_organization_member_role`, `remove_organization_member`) to securely handle team management operations on the backend. This ensures that all actions are validated against the user's permissions.

          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Medium"
          - Requires-Backup: false
          - Reversible: true

          ## Structure Details:
          - **Alters**: `handle_new_user`, `create_organization_and_assign_admin` functions.
          - **Adds**: RLS policies to `organization_members`.
          - **Adds**: RPC functions `invite_organization_member`, `update_organization_member_role`, `remove_organization_member`.

          ## Security Implications:
          - RLS Status: Policies added/modified.
          - Auth Requirements: Admin role required for new RPC functions.
          - This migration significantly improves the security and functionality of team management within the application.
          */

-- 1. Security Hardening: Set search_path for existing functions
ALTER FUNCTION public.handle_new_user() SET search_path = 'public';
ALTER FUNCTION public.create_organization_and_assign_admin(org_name text, org_description text) SET search_path = 'public';

-- 2. Helper function to check for admin role
CREATE OR REPLACE FUNCTION is_org_admin(org_id uuid, user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM organization_members om
    WHERE om.organization_id = org_id
      AND om.user_id = user_id
      AND om.role = 'admin'
  );
END;
$$;

-- 3. RLS Policies for Team Management
ALTER TABLE public.organization_members ENABLE ROW LEVEL SECURITY;

-- Members can see other members of the same organization
DROP POLICY IF EXISTS "Allow members to view other members" ON public.organization_members;
CREATE POLICY "Allow members to view other members"
ON public.organization_members FOR SELECT
USING (
  organization_id IN (
    SELECT organization_id FROM organization_members WHERE user_id = auth.uid()
  )
);

-- Admins can add new members to their organization
DROP POLICY IF EXISTS "Allow admins to insert new members" ON public.organization_members;
CREATE POLICY "Allow admins to insert new members"
ON public.organization_members FOR INSERT
WITH CHECK ( is_org_admin(organization_id, auth.uid()) );

-- Admins can update roles of members in their organization
DROP POLICY IF EXISTS "Allow admins to update member roles" ON public.organization_members;
CREATE POLICY "Allow admins to update member roles"
ON public.organization_members FOR UPDATE
USING ( is_org_admin(organization_id, auth.uid()) )
WITH CHECK ( is_org_admin(organization_id, auth.uid()) );

-- Admins can remove members from their organization
DROP POLICY IF EXISTS "Allow admins to remove members" ON public.organization_members;
CREATE POLICY "Allow admins to remove members"
ON public.organization_members FOR DELETE
USING ( is_org_admin(organization_id, auth.uid()) );


-- 4. RPC Functions for secure team management

-- Function to invite a user
CREATE OR REPLACE FUNCTION invite_organization_member(
  org_id uuid,
  invitee_email text,
  invitee_role public.user_role
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  invitee_user_id uuid;
  inviter_user_id uuid := auth.uid();
BEGIN
  -- Check if the inviter is an admin of the organization
  IF NOT is_org_admin(org_id, inviter_user_id) THEN
    RAISE EXCEPTION 'Only organization admins can invite new members.';
  END IF;

  -- Find the user by email
  SELECT id INTO invitee_user_id FROM auth.users WHERE email = invitee_email;

  -- If user does not exist, invite them to Supabase Auth
  IF invitee_user_id IS NULL THEN
    RAISE EXCEPTION 'User with email % does not exist. Please ask them to sign up first.', invitee_email;
    -- Note: For a full implementation, you might use `auth.admin.inviteUserByEmail`,
    -- but that requires service_role key and is more complex for this context.
    -- For now, we require users to exist.
  END IF;

  -- Check if user is already a member
  IF EXISTS (SELECT 1 FROM organization_members WHERE organization_id = org_id AND user_id = invitee_user_id) THEN
    RAISE EXCEPTION 'User is already a member of this organization.';
  END IF;

  -- Add user to the organization
  INSERT INTO organization_members (organization_id, user_id, role)
  VALUES (org_id, invitee_user_id, invitee_role);

  RETURN 'Invitation successful.';
END;
$$;


-- Function to update a member's role
CREATE OR REPLACE FUNCTION update_organization_member_role(
  member_id uuid,
  new_role public.user_role
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  org_id uuid;
  inviter_user_id uuid := auth.uid();
BEGIN
  -- Get organization_id from member_id
  SELECT organization_id INTO org_id FROM organization_members WHERE id = member_id;

  -- Check if the updater is an admin
  IF NOT is_org_admin(org_id, inviter_user_id) THEN
    RAISE EXCEPTION 'Only organization admins can update roles.';
  END IF;

  -- Update the role
  UPDATE organization_members
  SET role = new_role
  WHERE id = member_id;
END;
$$;


-- Function to remove a member from an organization
CREATE OR REPLACE FUNCTION remove_organization_member(
  member_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  org_id uuid;
  inviter_user_id uuid := auth.uid();
BEGIN
  -- Get organization_id from member_id
  SELECT organization_id INTO org_id FROM organization_members WHERE id = member_id;

  -- Check if the remover is an admin
  IF NOT is_org_admin(org_id, inviter_user_id) THEN
    RAISE EXCEPTION 'Only organization admins can remove members.';
  END IF;

  -- Remove the member
  DELETE FROM organization_members
  WHERE id = member_id;
END;
$$;
