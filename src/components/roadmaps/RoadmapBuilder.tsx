import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { ArrowLeft, Plus, Calendar, Layout, Target, BarChart3 } from 'lucide-react';
import { Button } from '../ui/Button';
import { Modal } from '../ui/Modal';
import { InitiativesList } from '../initiatives/InitiativesList';
import { CreateInitiativeForm } from '../initiatives/CreateInitiativeForm';
import { TimelineView } from '../timeline/TimelineView';
import { AnalyticsDashboard } from '../analytics/AnalyticsDashboard';
import { ReleasesView } from '../releases/ReleasesView';
import { CreateReleaseForm } from '../releases/CreateReleaseForm';
import { supabase } from '../../lib/supabase';
import { useAuth } from '../../contexts/AuthContext';
import toast from 'react-hot-toast';

interface RoadmapBuilderProps {
  roadmap: any;
  onBack: () => void;
  organization: any;
}

export const RoadmapBuilder: React.FC<RoadmapBuilderProps> = ({
  roadmap,
  onBack,
  organization,
}) => {
  const { user } = useAuth();
  const [view, setView] = useState<'kanban' | 'timeline' | 'releases' | 'analytics'>('kanban');
  const [showCreateInitiativeModal, setShowCreateInitiativeModal] = useState(false);
  const [showCreateReleaseModal, setShowCreateReleaseModal] = useState(false);
  const [initiatives, setInitiatives] = useState<any[]>([]);
  const [features, setFeatures] = useState<any[]>([]);
  const [releases, setReleases] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchRoadmapData();
  }, [roadmap]);

  const fetchRoadmapData = async () => {
    setLoading(true);
    try {
      const { data: initiativesData, error: initiativesError } = await supabase
        .from('initiatives')
        .select('*')
        .eq('roadmap_id', roadmap.id)
        .order('sort_order', { ascending: true });
      if (initiativesError) throw initiativesError;

      const { data: featuresData, error: featuresError } = await supabase
        .from('features')
        .select('*')
        .eq('roadmap_id', roadmap.id)
        .order('sort_order', { ascending: true });
      if (featuresError) throw featuresError;

      const { data: releasesData, error: releasesError } = await supabase
        .from('releases')
        .select('*')
        .eq('roadmap_id', roadmap.id)
        .order('target_date', { ascending: true });
      if (releasesError) {
        console.warn('Could not fetch releases:', releasesError.message);
        setReleases([]);
      } else {
        setReleases(releasesData || []);
      }

      setInitiatives(initiativesData || []);
      setFeatures(featuresData || []);
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'An unknown error occurred';
      console.error('Error fetching roadmap data:', errorMessage);
      toast.error('Failed to load roadmap data');
    } finally {
      setLoading(false);
    }
  };

  const handleCreateInitiative = async (initiativeData: any) => {
    try {
      const { data, error } = await supabase
        .from('initiatives')
        .insert([{
          roadmap_id: roadmap.id,
          title: initiativeData.title,
          description: initiativeData.description,
          status: initiativeData.status,
          priority: initiativeData.priority,
          start_date: initiativeData.startDate,
          end_date: initiativeData.endDate,
          color: initiativeData.color,
          progress: 0,
          sort_order: initiatives.length,
          created_by: user?.id
        }])
        .select()
        .single();
      if (error) throw error;
      toast.success('Initiative created successfully!');
      setShowCreateInitiativeModal(false);
      setInitiatives([...initiatives, data]);
    } catch (error) {
      console.error('Error creating initiative:', error);
      toast.error('Failed to create initiative');
    }
  };

  const handleCreateRelease = async (releaseData: any) => {
    try {
      const { data, error } = await supabase
        .from('releases')
        .insert([{
          roadmap_id: roadmap.id,
          name: releaseData.name,
          description: releaseData.description,
          target_date: releaseData.targetDate,
          status: 'planned',
          created_by: user?.id
        }])
        .select()
        .single();
      if (error) throw error;
      toast.success('Release created successfully!');
      setShowCreateReleaseModal(false);
      setReleases([...releases, data]);
    } catch (error) {
      console.error('Error creating release:', error);
      toast.error('Failed to create release');
    }
  };

  const handleUpdateInitiative = async (initiativeId: string, updates: any) => {
    try {
      const { data, error } = await supabase
        .from('initiatives')
        .update(updates)
        .eq('id', initiativeId)
        .select()
        .single();
      if (error) throw error;
      setInitiatives(initiatives.map(i => (i.id === initiativeId ? data : i)));
      toast.success('Initiative updated successfully!');
    } catch (error) {
      console.error('Error updating initiative:', error);
      toast.error('Failed to update initiative');
    }
  };

  const views = [
    { id: 'kanban' as const, label: 'Kanban', icon: Layout },
    { id: 'timeline' as const, label: 'Timeline', icon: Calendar },
    { id: 'releases' as const, label: 'Releases', icon: Target },
    { id: 'analytics' as const, label: 'Analytics', icon: BarChart3 },
  ];

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

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center space-x-4">
          <Button variant="ghost" size="sm" onClick={onBack}>
            <ArrowLeft className="w-4 h-4 mr-2" />
            Back to Roadmaps
          </Button>
          <div>
            <h2 className="text-2xl font-bold text-gray-900">{roadmap.name}</h2>
            <p className="text-gray-600">{roadmap.projects?.name} • {roadmap.description}</p>
          </div>
        </div>
        <div className="flex items-center space-x-3">
          {view === 'releases' && (
            <Button size="sm" onClick={() => setShowCreateReleaseModal(true)}>
              <Plus className="w-4 h-4 mr-2" />
              New Release
            </Button>
          )}
          <Button size="sm" onClick={() => setShowCreateInitiativeModal(true)}>
            <Plus className="w-4 h-4 mr-2" />
            New Initiative
          </Button>
        </div>
      </div>

      <div className="flex items-center space-x-1 bg-gray-100 p-1 rounded-lg w-fit">
        {views.map((viewOption) => {
          const Icon = viewOption.icon;
          return (
            <button
              key={viewOption.id}
              onClick={() => setView(viewOption.id)}
              className={`flex items-center space-x-2 px-3 py-2 text-sm font-medium rounded-md transition-colors ${
                view === viewOption.id
                  ? 'bg-white text-blue-700 shadow'
                  : 'text-gray-600 hover:text-gray-800'
              }`}
            >
              <Icon className="w-4 h-4" />
              <span>{viewOption.label}</span>
            </button>
          );
        })}
      </div>

      <motion.div
        key={view}
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3 }}
      >
        {view === 'kanban' && (
          <InitiativesList
            initiatives={initiatives}
            features={features}
            onUpdateInitiative={handleUpdateInitiative}
            roadmapId={roadmap.id}
            releases={releases}
          />
        )}
        {view === 'timeline' && (
          <TimelineView
            initiatives={initiatives}
            features={features}
            releases={releases}
            onUpdateInitiative={handleUpdateInitiative}
          />
        )}
        {view === 'releases' && (
          <ReleasesView
            releases={releases}
            features={features}
            roadmapId={roadmap.id}
          />
        )}
        {view === 'analytics' && (
          <AnalyticsDashboard
            initiatives={initiatives}
            features={features}
            releases={releases}
          />
        )}
      </motion.div>

      <Modal
        isOpen={showCreateInitiativeModal}
        onClose={() => setShowCreateInitiativeModal(false)}
        title="Create New Initiative"
        size="lg"
      >
        <CreateInitiativeForm
          onSubmit={handleCreateInitiative}
          onCancel={() => setShowCreateInitiativeModal(false)}
        />
      </Modal>

      <Modal
        isOpen={showCreateReleaseModal}
        onClose={() => setShowCreateReleaseModal(false)}
        title="Create New Release"
      >
        <CreateReleaseForm
          onSubmit={handleCreateRelease}
          onCancel={() => setShowCreateReleaseModal(false)}
        />
      </Modal>
    </div>
  );
};
