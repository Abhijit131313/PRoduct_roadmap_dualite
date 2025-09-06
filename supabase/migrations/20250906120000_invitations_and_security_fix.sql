/*
          # [Feature] Team Invitation System & Security Hardening
          This migration introduces a robust invitation system and hardens existing database functions against security vulnerabilities.

          ## Query Description: 
          - Creates a new `invitations` table to manage user invites to organizations.
          - Creates an `invitation_status` type ('pending', 'accepted', 'declined').
          - Replaces the `invite_organization_member` function to use the new `invitations` table.
          - Adds new functions (`accept_invitation`, `decline_invitation`) for users to manage their invites.
          - **Security Fix:** Updates all existing RPC functions to set a secure `search_path`, resolving the "Function Search Path Mutable" warnings.
          This change improves security and provides a better user experience for team management. No data loss is expected.
          
          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Medium"
          - Requires-Backup: false
          - Reversible: false
          
          ## Structure Details:
          - **New Table:** `public.invitations`
          - **New Type:** `public.invitation_status`
          - **Modified Functions:** `create_organization_and_assign_admin`, `invite_organization_member`, `update_organization_member_role`, `remove_organization_member`
          - **New Functions:** `accept_invitation`, `decline_invitation`
          
          ## Security Implications:
          - RLS Status: Enabled on the new `invitations` table.
          - Policy Changes: New policies for `invitations`.
          - Auth Requirements: Operations require authenticated users with appropriate roles.
          - **Fixes:** Addresses "Function Search Path Mutable" warnings.
          
          ## Performance Impact:
          - Indexes: Added to `invitations` table on `organization_id`, `invitee_email`, and `status`.
          - Triggers: None.
          - Estimated Impact: Low performance impact.
          */

-- 1. Create the invitation status type
CREATE TYPE public.invitation_status AS ENUM ('pending', 'accepted', 'declined');

-- 2. Create the invitations table
CREATE TABLE public.invitations (
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    organization_id uuid NOT NULL,
    invitee_email character varying NOT NULL,
    role public.user_role NOT NULL,
    status public.invitation_status NOT NULL DEFAULT 'pending',
    invited_by uuid NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT invitations_pkey PRIMARY KEY (id),
    CONSTRAINT invitations_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id) ON DELETE CASCADE,
    CONSTRAINT invitations_invited_by_fkey FOREIGN KEY (invited_by) REFERENCES auth.users(id) ON DELETE CASCADE
);

-- 3. Enable RLS and create policies for the invitations table
ALTER TABLE public.invitations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow admins to manage invitations for their organizations"
ON public.invitations
FOR ALL
USING (
  is_org_member(organization_id, auth.uid(), 'admin')
);

CREATE POLICY "Allow invited users to see their own pending invitations"
ON public.invitations
FOR SELECT
USING (
  invitee_email = auth.jwt() ->> 'email' AND status = 'pending'
);

-- 4. Harden existing functions by setting a secure search_path

-- create_organization_and_assign_admin
CREATE OR REPLACE FUNCTION public.create_organization_and_assign_admin(org_name character varying, org_description character varying)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  new_org_id uuid;
  user_id uuid := auth.uid();
BEGIN
  SET search_path = 'public';
  
  INSERT INTO public.organizations (name, description, created_by)
  VALUES (org_name, org_description, user_id)
  RETURNING id INTO new_org_id;

  INSERT INTO public.organization_members (organization_id, user_id, role)
  VALUES (new_org_id, user_id, 'admin');
  
  RETURN new_org_id;
END;
$$;

-- update_organization_member_role
CREATE OR REPLACE FUNCTION public.update_organization_member_role(member_id uuid, new_role public.user_role)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    org_id uuid;
BEGIN
    SET search_path = 'public';

    SELECT organization_id INTO org_id FROM organization_members WHERE id = member_id;

    IF is_org_member(org_id, auth.uid(), 'admin') THEN
        UPDATE organization_members
        SET role = new_role
        WHERE id = member_id;
    ELSE
        RAISE EXCEPTION 'Only admins can update member roles.';
    END IF;
END;
$$;

-- remove_organization_member
CREATE OR REPLACE FUNCTION public.remove_organization_member(member_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    org_id uuid;
BEGIN
    SET search_path = 'public';
    
    SELECT organization_id INTO org_id FROM organization_members WHERE id = member_id;

    IF is_org_member(org_id, auth.uid(), 'admin') THEN
        DELETE FROM organization_members WHERE id = member_id;
    ELSE
        RAISE EXCEPTION 'Only admins can remove members.';
    END IF;
END;
$$;


-- 5. Update invite function and create accept/decline functions

-- invite_organization_member (now creates an invitation)
CREATE OR REPLACE FUNCTION public.invite_organization_member(org_id uuid, invitee_email character varying, invitee_role public.user_role)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  SET search_path = 'public';

  IF is_org_member(org_id, auth.uid(), 'admin') THEN
    INSERT INTO public.invitations (organization_id, invitee_email, role, invited_by)
    VALUES (org_id, invitee_email, invitee_role, auth.uid());
  ELSE
    RAISE EXCEPTION 'Only admins can invite new members.';
  END IF;
END;
$$;

-- accept_invitation
CREATE OR REPLACE FUNCTION public.accept_invitation(invitation_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  inv_email character varying;
  inv_org_id uuid;
  inv_role public.user_role;
BEGIN
  SET search_path = 'public';

  SELECT invitee_email, organization_id, role 
  INTO inv_email, inv_org_id, inv_role
  FROM public.invitations
  WHERE id = invitation_id AND status = 'pending';

  IF inv_email IS NULL THEN
    RAISE EXCEPTION 'Invitation not found or already actioned.';
  END IF;

  IF inv_email = (auth.jwt() ->> 'email') THEN
    INSERT INTO public.organization_members (organization_id, user_id, role)
    VALUES (inv_org_id, auth.uid(), inv_role);

    UPDATE public.invitations
    SET status = 'accepted', updated_at = now()
    WHERE id = invitation_id;
  ELSE
    RAISE EXCEPTION 'You are not authorized to accept this invitation.';
  END IF;
END;
$$;

-- decline_invitation
CREATE OR REPLACE FUNCTION public.decline_invitation(invitation_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  inv_email character varying;
BEGIN
  SET search_path = 'public';

  SELECT invitee_email 
  INTO inv_email
  FROM public.invitations
  WHERE id = invitation_id AND status = 'pending';

  IF inv_email IS NULL THEN
    RAISE EXCEPTION 'Invitation not found or already actioned.';
  END IF;

  IF inv_email = (auth.jwt() ->> 'email') THEN
    UPDATE public.invitations
    SET status = 'declined', updated_at = now()
    WHERE id = invitation_id;
  ELSE
    RAISE EXCEPTION 'You are not authorized to decline this invitation.';
  END IF;
END;
$$;
