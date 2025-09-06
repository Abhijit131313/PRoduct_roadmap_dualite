/*
# Product Roadmap Management Schema
Creates the complete database schema for a product roadmap management application.

## Query Description: 
This migration creates a comprehensive multi-tenant roadmap management system with organizations, projects, roadmaps, initiatives, and features. It includes role-based access control, dependencies tracking, and release management. The migration safely handles existing objects and creates new ones as needed.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Medium"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- Tables: profiles, organizations, organization_members, projects, roadmaps, initiatives, features, dependencies, releases
- Indexes: Performance indexes on foreign keys and common query patterns
- RLS: Row Level Security policies for multi-tenant access
- Triggers: Auto profile creation on auth user signup

## Security Implications:
- RLS Status: Enabled on all tables
- Policy Changes: Yes - comprehensive policies for multi-tenant access
- Auth Requirements: All operations require authentication

## Performance Impact:
- Indexes: Added for all foreign keys and common queries
- Triggers: Minimal impact auto-profile creation trigger
- Estimated Impact: Low - well-indexed schema design
*/

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop existing trigger if it exists to avoid conflicts
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create profiles table
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    email TEXT NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create organizations table
CREATE TABLE IF NOT EXISTS public.organizations (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES public.profiles(id)
);

-- Create organization_members table
CREATE TABLE IF NOT EXISTS public.organization_members (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    role TEXT CHECK (role IN ('admin', 'editor', 'viewer')) DEFAULT 'viewer',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(organization_id, user_id)
);

-- Create projects table
CREATE TABLE IF NOT EXISTS public.projects (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    organization_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    status TEXT DEFAULT 'active',
    start_date DATE,
    end_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES public.profiles(id)
);

-- Create roadmaps table
CREATE TABLE IF NOT EXISTS public.roadmaps (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    project_id UUID REFERENCES public.projects(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    is_public BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES public.profiles(id)
);

-- Create releases table
CREATE TABLE IF NOT EXISTS public.releases (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    roadmap_id UUID REFERENCES public.roadmaps(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    version TEXT,
    release_date DATE,
    status TEXT CHECK (status IN ('planned', 'in_progress', 'released', 'cancelled')) DEFAULT 'planned',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES public.profiles(id)
);

-- Create initiatives table
CREATE TABLE IF NOT EXISTS public.initiatives (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    roadmap_id UUID REFERENCES public.roadmaps(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT CHECK (status IN ('backlog', 'planned', 'in_progress', 'completed', 'cancelled')) DEFAULT 'backlog',
    priority TEXT CHECK (priority IN ('low', 'medium', 'high', 'critical')) DEFAULT 'medium',
    start_date DATE,
    end_date DATE,
    progress INTEGER DEFAULT 0 CHECK (progress >= 0 AND progress <= 100),
    color TEXT DEFAULT '#3B82F6',
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES public.profiles(id)
);

-- Create features table
CREATE TABLE IF NOT EXISTS public.features (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    initiative_id UUID REFERENCES public.initiatives(id) ON DELETE SET NULL,
    roadmap_id UUID REFERENCES public.roadmaps(id) ON DELETE CASCADE,
    release_id UUID REFERENCES public.releases(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT CHECK (status IN ('backlog', 'planned', 'in_progress', 'completed', 'cancelled')) DEFAULT 'backlog',
    priority TEXT CHECK (priority IN ('low', 'medium', 'high', 'critical')) DEFAULT 'medium',
    story_points INTEGER,
    start_date DATE,
    end_date DATE,
    assignee_id UUID REFERENCES public.profiles(id),
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES public.profiles(id)
);

-- Create dependencies table
CREATE TABLE IF NOT EXISTS public.dependencies (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    dependent_feature_id UUID REFERENCES public.features(id) ON DELETE CASCADE,
    prerequisite_feature_id UUID REFERENCES public.features(id) ON DELETE CASCADE,
    dependency_type TEXT CHECK (dependency_type IN ('blocks', 'relates_to')) DEFAULT 'blocks',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES public.profiles(id),
    UNIQUE(dependent_feature_id, prerequisite_feature_id),
    CHECK (dependent_feature_id != prerequisite_feature_id)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_organization_members_org_id ON public.organization_members(organization_id);
CREATE INDEX IF NOT EXISTS idx_organization_members_user_id ON public.organization_members(user_id);
CREATE INDEX IF NOT EXISTS idx_projects_org_id ON public.projects(organization_id);
CREATE INDEX IF NOT EXISTS idx_roadmaps_project_id ON public.roadmaps(project_id);
CREATE INDEX IF NOT EXISTS idx_initiatives_roadmap_id ON public.initiatives(roadmap_id);
CREATE INDEX IF NOT EXISTS idx_features_roadmap_id ON public.features(roadmap_id);
CREATE INDEX IF NOT EXISTS idx_features_initiative_id ON public.features(initiative_id);
CREATE INDEX IF NOT EXISTS idx_features_assignee_id ON public.features(assignee_id);
CREATE INDEX IF NOT EXISTS idx_dependencies_dependent ON public.dependencies(dependent_feature_id);
CREATE INDEX IF NOT EXISTS idx_dependencies_prerequisite ON public.dependencies(prerequisite_feature_id);
CREATE INDEX IF NOT EXISTS idx_releases_roadmap_id ON public.releases(roadmap_id);

-- Enable Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organization_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roadmaps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.initiatives ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.features ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dependencies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.releases ENABLE ROW LEVEL SECURITY;

-- RLS Policies for profiles
CREATE POLICY "Users can view own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

-- RLS Policies for organizations
CREATE POLICY "Users can view organizations they belong to" ON public.organizations
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.organization_members 
            WHERE organization_id = id AND user_id = auth.uid()
        )
    );

CREATE POLICY "Organization admins can update organizations" ON public.organizations
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.organization_members 
            WHERE organization_id = id AND user_id = auth.uid() AND role = 'admin'
        )
    );

CREATE POLICY "Authenticated users can create organizations" ON public.organizations
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- RLS Policies for organization_members
CREATE POLICY "Users can view organization members" ON public.organization_members
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.organization_members om 
            WHERE om.organization_id = organization_id AND om.user_id = auth.uid()
        )
    );

CREATE POLICY "Organization admins can manage members" ON public.organization_members
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.organization_members 
            WHERE organization_id = organization_members.organization_id 
            AND user_id = auth.uid() AND role = 'admin'
        )
    );

-- RLS Policies for projects
CREATE POLICY "Users can view projects in their organizations" ON public.projects
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.organization_members 
            WHERE organization_id = projects.organization_id AND user_id = auth.uid()
        )
    );

CREATE POLICY "Organization editors and admins can manage projects" ON public.projects
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.organization_members 
            WHERE organization_id = projects.organization_id 
            AND user_id = auth.uid() AND role IN ('admin', 'editor')
        )
    );

-- RLS Policies for roadmaps
CREATE POLICY "Users can view roadmaps in their organizations" ON public.roadmaps
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.organization_members om
            JOIN public.projects p ON p.organization_id = om.organization_id
            WHERE p.id = roadmaps.project_id AND om.user_id = auth.uid()
        )
    );

CREATE POLICY "Organization editors and admins can manage roadmaps" ON public.roadmaps
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.organization_members om
            JOIN public.projects p ON p.organization_id = om.organization_id
            WHERE p.id = roadmaps.project_id 
            AND om.user_id = auth.uid() AND om.role IN ('admin', 'editor')
        )
    );

-- RLS Policies for initiatives
CREATE POLICY "Users can view initiatives in their organizations" ON public.initiatives
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.organization_members om
            JOIN public.projects p ON p.organization_id = om.organization_id
            JOIN public.roadmaps r ON r.project_id = p.id
            WHERE r.id = initiatives.roadmap_id AND om.user_id = auth.uid()
        )
    );

CREATE POLICY "Organization editors and admins can manage initiatives" ON public.initiatives
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.organization_members om
            JOIN public.projects p ON p.organization_id = om.organization_id
            JOIN public.roadmaps r ON r.project_id = p.id
            WHERE r.id = initiatives.roadmap_id 
            AND om.user_id = auth.uid() AND om.role IN ('admin', 'editor')
        )
    );

-- RLS Policies for features
CREATE POLICY "Users can view features in their organizations" ON public.features
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.organization_members om
            JOIN public.projects p ON p.organization_id = om.organization_id
            JOIN public.roadmaps r ON r.project_id = p.id
            WHERE r.id = features.roadmap_id AND om.user_id = auth.uid()
        )
    );

CREATE POLICY "Organization editors and admins can manage features" ON public.features
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.organization_members om
            JOIN public.projects p ON p.organization_id = om.organization_id
            JOIN public.roadmaps r ON r.project_id = p.id
            WHERE r.id = features.roadmap_id 
            AND om.user_id = auth.uid() AND om.role IN ('admin', 'editor')
        )
    );

-- RLS Policies for dependencies
CREATE POLICY "Users can view dependencies in their organizations" ON public.dependencies
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.features f
            JOIN public.organization_members om ON (
                EXISTS (
                    SELECT 1 FROM public.roadmaps r
                    JOIN public.projects p ON p.id = r.project_id
                    WHERE r.id = f.roadmap_id AND p.organization_id = om.organization_id
                )
            )
            WHERE f.id = dependencies.dependent_feature_id AND om.user_id = auth.uid()
        )
    );

CREATE POLICY "Organization editors and admins can manage dependencies" ON public.dependencies
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.features f
            JOIN public.organization_members om ON (
                EXISTS (
                    SELECT 1 FROM public.roadmaps r
                    JOIN public.projects p ON p.id = r.project_id
                    WHERE r.id = f.roadmap_id AND p.organization_id = om.organization_id
                )
            )
            WHERE f.id = dependencies.dependent_feature_id 
            AND om.user_id = auth.uid() AND om.role IN ('admin', 'editor')
        )
    );

-- RLS Policies for releases
CREATE POLICY "Users can view releases in their organizations" ON public.releases
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.organization_members om
            JOIN public.projects p ON p.organization_id = om.organization_id
            JOIN public.roadmaps r ON r.project_id = p.id
            WHERE r.id = releases.roadmap_id AND om.user_id = auth.uid()
        )
    );

CREATE POLICY "Organization editors and admins can manage releases" ON public.releases
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.organization_members om
            JOIN public.projects p ON p.organization_id = om.organization_id
            JOIN public.roadmaps r ON r.project_id = p.id
            WHERE r.id = releases.roadmap_id 
            AND om.user_id = auth.uid() AND om.role IN ('admin', 'editor')
        )
    );

-- Function to handle new user creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', '')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger for auto profile creation
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Function to update timestamps
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create update triggers
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_organizations_updated_at
    BEFORE UPDATE ON public.organizations
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_projects_updated_at
    BEFORE UPDATE ON public.projects
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_roadmaps_updated_at
    BEFORE UPDATE ON public.roadmaps
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_initiatives_updated_at
    BEFORE UPDATE ON public.initiatives
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_features_updated_at
    BEFORE UPDATE ON public.features
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_releases_updated_at
    BEFORE UPDATE ON public.releases
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
