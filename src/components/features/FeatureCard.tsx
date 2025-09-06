import React from 'react';
import { Calendar, Hash } from 'lucide-react';
import { format } from 'date-fns';

const PRIORITIES = {
  low: { color: 'bg-gray-100 text-gray-800', label: 'Low' },
  medium: { color: 'bg-yellow-100 text-yellow-800', label: 'Medium' },
  high: { color: 'bg-orange-100 text-orange-800', label: 'High' },
  critical: { color: 'bg-red-100 text-red-800', label: 'Critical' },
};

const STATUSES = {
  backlog: { color: 'bg-gray-100 text-gray-800', label: 'Backlog' },
  planned: { color: 'bg-blue-100 text-blue-800', label: 'Planned' },
  in_progress: { color: 'bg-yellow-100 text-yellow-800', label: 'In Progress' },
  completed: { color: 'bg-green-100 text-green-800', label: 'Completed' },
  cancelled: { color: 'bg-red-100 text-red-800', label: 'Cancelled' },
};

interface FeatureCardProps {
  feature: any;
}

export const FeatureCard: React.FC<FeatureCardProps> = ({ feature }) => {
  const priorityConfig = PRIORITIES[feature.priority as keyof typeof PRIORITIES];
  const statusConfig = STATUSES[feature.status as keyof typeof STATUSES];

  return (
    <div className="bg-gray-50 rounded-md p-3 border border-gray-200 hover:border-gray-300 transition-colors">
      <div className="flex items-start justify-between mb-2">
        <h4 className="text-sm font-medium text-gray-900 line-clamp-1">
          {feature.title}
        </h4>
        <div className="flex items-center space-x-1 ml-2">
          <span className={`inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium ${priorityConfig.color}`}>
            {priorityConfig.label}
          </span>
        </div>
      </div>

      {feature.description && (
        <p className="text-xs text-gray-600 mb-2 line-clamp-2">
          {feature.description}
        </p>
      )}

      <div className="flex items-center justify-between text-xs text-gray-500">
        <div className="flex items-center space-x-2">
          <span className={`inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium ${statusConfig.color}`}>
            {statusConfig.label}
          </span>
          {feature.story_points && (
            <div className="flex items-center space-x-1">
              <Hash className="w-3 h-3" />
              <span>{feature.story_points}</span>
            </div>
          )}
        </div>
        {feature.end_date && (
          <div className="flex items-center space-x-1">
            <Calendar className="w-3 h-3" />
            <span>{format(new Date(feature.end_date), 'MMM d')}</span>
          </div>
        )}
      </div>
    </div>
  );
};
