import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { Plus, MoreVertical, Calendar, Users, Target } from 'lucide-react';
import { DndProvider, useDrag, useDrop } from 'react-dnd';
import { HTML5Backend } from 'react-dnd-html5-backend';
import { Button } from '../ui/Button';
import { Modal } from '../ui/Modal';
import { CreateFeatureForm } from '../features/CreateFeatureForm';
import { FeatureCard } from '../features/FeatureCard';
import { supabase } from '../../lib/supabase';
import { useAuth } from '../../contexts/AuthContext';
import toast from 'react-hot-toast';
import { format } from 'date-fns';

interface InitiativesListProps {
  initiatives: any[];
  features: any[];
  onUpdateInitiative: (id: string, updates: any) => void;
  roadmapId: string;
  releases: any[];
}

const STATUSES = [
  { id: 'backlog', label: 'Backlog', color: 'bg-gray-100 text-gray-800' },
  { id: 'planned', label: 'Planned', color: 'bg-blue-100 text-blue-800' },
  { id: 'in_progress', label: 'In Progress', color: 'bg-yellow-100 text-yellow-800' },
  { id: 'completed', label: 'Completed', color: 'bg-green-100 text-green-800' },
  { id: 'cancelled', label: 'Cancelled', color: 'bg-red-100 text-red-800' },
];

const PRIORITIES = {
  low: { color: 'bg-gray-100 text-gray-800', label: 'Low' },
  medium: { color: 'bg-yellow-100 text-yellow-800', label: 'Medium' },
  high: { color: 'bg-orange-100 text-orange-800', label: 'High' },
  critical: { color: 'bg-red-100 text-red-800', label: 'Critical' },
};

interface InitiativeCardProps {
  initiative: any;
  features: any[];
  releases: any[];
  onUpdate: (updates: any) => void;
  onDrop: (draggedId: string) => void;
}

const InitiativeCard: React.FC<InitiativeCardProps> = ({
  initiative,
  features,
  releases,
  onUpdate,
  onDrop,
}) => {
  const { user } = useAuth();
  const [showCreateFeatureModal, setShowCreateFeatureModal] = useState(false);
  const [showFeatures, setShowFeatures] = useState(true);

  const [{ isDragging }, drag] = useDrag({
    type: 'initiative',
    item: { id: initiative.id, type: 'initiative' },
    collect: (monitor) => ({
      isDragging: monitor.isDragging(),
    }),
  });

  const [{ isOver }, drop] = useDrop({
    accept: 'initiative',
    drop: (item: any) => {
      if (item.id !== initiative.id) {
        onDrop(item.id);
      }
    },
    collect: (monitor) => ({
      isOver: monitor.isOver(),
    }),
  });

  const initiativeFeatures = features.filter(f => f.initiative_id === initiative.id);
  const progress = initiative.progress || 0;
  const priorityConfig = PRIORITIES[initiative.priority as keyof typeof PRIORITIES];

  const handleCreateFeature = async (featureData: any) => {
    try {
      const { data, error } = await supabase
        .from('features')
        .insert([{
          initiative_id: initiative.id,
          roadmap_id: initiative.roadmap_id,
          title: featureData.title,
          description: featureData.description,
          status: featureData.status,
          priority: featureData.priority,
          story_points: featureData.storyPoints,
          start_date: featureData.startDate,
          end_date: featureData.endDate,
          release_id: featureData.releaseId,
          sort_order: initiativeFeatures.length,
          created_by: user?.id
        }])
        .select()
        .single();

      if (error) throw error;

      toast.success('Feature created successfully!');
      setShowCreateFeatureModal(false);
      // Note: This won't visually update the feature list until the next full fetch.
      // For a more reactive UI, you'd lift feature state up to RoadmapBuilder.
    } catch (error) {
      console.error('Error creating feature:', error);
      toast.error('Failed to create feature');
    }
  };

  return (
    <>
      <motion.div
        ref={(node) => drag(drop(node))}
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className={`bg-white rounded-lg shadow border-l-4 p-4 cursor-move ${
          isDragging ? 'opacity-50' : ''
        } ${isOver ? 'ring-2 ring-blue-300' : ''}`}
        style={{ borderLeftColor: initiative.color || '#3B82F6' }}
      >
        <div className="flex items-start justify-between mb-3">
          <div className="flex-1">
            <h3 className="text-lg font-semibold text-gray-900 mb-1">
              {initiative.title}
            </h3>
            <div className="flex items-center space-x-2 mb-2">
              <span className={`inline-flex items-center px-2 py-1 rounded-full text-xs font-medium ${priorityConfig.color}`}>
                {priorityConfig.label}
              </span>
              <span className={`inline-flex items-center px-2 py-1 rounded-full text-xs font-medium ${
                STATUSES.find(s => s.id === initiative.status)?.color
              }`}>
                {STATUSES.find(s => s.id === initiative.status)?.label}
              </span>
            </div>
          </div>
          <button className="text-gray-400 hover:text-gray-600">
            <MoreVertical className="w-4 h-4" />
          </button>
        </div>

        {initiative.description && (
          <p className="text-gray-600 text-sm mb-3 line-clamp-2">
            {initiative.description}
          </p>
        )}

        <div className="mb-3">
          <div className="flex items-center justify-between text-sm text-gray-600 mb-1">
            <span>Progress</span>
            <span>{progress}%</span>
          </div>
          <div className="w-full bg-gray-200 rounded-full h-2">
            <div
              className="bg-blue-600 h-2 rounded-full transition-all duration-300"
              style={{ width: `${progress}%` }}
            />
          </div>
        </div>

        {(initiative.start_date || initiative.end_date) && (
          <div className="flex items-center text-sm text-gray-500 mb-3">
            <Calendar className="w-4 h-4 mr-1" />
            {initiative.start_date && format(new Date(initiative.start_date), 'MMM d')}
            {initiative.start_date && initiative.end_date && ' - '}
            {initiative.end_date && format(new Date(initiative.end_date), 'MMM d, yyyy')}
          </div>
        )}

        <div className="border-t border-gray-200 pt-3">
          <div className="flex items-center justify-between mb-2">
            <button
              onClick={() => setShowFeatures(!showFeatures)}
              className="flex items-center text-sm font-medium text-gray-700 hover:text-gray-900"
            >
              <Target className="w-4 h-4 mr-1" />
              Features ({initiativeFeatures.length})
            </button>
            <Button
              size="sm"
              variant="ghost"
              onClick={() => setShowCreateFeatureModal(true)}
            >
              <Plus className="w-4 h-4" />
            </Button>
          </div>
          
          {showFeatures && (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: 'auto' }}
              className="space-y-2"
            >
              {initiativeFeatures.map((feature) => (
                <FeatureCard key={feature.id} feature={feature} />
              ))}
              {initiativeFeatures.length === 0 && (
                <p className="text-gray-500 text-sm italic">No features yet</p>
              )}
            </motion.div>
          )}
        </div>
      </motion.div>

      <Modal
        isOpen={showCreateFeatureModal}
        onClose={() => setShowCreateFeatureModal(false)}
        title="Create New Feature"
      >
        <CreateFeatureForm
          onSubmit={handleCreateFeature}
          onCancel={() => setShowCreateFeatureModal(false)}
          releases={releases}
        />
      </Modal>
    </>
  );
};

export const InitiativesList: React.FC<InitiativesListProps> = ({
  initiatives,
  features,
  onUpdateInitiative,
  roadmapId,
  releases,
}) => {
  const handleDrop = (draggedId: string, targetStatus: string) => {
    const updates = { status: targetStatus };
    onUpdateInitiative(draggedId, updates);
  };

  if (initiatives.length === 0) {
    return (
      <div className="bg-white rounded-lg shadow p-8 text-center">
        <Target className="w-16 h-16 text-gray-400 mx-auto mb-4" />
        <h3 className="text-xl font-semibold text-gray-900 mb-2">No Initiatives Yet</h3>
        <p className="text-gray-600 mb-4">
          Create your first initiative to start organizing features and tracking progress.
        </p>
        <p className="text-sm text-gray-500">
          Initiatives are high-level goals that group related features together.
        </p>
      </div>
    );
  }

  return (
    <DndProvider backend={HTML5Backend}>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {STATUSES.map((status) => {
          const statusInitiatives = initiatives.filter(i => i.status === status.id);
          
          return (
            <div key={status.id} className="space-y-4">
              <div className="flex items-center justify-between">
                <h3 className="text-lg font-semibold text-gray-900">{status.label}</h3>
                <span className="text-sm text-gray-500">
                  {statusInitiatives.length}
                </span>
              </div>
              
              <div className="space-y-4 min-h-screen bg-gray-50 rounded-lg p-4">
                {statusInitiatives.map((initiative) => (
                  <InitiativeCard
                    key={initiative.id}
                    initiative={initiative}
                    features={features}
                    releases={releases}
                    onUpdate={(updates) => onUpdateInitiative(initiative.id, updates)}
                    onDrop={(draggedId) => handleDrop(draggedId, status.id)}
                  />
                ))}
              </div>
            </div>
          );
        })}
      </div>
    </DndProvider>
  );
};
