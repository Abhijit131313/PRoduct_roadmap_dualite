import React from 'react';
import { motion } from 'framer-motion';
import { Target } from 'lucide-react';
import { ReleaseCard } from './ReleaseCard';

interface ReleasesViewProps {
  releases: any[];
  features: any[];
  roadmapId: string;
}

export const ReleasesView: React.FC<ReleasesViewProps> = ({ releases, features }) => {
  if (releases.length === 0) {
    return (
      <div className="bg-white rounded-lg shadow p-8 text-center">
        <Target className="w-16 h-16 text-gray-400 mx-auto mb-4" />
        <h3 className="text-xl font-semibold text-gray-900 mb-2">No Releases Yet</h3>
        <p className="text-gray-600 mb-4">
          Create your first release to start planning and tracking your product launches.
        </p>
        <p className="text-sm text-gray-500">
          Releases help you group features and communicate timelines to your stakeholders.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
        {releases.map((release, index) => (
          <motion.div
            key={release.id}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: index * 0.1 }}
          >
            <ReleaseCard
              release={release}
              features={features.filter(f => f.release_id === release.id)}
            />
          </motion.div>
        ))}
      </div>
    </div>
  );
};
