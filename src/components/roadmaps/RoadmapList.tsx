import React from 'react';
import { motion } from 'framer-motion';
import { MapPin, Calendar, Users, Eye, Lock } from 'lucide-react';
import { format } from 'date-fns';

interface RoadmapListProps {
  roadmaps: any[];
  onSelectRoadmap: (roadmap: any) => void;
}

export const RoadmapList: React.FC<RoadmapListProps> = ({
  roadmaps,
  onSelectRoadmap,
}) => {
  if (roadmaps.length === 0) {
    return (
      <div className="bg-white rounded-lg shadow p-8 text-center">
        <MapPin className="w-16 h-16 text-gray-400 mx-auto mb-4" />
        <h3 className="text-xl font-semibold text-gray-900 mb-2">No Roadmaps Yet</h3>
        <p className="text-gray-600 mb-4">
          Create your first roadmap to start planning initiatives and features.
        </p>
        <p className="text-sm text-gray-500">
          Roadmaps help you visualize and communicate your product strategy.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <h3 className="text-lg font-semibold text-gray-900">Your Roadmaps</h3>
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {roadmaps.map((roadmap, index) => (
          <motion.div
            key={roadmap.id}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: index * 0.1 }}
            onClick={() => onSelectRoadmap(roadmap)}
            className="bg-white rounded-lg shadow hover:shadow-md transition-all cursor-pointer p-6 border border-gray-200 hover:border-blue-300"
          >
            <div className="flex items-start justify-between mb-4">
              <div className="flex items-center space-x-3">
                <div className="w-10 h-10 bg-indigo-100 rounded-lg flex items-center justify-center">
                  <MapPin className="w-5 h-5 text-indigo-600" />
                </div>
                <div>
                  <h4 className="text-lg font-semibold text-gray-900">{roadmap.name}</h4>
                  <p className="text-sm text-gray-600">{roadmap.projects?.name}</p>
                </div>
              </div>
              <div className="flex items-center space-x-1">
                {roadmap.is_public ? (
                  <Eye className="w-4 h-4 text-green-600" />
                ) : (
                  <Lock className="w-4 h-4 text-gray-400" />
                )}
              </div>
            </div>

            {roadmap.description && (
              <p className="text-gray-600 text-sm mb-4 line-clamp-2">
                {roadmap.description}
              </p>
            )}

            <div className="flex items-center justify-between text-sm text-gray-500">
              <div className="flex items-center space-x-1">
                <Calendar className="w-4 h-4" />
                <span>Created {format(new Date(roadmap.created_at), 'MMM d, yyyy')}</span>
              </div>
              <div className="flex items-center space-x-1">
                <Users className="w-4 h-4" />
                <span>{roadmap.is_public ? 'Public' : 'Private'}</span>
              </div>
            </div>
          </motion.div>
        ))}
      </div>
    </div>
  );
};
