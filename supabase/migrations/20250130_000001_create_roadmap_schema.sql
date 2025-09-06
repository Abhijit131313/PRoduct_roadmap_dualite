/*
# Product Roadmap Management Schema

This migration creates the foundational database structure for a product roadmap management application.

## Query Description:
This operation will create the core tables needed for managing projects, roadmaps, initiatives, features, and user access. This is a foundational schema setup that establishes the data model for product roadmap management. No existing data will be affected as this creates new tables from scratch.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- profiles: User profile management linked to auth.users
- organizations: Company/team workspaces
- projects: Individual product projects
- roadmaps: Strategic roadmap containers
- initiatives: High-level strategic initiatives/epics
- features: Individual features/user stories
- releases: Release planning and versioning
- dependencies: Feature dependencies tracking
- organization_members: Role-based access control

## Security Implications:
- RLS Status: Enabled on all tables
- Policy Changes: Yes - comprehensive RLS policies for multi-tenant access
- Auth Requirements: All tables require authenticated users

## Performance Impact:
- Indexes: Added on foreign keys and commonly queried columns
- Triggers: Profile creation trigger on auth.users
- Estimated Impact: Minimal - new schema creation
*/

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create custom types
CREATE TYPE user_role AS ENUM ('admin', 'editor', 'viewer');
CREATE TYPE feature_status AS ENUM ('backlog', 'planned', 'in_progress', 'completed', 'cancelled');
CREATE TYPE priority_level AS ENUM ('low', 'medium', 'high', 'critical');
CREATE TYPE dependency_type AS ENUM ('blocks', 'depends_on');

-- User profiles table
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Organizations table
CREATE TABLE public.organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

-- Organization members for role-based access
CREATE TABLE public.organization_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role user_role NOT NULL DEFAULT 'viewer',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(organization_id, user_id)
);

-- Projects table
CREATE TABLE public.projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    status TEXT DEFAULT 'active',
    start_date DATE,
    end_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

-- Roadmaps table
CREATE TABLE public.roadmaps (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    is_public BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

-- Releases table
CREATE TABLE public.releases (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    target_date DATE,
    release_date DATE,
    version TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Initiatives table (epics)
CREATE TABLE public.initiatives (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    roadmap_id UUID NOT NULL REFERENCES public.roadmaps(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    status feature_status DEFAULT 'backlog',
    priority priority_level DEFAULT 'medium',
    start_date DATE,
    end_date DATE,
    progress INTEGER DEFAULT 0 CHECK (progress >= 0 AND progress <= 100),
    color TEXT DEFAULT '#3B82F6',
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

-- Features table (user stories)
CREATE TABLE public.features (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    initiative_id UUID REFERENCES public.initiatives(id) ON DELETE CASCADE,
    roadmap_id UUID NOT NULL REFERENCES public.roadmaps(id) ON DELETE CASCADE,
    release_id UUID REFERENCES public.releases(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT,
    status feature_status DEFAULT 'backlog',
    priority priority_level DEFAULT 'medium',
    story_points INTEGER,
    start_date DATE,
    end_date DATE,
    assignee_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

-- Dependencies table
CREATE TABLE public.feature_dependencies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_feature_id UUID NOT NULL REFERENCES public.features(id) ON DELETE CASCADE,
    target_feature_id UUID NOT NULL REFERENCES public.features(id) ON DELETE CASCADE,
    dependency_type dependency_type NOT NULL DEFAULT 'depends_on',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(source_feature_id, target_feature_id)
);

-- Create indexes for better performance
CREATE INDEX idx_profiles_email ON public.profiles(email);
CREATE INDEX idx_organization_members_org_id ON public.organization_members(organization_id);
CREATE INDEX idx_organization_members_user_id ON public.organization_members(user_id);
CREATE INDEX idx_projects_org_id ON public.projects(organization_id);
CREATE INDEX idx_roadmaps_project_id ON public.roadmaps(project_id);
CREATE INDEX idx_initiatives_roadmap_id ON public.initiatives(roadmap_id);
CREATE INDEX idx_features_initiative_id ON public.features(initiative_id);
CREATE INDEX idx_features_roadmap_id ON public.features(roadmap_id);
CREATE INDEX idx_features_release_id ON public.features(release_id);
CREATE INDEX idx_feature_dependencies_source ON public.feature_dependencies(source_feature_id);
CREATE INDEX idx_feature_dependencies_target ON public.feature_dependencies(target_feature_id);

-- Enable Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roadmaps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.releases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.initiatives ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.features ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feature_dependencies ENABLE ROW LEVEL SECURITY;

-- RLS Policies for profiles
CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- RLS Policies for organizations
CREATE POLICY "Users can view organizations they belong to" ON public.organizations FOR SELECT 
    USING (
        EXISTS (
            SELECT 1 FROM public.organization_members 
            WHERE organization_id = organizations.id AND user_id = auth.uid()
        )
    );

CREATE POLICY "Admins can update organizations" ON public.organizations FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.organization_members 
            WHERE organization_id = organizations.id AND user_id = auth.uid() AND role = 'admin'
        )
    );

CREATE POLICY "Authenticated users can create organizations" ON public.organizations FOR INSERT
    WITH CHECK (auth.role() = 'authenticated');

-- RLS Policies for organization_members
CREATE POLICY "Members can view organization membership" ON public.organization_members FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.organization_members om 
            WHERE om.organization_id = organization_members.organization_id AND om.user_id = auth.uid()
        )
    );

CREATE POLICY "Admins can manage organization members" ON public.organization_members FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.organization_members 
            WHERE organization_id = organization_members.organization_id AND user_id = auth.uid() AND role = 'admin'
        )
    );

-- RLS Policies for projects
CREATE POLICY "Organization members can view projects" ON public.projects FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.organization_members 
            WHERE organization_id = projects.organization_id AND user_id = auth.uid()
        )
    );

CREATE POLICY "Editors and admins can modify projects" ON public.projects FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.organization_members 
            WHERE organization_id = projects.organization_id AND user_id = auth.uid() 
            AND role IN ('admin', 'editor')
        )
    );

-- RLS Policies for roadmaps
CREATE POLICY "Organization members can view roadmaps" ON public.roadmaps FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.organization_members om
            JOIN public.projects p ON p.organization_id = om.organization_id
            WHERE p.id = roadmaps.project_id AND om.user_id = auth.uid()
        )
    );

CREATE POLICY "Editors and admins can modify roadmaps" ON public.roadmaps FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.organization_members om
            JOIN public.projects p ON p.organization_id = om.organization_id
            WHERE p.id = roadmaps.project_id AND om.user_id = auth.uid() 
            AND om.role IN ('admin', 'editor')
        )
    );

-- RLS Policies for releases
CREATE POLICY "Organization members can view releases" ON public.releases FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.organization_members om
            JOIN public.projects p ON p.organization_id = om.organization_id
            WHERE p.id = releases.project_id AND om.user_id = auth.uid()
        )
    );

CREATE POLICY "Editors and admins can modify releases" ON public.releases FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.organization_members om
            JOIN public.projects p ON p.organization_id = om.organization_id
            WHERE p.id = releases.project_id AND om.user_id = auth.uid() 
            AND om.role IN ('admin', 'editor')
        )
    );

-- RLS Policies for initiatives
CREATE POLICY "Organization members can view initiatives" ON public.initiatives FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.organization_members om
            JOIN public.projects p ON p.organization_id = om.organization_id
            JOIN public.roadmaps r ON r.project_id = p.id
            WHERE r.id = initiatives.roadmap_id AND om.user_id = auth.uid()
        )
    );

CREATE POLICY "Editors and admins can modify initiatives" ON public.initiatives FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.organization_members om
            JOIN public.projects p ON p.organization_id = om.organization_id
            JOIN public.roadmaps r ON r.project_id = p.id
            WHERE r.id = initiatives.roadmap_id AND om.user_id = auth.uid() 
            AND om.role IN ('admin', 'editor')
        )
    );

-- RLS Policies for features
CREATE POLICY "Organization members can view features" ON public.features FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.organization_members om
            JOIN public.projects p ON p.organization_id = om.organization_id
            JOIN public.roadmaps r ON r.project_id = p.id
            WHERE r.id = features.roadmap_id AND om.user_id = auth.uid()
        )
    );

CREATE POLICY "Editors and admins can modify features" ON public.features FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.organization_members om
            JOIN public.projects p ON p.organization_id = om.organization_id
            JOIN public.roadmaps r ON r.project_id = p.id
            WHERE r.id = features.roadmap_id AND om.user_id = auth.uid() 
            AND om.role IN ('admin', 'editor')
        )
    );

-- RLS Policies for feature_dependencies
CREATE POLICY "Organization members can view dependencies" ON public.feature_dependencies FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.organization_members om
            JOIN public.projects p ON p.organization_id = om.organization_id
            JOIN public.roadmaps r ON r.project_id = p.id
            JOIN public.features f ON f.roadmap_id = r.id
            WHERE f.id = feature_dependencies.source_feature_id AND om.user_id = auth.uid()
        )
    );

CREATE POLICY "Editors and admins can modify dependencies" ON public.feature_dependencies FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.organization_members om
            JOIN public.projects p ON p.organization_id = om.organization_id
            JOIN public.roadmaps r ON r.project_id = p.id
            JOIN public.features f ON f.roadmap_id = r.id
            WHERE f.id = feature_dependencies.source_feature_id AND om.user_id = auth.uid() 
            AND om.role IN ('admin', 'editor')
        )
    );

-- Create function to handle profile creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name)
    VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'full_name', ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for automatic profile creation
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- Create function to update updated_at timestamps
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE PROCEDURE public.update_updated_at_column();

CREATE TRIGGER update_organizations_updated_at BEFORE UPDATE ON public.organizations
    FOR EACH ROW EXECUTE PROCEDURE public.update_updated_at_column();

CREATE TRIGGER update_projects_updated_at BEFORE UPDATE ON public.projects
    FOR EACH ROW EXECUTE PROCEDURE public.update_updated_at_column();

CREATE TRIGGER update_roadmaps_updated_at BEFORE UPDATE ON public.roadmaps
    FOR EACH ROW EXECUTE PROCEDURE public.update_updated_at_column();

CREATE TRIGGER update_initiatives_updated_at BEFORE UPDATE ON public.initiatives
    FOR EACH ROW EXECUTE PROCEDURE public.update_updated_at_column();

CREATE TRIGGER update_features_updated_at BEFORE UPDATE ON public.features
    FOR EACH ROW EXECUTE PROCEDURE public.update_updated_at_column();
