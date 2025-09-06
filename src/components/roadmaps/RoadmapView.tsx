import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { Plus, BarChart3, Calendar, Target, Filter, Download, Upload } from 'lucide-react';
import { Button } from '../ui/Button';
import { Modal } from '../ui/Modal';
import { RoadmapBuilder } from './RoadmapBuilder';
import { CreateRoadmapForm } from './CreateRoadmapForm';
import { RoadmapList } from './RoadmapList';
import { supabase } from '../../lib/supabase';
import { useAuth } from '../../contexts/AuthContext';
import toast from 'react-hot-toast';

interface RoadmapViewProps {
  organization: any;
}

export const RoadmapView: React.FC<RoadmapViewProps> = ({ organization }) => {
  const { user } = useAuth();
  const [roadmaps, setRoadmaps] = useState<any[]>([]);
  const [selectedRoadmap, setSelectedRoadmap] = useState<any>(null);
  const [projects, setProjects] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [view, setView] = useState<'list' | 'builder'>('list');

  useEffect(() => {
    fetchData();
  }, [organization]);

  const fetchData = async () => {
    try {
      // Fetch projects for this organization
      const { data: projectsData, error: projectsError } = await supabase
        .from('projects')
        .select('*')
        .eq('organization_id', organization.id);

      if (projectsError) throw projectsError;
      setProjects(projectsData || []);

      // Fetch roadmaps
      if (projectsData && projectsData.length > 0) {
        const projectIds = projectsData.map(p => p.id);
        const { data: roadmapsData, error: roadmapsError } = await supabase
          .from('roadmaps')
          .select(`
            *,
            projects (
              id,
              name
            )
          `)
          .in('project_id', projectIds)
          .order('created_at', { ascending: false });

        if (roadmapsError) throw roadmapsError;
        setRoadmaps(roadmapsData || []);
      }
    } catch (error) {
      console.error('Error fetching data:', error);
      toast.error('Failed to load roadmaps');
    } finally {
      setLoading(false);
    }
  };

  const handleCreateRoadmap = async (roadmapData: any) => {
    try {
      const { data, error } = await supabase
        .from('roadmaps')
        .insert([{
          project_id: roadmapData.projectId,
          name: roadmapData.name,
          description: roadmapData.description,
          is_public: roadmapData.isPublic,
          created_by: user?.id
        }])
        .select(`
          *,
          projects (
            id,
            name
          )
        `)
        .single();

      if (error) throw error;

      toast.success('Roadmap created successfully!');
      setShowCreateModal(false);
      setRoadmaps([data, ...roadmaps]);
    } catch (error) {
      console.error('Error creating roadmap:', error);
      toast.error('Failed to create roadmap');
    }
  };

  const handleSelectRoadmap = (roadmap: any) => {
    setSelectedRoadmap(roadmap);
    setView('builder');
  };

  const handleBackToList = () => {
    setView('list');
    setSelectedRoadmap(null);
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <motion.div
          animate={{ rotate: 360 }}
          transition={{ duration: 1, repeat: Infinity, ease: "linear" }}
          className="w-8 h-8 border-2 border-blue-200 border-t-blue-600 rounded-full"
        />
      </div>
    );
  }

  if (projects.length === 0) {
    return (
      <div className="bg-white rounded-lg shadow p-8 text-center">
        <Target className="w-16 h-16 text-gray-400 mx-auto mb-4" />
        <h3 className="text-xl font-semibold text-gray-900 mb-2">No Projects Found</h3>
        <p className="text-gray-600 mb-4">
          You need to create a project first before you can create roadmaps.
        </p>
        <p className="text-sm text-gray-500">
          Switch to the Projects tab to create your first project.
        </p>
      </div>
    );
  }

  if (view === 'builder' && selectedRoadmap) {
    return (
      <RoadmapBuilder
        roadmap={selectedRoadmap}
        onBack={handleBackToList}
        organization={organization}
      />
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">Roadmaps</h2>
          <p className="text-gray-600">Visual roadmap planning for {organization.name}</p>
        </div>
        <div className="flex items-center space-x-3">
          <Button variant="outline" size="sm">
            <Upload className="w-4 h-4 mr-2" />
            Import
          </Button>
          <Button variant="outline" size="sm">
            <Download className="w-4 h-4 mr-2" />
            Export
          </Button>
          <Button onClick={() => setShowCreateModal(true)}>
            <Plus className="w-4 h-4 mr-2" />
            New Roadmap
          </Button>
        </div>
      </div>

      <div className="grid gap-6 md:grid-cols-3 mb-6">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="bg-white rounded-lg shadow p-6"
        >
          <div className="flex items-center space-x-3 mb-4">
            <div className="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center">
              <Target className="w-5 h-5 text-blue-600" />
            </div>
            <div>
              <h3 className="text-lg font-semibold text-gray-900">Strategic Planning</h3>
              <p className="text-sm text-gray-600">Timeline & Gantt views</p>
            </div>
          </div>
          <p className="text-gray-600 text-sm">
            Visualize your product roadmap with interactive timeline views and drag-drop prioritization.
          </p>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          className="bg-white rounded-lg shadow p-6"
        >
          <div className="flex items-center space-x-3 mb-4">
            <div className="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center">
              <Calendar className="w-5 h-5 text-green-600" />
            </div>
            <div>
              <h3 className="text-lg font-semibold text-gray-900">Release Planning</h3>
              <p className="text-sm text-gray-600">Milestone tracking</p>
            </div>
          </div>
          <p className="text-gray-600 text-sm">
            Plan and track releases with dependency management and progress monitoring.
          </p>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
          className="bg-white rounded-lg shadow p-6"
        >
          <div className="flex items-center space-x-3 mb-4">
            <div className="w-10 h-10 bg-purple-100 rounded-lg flex items-center justify-center">
              <BarChart3 className="w-5 h-5 text-purple-600" />
            </div>
            <div>
              <h3 className="text-lg font-semibold text-gray-900">Progress Tracking</h3>
              <p className="text-sm text-gray-600">Real-time insights</p>
            </div>
          </div>
          <p className="text-gray-600 text-sm">
            Monitor progress with detailed analytics and team collaboration features.
          </p>
        </motion.div>
      </div>

      <RoadmapList
        roadmaps={roadmaps}
        onSelectRoadmap={handleSelectRoadmap}
      />

      <Modal
        isOpen={showCreateModal}
        onClose={() => setShowCreateModal(false)}
        title="Create New Roadmap"
      >
        <CreateRoadmapForm
          projects={projects}
          onSubmit={handleCreateRoadmap}
          onCancel={() => setShowCreateModal(false)}
        />
      </Modal>
    </div>
  );
};
