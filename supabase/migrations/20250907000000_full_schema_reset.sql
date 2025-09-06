/*
          # [Full Schema Reset &amp; Rebuild]
          This migration completely resets and rebuilds the core application schema. It drops all existing tables, types, functions, and policies to ensure a clean state and then recreates them in the correct order of dependency. This is a destructive operation designed to fix persistent migration errors but will result in the loss of all existing roadmap data. User authentication data will be preserved.

          ## Query Description: [This operation will DELETE ALL existing data in the roadmap application tables (Organizations, Projects, Roadmaps, etc.). It is designed to fix critical schema errors. BACKUP YOUR DATA if it is important. This change is NOT REVERSIBLE.]
          
          ## Metadata:
          - Schema-Category: ["Dangerous"]
          - Impact-Level: ["High"]
          - Requires-Backup: [true]
          - Reversible: [false]
          
          ## Structure Details:
          - Drops all application tables, functions, types, and policies.
          - Recreates all schema components in the correct dependency order.
          
          ## Security Implications:
          - RLS Status: [Re-enabled]
          - Policy Changes: [Yes, all policies are recreated]
          - Auth Requirements: [No changes to auth schema]
          
          ## Performance Impact:
          - Indexes: [Recreated]
          - Triggers: [Recreated]
          - Estimated Impact: [Brief performance dip during migration, then normal operation.]
          */

-- Step 1: Drop existing objects in reverse order of dependency to avoid errors.
DROP POLICY IF EXISTS "Enable all for admins" ON "public"."invitations";
DROP POLICY IF EXISTS "Enable read for members" ON "public"."invitations";
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON "public"."invitations";
DROP POLICY IF EXISTS "Enable all for organization admins" ON "public"."features";
DROP POLICY IF EXISTS "Enable read for organization members" ON "public"."features";
DROP POLICY IF EXISTS "Enable all for organization admins" ON "public"."initiatives";
DROP POLICY IF EXISTS "Enable read for organization members" ON "public"."initiatives";
DROP POLICY IF EXISTS "Enable all for organization admins" ON "public"."releases";
DROP POLICY IF EXISTS "Enable read for organization members" ON "public"."releases";
DROP POLICY IF EXISTS "Enable all for organization admins" ON "public"."roadmaps";
DROP POLICY IF EXISTS "Enable read for public roadmaps" ON "public"."roadmaps";
DROP POLICY IF EXISTS "Enable read for organization members" ON "public"."roadmaps";
DROP POLICY IF EXISTS "Enable all for organization admins" ON "public"."projects";
DROP POLICY IF EXISTS "Enable read for organization members" ON "public"."projects";
DROP POLICY IF EXISTS "Enable all for organization admins" ON "public"."organization_members";
DROP POLICY IF EXISTS "Enable read for organization members" ON "public"."organization_members";
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON "public"."organizations";
DROP POLICY IF EXISTS "Enable read for organization members" ON "public"."organizations";
DROP POLICY IF EXISTS "Enable update for users based on email" ON "public"."profiles";
DROP POLICY IF EXISTS "Enable read access for all users" ON "public"."profiles";
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON "public"."profiles";

ALTER TABLE IF EXISTS public.invitations DROP CONSTRAINT IF EXISTS invitations_organization_id_fkey;
ALTER TABLE IF EXISTS public.invitations DROP CONSTRAINT IF EXISTS invitations_invited_by_fkey;
ALTER TABLE IF EXISTS public.features DROP CONSTRAINT IF EXISTS features_release_id_fkey;
ALTER TABLE IF EXISTS public.features DROP CONSTRAINT IF EXISTS features_initiative_id_fkey;
ALTER TABLE IF EXISTS public.features DROP CONSTRAINT IF EXISTS features_roadmap_id_fkey;
ALTER TABLE IF EXISTS public.features DROP CONSTRAINT IF EXISTS features_created_by_fkey;
ALTER TABLE IF EXISTS public.features DROP CONSTRAINT IF EXISTS features_assignee_id_fkey;
ALTER TABLE IF EXISTS public.initiatives DROP CONSTRAINT IF EXISTS initiatives_roadmap_id_fkey;
ALTER TABLE IF EXISTS public.initiatives DROP CONSTRAINT IF EXISTS initiatives_created_by_fkey;
ALTER TABLE IF EXISTS public.releases DROP CONSTRAINT IF EXISTS releases_roadmap_id_fkey;
ALTER TABLE IF EXISTS public.releases DROP CONSTRAINT IF EXISTS releases_created_by_fkey;
ALTER TABLE IF EXISTS public.roadmaps DROP CONSTRAINT IF EXISTS roadmaps_project_id_fkey;
ALTER TABLE IF EXISTS public.roadmaps DROP CONSTRAINT IF EXISTS roadmaps_created_by_fkey;
ALTER TABLE IF EXISTS public.projects DROP CONSTRAINT IF EXISTS projects_organization_id_fkey;
ALTER TABLE IF EXISTS public.projects DROP CONSTRAINT IF EXISTS projects_created_by_fkey;
ALTER TABLE IF EXISTS public.organization_members DROP CONSTRAINT IF EXISTS organization_members_user_id_fkey;
ALTER TABLE IF EXISTS public.organization_members DROP CONSTRAINT IF EXISTS organization_members_organization_id_fkey;
ALTER TABLE IF EXISTS public.organizations DROP CONSTRAINT IF EXISTS organizations_created_by_fkey;
ALTER TABLE IF EXISTS public.profiles DROP CONSTRAINT IF EXISTS profiles_id_fkey;

DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.create_organization_and_assign_admin(text, text);
DROP FUNCTION IF EXISTS public.invite_organization_member(uuid, text, public.user_role);
DROP FUNCTION IF EXISTS public.accept_invitation(uuid);
DROP FUNCTION IF EXISTS public.decline_invitation(uuid);
DROP FUNCTION IF EXISTS public.update_organization_member_role(uuid, public.user_role);
DROP FUNCTION IF EXISTS public.remove_organization_member(uuid);
DROP FUNCTION IF EXISTS public.is_org_member(uuid, uuid, public.user_role);

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

DROP TABLE IF EXISTS public.features;
DROP TABLE IF EXISTS public.initiatives;
DROP TABLE IF EXISTS public.releases;
DROP TABLE IF EXISTS public.roadmaps;
DROP TABLE IF EXISTS public.projects;
DROP TABLE IF EXISTS public.invitations;
DROP TABLE IF EXISTS public.organization_members;
DROP TABLE IF EXISTS public.organizations;
DROP TABLE IF EXISTS public.profiles;

DROP TYPE IF EXISTS public.user_role;
DROP TYPE IF EXISTS public.status;
DROP TYPE IF EXISTS public.priority;
DROP TYPE IF EXISTS public.invitation_status;

-- Step 2: Recreate ENUM types
CREATE TYPE public.user_role AS ENUM ('admin', 'editor', 'viewer');
CREATE TYPE public.status AS ENUM ('backlog', 'planned', 'in_progress', 'completed', 'cancelled');
CREATE TYPE public.priority AS ENUM ('low', 'medium', 'high', 'critical');
CREATE TYPE public.invitation_status AS ENUM ('pending', 'accepted', 'declined');

-- Step 3: Recreate tables in the correct order
CREATE TABLE public.profiles (
    id uuid NOT NULL PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name text,
    avatar_url text,
    email text NOT NULL UNIQUE,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.organizations (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name text NOT NULL,
    description text,
    created_by uuid REFERENCES auth.users(id),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.organization_members (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role public.user_role DEFAULT 'viewer'::public.user_role NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    UNIQUE (organization_id, user_id)
);

CREATE TABLE public.invitations (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    invited_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    invitee_email text NOT NULL,
    role public.user_role NOT NULL,
    status public.invitation_status DEFAULT 'pending'::public.invitation_status NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.projects (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    name text NOT NULL,
    description text,
    status text DEFAULT 'planned'::text NOT NULL,
    start_date date,
    end_date date,
    created_by uuid REFERENCES auth.users(id),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.roadmaps (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    project_id uuid NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
    name text NOT NULL,
    description text,
    is_public boolean DEFAULT false NOT NULL,
    created_by uuid REFERENCES auth.users(id),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.releases (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    roadmap_id uuid NOT NULL REFERENCES public.roadmaps(id) ON DELETE CASCADE,
    name text NOT NULL,
    description text,
    status text DEFAULT 'planned'::text NOT NULL,
    target_date date,
    created_by uuid REFERENCES auth.users(id),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.initiatives (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    roadmap_id uuid NOT NULL REFERENCES public.roadmaps(id) ON DELETE CASCADE,
    title text NOT NULL,
    description text,
    status public.status DEFAULT 'backlog'::public.status NOT NULL,
    priority public.priority DEFAULT 'medium'::public.priority NOT NULL,
    start_date date,
    end_date date,
    progress integer DEFAULT 0 NOT NULL,
    color text DEFAULT '#3B82F6'::text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_by uuid REFERENCES auth.users(id),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.features (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    roadmap_id uuid NOT NULL REFERENCES public.roadmaps(id) ON DELETE CASCADE,
    initiative_id uuid REFERENCES public.initiatives(id) ON DELETE SET NULL,
    release_id uuid REFERENCES public.releases(id) ON DELETE SET NULL,
    title text NOT NULL,
    description text,
    status public.status DEFAULT 'backlog'::public.status NOT NULL,
    priority public.priority DEFAULT 'medium'::public.priority NOT NULL,
    story_points integer,
    start_date date,
    end_date date,
    assignee_id uuid REFERENCES auth.users(id),
    sort_order integer DEFAULT 0 NOT NULL,
    created_by uuid REFERENCES auth.users(id),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Step 4: Recreate functions and triggers
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, avatar_url, email)
  VALUES (
    new.id,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'avatar_url',
    new.email
  );
  RETURN new;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

CREATE OR REPLACE FUNCTION public.is_org_member(org_id uuid, user_id uuid, min_role public.user_role)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_role_level integer;
  min_role_level integer;
BEGIN
  SELECT CASE role WHEN 'admin' THEN 3 WHEN 'editor' THEN 2 WHEN 'viewer' THEN 1 ELSE 0 END
  INTO user_role_level
  FROM organization_members
  WHERE organization_members.organization_id = org_id AND organization_members.user_id = user_id;

  SELECT CASE min_role WHEN 'admin' THEN 3 WHEN 'editor' THEN 2 WHEN 'viewer' THEN 1 ELSE 0 END
  INTO min_role_level;

  RETURN user_role_level >= min_role_level;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_organization_and_assign_admin(org_name text, org_description text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_org_id uuid;
  current_user_id uuid := auth.uid();
BEGIN
  INSERT INTO public.organizations (name, description, created_by)
  VALUES (org_name, org_description, current_user_id)
  RETURNING id INTO new_org_id;

  INSERT INTO public.organization_members (organization_id, user_id, role)
  VALUES (new_org_id, current_user_id, 'admin');

  RETURN new_org_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.invite_organization_member(org_id uuid, invitee_email text, invitee_role public.user_role)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_org_member(org_id, auth.uid(), 'admin'::public.user_role) THEN
    RAISE EXCEPTION 'Only admins can invite new members.';
  END IF;

  INSERT INTO public.invitations (organization_id, invited_by, invitee_email, role)
  VALUES (org_id, auth.uid(), invitee_email, invitee_role);
END;
$$;

CREATE OR REPLACE FUNCTION public.accept_invitation(invitation_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  invitation_rec public.invitations;
  invitee_profile public.profiles;
BEGIN
  SELECT * INTO invitation_rec FROM public.invitations WHERE id = invitation_id;
  SELECT * INTO invitee_profile FROM public.profiles WHERE email = invitation_rec.invitee_email;

  IF invitee_profile.id != auth.uid() THEN
    RAISE EXCEPTION 'You cannot accept an invitation for another user.';
  END IF;

  IF invitation_rec.status != 'pending' THEN
    RAISE EXCEPTION 'This invitation is no longer valid.';
  END IF;

  INSERT INTO public.organization_members (organization_id, user_id, role)
  VALUES (invitation_rec.organization_id, auth.uid(), invitation_rec.role)
  ON CONFLICT (organization_id, user_id) DO UPDATE SET role = invitation_rec.role;

  UPDATE public.invitations SET status = 'accepted' WHERE id = invitation_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.decline_invitation(invitation_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  invitation_rec public.invitations;
  invitee_profile public.profiles;
BEGIN
  SELECT * INTO invitation_rec FROM public.invitations WHERE id = invitation_id;
  SELECT * INTO invitee_profile FROM public.profiles WHERE email = invitation_rec.invitee_email;

  IF invitee_profile.id != auth.uid() THEN
    RAISE EXCEPTION 'You cannot decline an invitation for another user.';
  END IF;
  
  UPDATE public.invitations SET status = 'declined' WHERE id = invitation_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_organization_member_role(member_id uuid, new_role public.user_role)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  member_rec public.organization_members;
BEGIN
  SELECT * INTO member_rec FROM public.organization_members WHERE id = member_id;

  IF NOT is_org_member(member_rec.organization_id, auth.uid(), 'admin'::public.user_role) THEN
    RAISE EXCEPTION 'Only admins can change member roles.';
  END IF;

  UPDATE public.organization_members SET role = new_role WHERE id = member_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.remove_organization_member(member_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  member_rec public.organization_members;
BEGIN
  SELECT * INTO member_rec FROM public.organization_members WHERE id = member_id;

  IF NOT is_org_member(member_rec.organization_id, auth.uid(), 'admin'::public.user_role) THEN
    RAISE EXCEPTION 'Only admins can remove members.';
  END IF;

  DELETE FROM public.organization_members WHERE id = member_id;
END;
$$;

-- Step 5: Re-enable RLS and recreate policies
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read access for all users" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Enable insert for authenticated users" ON public.profiles FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Enable update for users based on email" ON public.profiles FOR UPDATE USING (auth.uid() = id);

ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read for organization members" ON public.organizations FOR SELECT USING (is_org_member(id, auth.uid(), 'viewer'::public.user_role));
CREATE POLICY "Enable insert for authenticated users" ON public.organizations FOR INSERT WITH CHECK (auth.role() = 'authenticated');

ALTER TABLE public.organization_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read for organization members" ON public.organization_members FOR SELECT USING (is_org_member(organization_id, auth.uid(), 'viewer'::public.user_role));
CREATE POLICY "Enable all for organization admins" ON public.organization_members FOR ALL USING (is_org_member(organization_id, auth.uid(), 'admin'::public.user_role));

ALTER TABLE public.invitations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable insert for authenticated users" ON public.invitations FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Enable read for members" ON public.invitations FOR SELECT USING (is_org_member(organization_id, auth.uid(), 'admin'::public.user_role) OR invitee_email = (SELECT email FROM auth.users WHERE id = auth.uid()));
CREATE POLICY "Enable all for admins" ON public.invitations FOR ALL USING (is_org_member(organization_id, auth.uid(), 'admin'::public.user_role));

ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read for organization members" ON public.projects FOR SELECT USING (is_org_member(organization_id, auth.uid(), 'viewer'::public.user_role));
CREATE POLICY "Enable all for organization admins" ON public.projects FOR ALL USING (is_org_member(organization_id, auth.uid(), 'admin'::public.user_role));

ALTER TABLE public.roadmaps ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read for organization members" ON public.roadmaps FOR SELECT USING (is_org_member((SELECT organization_id FROM projects WHERE id = project_id), auth.uid(), 'viewer'::public.user_role));
CREATE POLICY "Enable read for public roadmaps" ON public.roadmaps FOR SELECT USING (is_public = true);
CREATE POLICY "Enable all for organization admins" ON public.roadmaps FOR ALL USING (is_org_member((SELECT organization_id FROM projects WHERE id = project_id), auth.uid(), 'admin'::public.user_role));

ALTER TABLE public.releases ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read for organization members" ON public.releases FOR SELECT USING (is_org_member((SELECT p.organization_id FROM roadmaps r JOIN projects p ON r.project_id = p.id WHERE r.id = roadmap_id), auth.uid(), 'viewer'::public.user_role));
CREATE POLICY "Enable all for organization admins" ON public.releases FOR ALL USING (is_org_member((SELECT p.organization_id FROM roadmaps r JOIN projects p ON r.project_id = p.id WHERE r.id = roadmap_id), auth.uid(), 'admin'::public.user_role));

ALTER TABLE public.initiatives ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read for organization members" ON public.initiatives FOR SELECT USING (is_org_member((SELECT p.organization_id FROM roadmaps r JOIN projects p ON r.project_id = p.id WHERE r.id = roadmap_id), auth.uid(), 'viewer'::public.user_role));
CREATE POLICY "Enable all for organization admins" ON public.initiatives FOR ALL USING (is_org_member((SELECT p.organization_id FROM roadmaps r JOIN projects p ON r.project_id = p.id WHERE r.id = roadmap_id), auth.uid(), 'admin'::public.user_role));

ALTER TABLE public.features ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read for organization members" ON public.features FOR SELECT USING (is_org_member((SELECT p.organization_id FROM roadmaps r JOIN projects p ON r.project_id = p.id WHERE r.id = roadmap_id), auth.uid(), 'viewer'::public.user_role));
CREATE POLICY "Enable all for organization admins" ON public.features FOR ALL USING (is_org_member((SELECT p.organization_id FROM roadmaps r JOIN projects p ON r.project_id = p.id WHERE r.id = roadmap_id), auth.uid(), 'admin'::public.user_role));
